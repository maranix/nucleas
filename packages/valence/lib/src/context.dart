import 'dart:async';

import 'package:valence/src/list.dart';
import 'package:valence/src/scheduler.dart';

/// The global [ReactiveContext] instance used by default when no explicit
/// context is provided to [Atom], [Computed], or [Effect] constructors.
///
/// Most applications will use this single shared context. Custom contexts
/// are primarily useful for testing or for isolating independent reactive
/// sub-systems.
final defaultReactiveContext = ReactiveContext();

/// The central coordinator for the reactive dependency graph.
///
/// A [ReactiveContext] owns the graph topology (which nodes depend on which),
/// manages dependency tracking during computation, and schedules deferred
/// updates via a [Scheduler].
///
/// **Lifecycle of a reactive update:**
/// 1. An [Atom] value is mutated via [Atom.update].
/// 2. The atom retrieves its dependents from the context and calls
///    [scheduleUpdate] for each one.
/// 3. [scheduleUpdate] enqueues the node ID and (if not already pending)
///    schedules a microtask to [flush] the queue.
/// 4. During [flush], each enqueued [SchedulableNode] is executed in FIFO
///    order — [Computed] nodes mark themselves dirty and propagate further,
///    while [Effect] nodes re-run their side-effect function.
abstract interface class ReactiveContext {
  /// Creates a new [ReactiveContext] backed by the given [scheduler].
  ///
  /// If [scheduler] is `null`, a default [Scheduler] with capacity 1024 is
  /// used.
  factory ReactiveContext([Scheduler? scheduler]) = _ReactiveContextImpl;

  /// Allocates a unique integer ID for a new reactive node and initialises
  /// its dependency/dependent storage.
  ///
  /// Returns the newly assigned node ID.
  int registerNode();

  /// Pushes [nodeId] onto the tracking stack.
  ///
  /// While a node is on the stack, any [trackRead] calls will record a
  /// dependency from [nodeId] to the read provider.
  void startTracking(int nodeId);

  /// Pops the most recent node from the tracking stack.
  ///
  /// Should always be called in a `finally` block paired with
  /// [startTracking] to guarantee stack consistency even when the compute
  /// function throws.
  void endTracking();

  /// Records that the currently-tracked node depends on [providerId].
  ///
  /// Called automatically by [Atom.value] and [Computed.value] when they
  /// are read inside a tracking scope (i.e. inside a [Computed] or [Effect]
  /// body).
  ///
  /// If no node is currently being tracked (the stack is empty), this is a
  /// no-op.
  void trackRead(int providerId);

  /// Returns the list of node IDs that depend on [nodeId].
  ///
  /// Used by [Atom.update] to discover which downstream nodes need to be
  /// scheduled for re-evaluation.
  GrowableUint32List getDependents(int nodeId);

  /// Enqueues [nodeId] for deferred execution.
  ///
  /// If no flush is currently in progress and no microtask has been
  /// scheduled yet, a microtask is automatically scheduled to call [flush].
  void scheduleUpdate(int nodeId);

  /// Drains the scheduler queue and executes all pending [SchedulableNode]s
  /// in FIFO order.
  void flush();

  /// Associates [nodeId] with a [SchedulableNode] so it can be executed
  /// during [flush].
  ///
  /// Only [Computed] and [Effect] nodes need to be registered — [Atom]
  /// nodes are never scheduled for execution themselves.
  void registerSchedulableNode(int nodeId, SchedulableNode node);

  /// Removes all **dependency** edges originating from [nodeId].
  ///
  /// For each provider that [nodeId] previously depended on, the reverse
  /// (dependent) link is also removed. This is called before recomputing a
  /// [Computed] or re-running an [Effect] so that stale dependencies are
  /// pruned and fresh ones can be re-established via [trackRead].
  void clearDependencies(int nodeId);

  /// Fully removes [nodeId] from the dependency graph and the schedulable
  /// registry.
  ///
  /// After disposal the node ID is effectively dead — it will no longer
  /// receive updates or be executed.
  void disposeNode(int nodeId);
}

/// Default implementation of [ReactiveContext].
///
/// Maintains the dependency graph as two parallel maps:
///
/// * `_dependents[A]` — the set of node IDs that **depend on** A (i.e. A's
///   downstream consumers). Used to propagate invalidation.
/// * `_dependencies[A]` — the set of node IDs that A **depends on** (i.e. A's
///   upstream providers). Used to clean up stale edges before recomputation.
///
/// A call stack (`_compStack`) tracks which [Computed] or [Effect] is
/// currently being evaluated so that [trackRead] knows where to record the
/// dependency.
final class _ReactiveContextImpl implements ReactiveContext {
  _ReactiveContextImpl([Scheduler? scheduler])
    : _scheduler = scheduler ?? Scheduler();

  /// Monotonically increasing counter for assigning unique node IDs.
  ///
  /// Starts at `1` because `0` is reserved as a sentinel value by the
  /// ring-buffer scheduler (see [Scheduler.pop]).
  int _nextNodeId = 1;

  /// Whether a microtask to call [flush] has already been scheduled.
  bool _isUpdateScheduled = false;

  /// Whether [flush] is currently executing.
  ///
  /// Used together with [_isUpdateScheduled] to prevent re-entrant or
  /// redundant microtask scheduling.
  bool _isFlushing = false;

  /// The underlying queue that orders pending node executions.
  final Scheduler _scheduler;

  /// Stack of node IDs currently being evaluated.
  ///
  /// Supports nested tracking: e.g. a [Computed] reading another
  /// [Computed] will push two IDs onto the stack.
  final GrowableUint32List _compStack = GrowableUint32List(16);

  /// **Downstream** map: `nodeId → [dependentIds...]`.
  ///
  /// When node A is read inside node B's computation, B is added to
  /// `_dependents[A]`.
  final Map<int, GrowableUint32List> _dependents = {};

  /// **Upstream** map: `nodeId → [providerIds...]`.
  ///
  /// When node B reads node A, A is added to `_dependencies[B]`.
  final Map<int, GrowableUint32List> _dependencies = {};

  /// Registry mapping node IDs to their [SchedulableNode] instances.
  ///
  /// Only [Computed] and [Effect] nodes are registered here.
  final Map<int, SchedulableNode> _schedulables = {};

  @override
  int registerNode() {
    final id = _nextNodeId;

    _dependents[id] = GrowableUint32List();
    _dependencies[id] = GrowableUint32List();

    _nextNodeId += 1;

    return id;
  }

  @override
  void startTracking(int nodeId) => _compStack.add(nodeId);

  @override
  void endTracking() {
    if (_compStack.isEmpty) return;
    _compStack.removeLast();
  }

  @override
  void trackRead(int providerId) {
    if (_compStack.isEmpty) return;

    final consumerId = _compStack.last;

    // These are guaranteed non-null because registerNode() pre-initialises
    // both maps for every node.
    final providerDependents = _dependents[providerId]!;
    final consumerDependencies = _dependencies[consumerId]!;

    // Establish a bidirectional link, skipping duplicates.
    if (!providerDependents.contains(consumerId)) {
      providerDependents.add(consumerId);
    }

    if (!consumerDependencies.contains(providerId)) {
      consumerDependencies.add(providerId);
    }
  }

  @override
  GrowableUint32List getDependents(int nodeId) =>
      _dependents[nodeId] ?? GrowableUint32List(0);

  @override
  void scheduleUpdate(int nodeId) {
    final node = _schedulables[nodeId];

    // If the node doesn't exist in the registry or is already enqueued,
    // there's nothing to do.
    if (node == null || node.isScheduled) return;

    node.isScheduled = true;

    _scheduler.push(nodeId);

    // Auto-schedule a microtask to drain the queue if one isn't already
    // pending and we aren't in the middle of a flush.
    if (!_isUpdateScheduled && !_isFlushing) {
      _isUpdateScheduled = true;
      scheduleMicrotask(flush);
    }
  }

  @override
  void registerSchedulableNode(int nodeId, SchedulableNode node) {
    _schedulables[nodeId] = node;
  }

  @override
  void flush() {
    // Allow future mutations to schedule a fresh microtask.
    _isUpdateScheduled = false;
    _isFlushing = true;

    try {
      while (!_scheduler.isEmpty) {
        final id = _scheduler.pop();

        // `0` is the ring-buffer sentinel for an empty queue.
        if (id == 0) continue;

        _schedulables[id]?.execute();
      }
    } finally {
      _isFlushing = false;
    }
  }

  @override
  void clearDependencies(int nodeId) {
    final deps = _dependencies[nodeId];

    if (deps == null || deps.isEmpty) return;

    // For each provider this node previously depended on, remove the
    // reverse (dependent) link.
    for (var i = 0; i < deps.length; i++) {
      _dependents[deps[i]]?.remove(nodeId);
    }

    deps.clear();
  }

  @override
  void disposeNode(int nodeId) {
    clearDependencies(nodeId);

    _dependents.remove(nodeId);
    _dependencies.remove(nodeId);
    _schedulables.remove(nodeId);
  }
}
