import 'dart:async';

import 'package:valence/src/list.dart';
import 'package:valence/src/scheduler.dart';

/// The global [ValenceContext] instance used by default when no explicit
/// context is provided to [Atom], [Computed], or [Effect] constructors.
///
/// Most applications will use this single shared context. Custom contexts
/// are primarily useful for testing or for isolating independent reactive
/// sub-systems.
final defaultValenceContext = ValenceContext();

/// The central coordinator for the reactive dependency graph.
///
/// A [ValenceContext] owns the graph topology (which nodes depend on which),
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
abstract interface class ValenceContext {
  /// Creates a new [ValenceContext] backed by the given [scheduler].
  ///
  /// If [scheduler] is `null`, a default [Scheduler] with capacity 1024 is
  /// used.
  factory ValenceContext([Scheduler? scheduler]) = _ValenceContextImpl;

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

  /// Removes all **dependent** edges pointing to [nodeId].
  ///
  /// This is called when a node is disposed to prevent dangling dependent
  /// references.
  void clearDependents(int nodeId);

  /// Fully removes [nodeId] from the dependency graph and the schedulable
  /// registry.
  ///
  /// After disposal the node ID is effectively dead — it will no longer
  /// receive updates or be executed.
  ///
  /// Also removes all dependency and dependent edges for the given node.
  void disposeNode(int nodeId);

  /// Sets the maximum number of times [flush] will run before throwing.
  ///
  /// This is a safety mechanism to prevent infinite loops in case of
  /// cyclic dependencies.
  ///
  /// The default value is `100_000`.
  ///
  /// Throws [ArgumentError] if [maxFlushIterations] is negative.
  void setMaxFlushIterations(int maxFlushIterations);
}

/// Default implementation of [ValenceContext].
///
/// Maintains the dependency graph as two parallel lists indexed by node ID:
///
/// * `_dependents[id]` — the set of node IDs that **depend on** id (i.e.
///   downstream consumers). Used to propagate invalidation.
/// * `_dependencies[id]` — the set of node IDs that id **depends on** (i.e.
///   upstream providers). Used to clean up stale edges before recomputation.
///
/// Using lists instead of maps gives O(1) indexed access with better cache
/// locality. Node IDs are recycled via a free-list to keep the lists compact.
///
/// A call stack (`_compStack`) tracks which [Computed] or [Effect] is
/// currently being evaluated so that [trackRead] knows where to record the
/// dependency.
final class _ValenceContextImpl implements ValenceContext {
  _ValenceContextImpl([Scheduler? scheduler])
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

  /// **Downstream** list: `nodeId → [dependentIds...]`.
  ///
  /// When node A is read inside node B's computation, B is added to
  /// `_dependents[A]`.
  ///
  /// Index 0 is unused (node IDs start at 1).
  final List<GrowableUint32List?> _dependents = [null];

  /// **Upstream** list: `nodeId → [providerIds...]`.
  ///
  /// When node B reads node A, A is added to `_dependencies[B]`.
  ///
  /// Index 0 is unused (node IDs start at 1).
  final List<GrowableUint32List?> _dependencies = [null];

  /// Registry mapping node IDs to their [SchedulableNode] instances.
  ///
  /// Only [Computed] and [Effect] nodes are registered here.
  ///
  /// Index 0 is unused (node IDs start at 1).
  final List<SchedulableNode?> _schedulables = [null];

  /// Free-list of recycled node IDs.
  ///
  /// When a node is disposed (and has no phantom entry in the scheduler),
  /// its ID is pushed here. [registerNode] pops from this list before
  /// falling back to [_nextNodeId].
  final GrowableUint32List _freeIds = GrowableUint32List();

  /// The maximum number of times [flush] will run before throwing.
  int _maxFlushIterations = 100_000;

  @override
  void setMaxFlushIterations(int maxFlushIterations) {
    if (maxFlushIterations < 0) {
      throw ArgumentError('maxFlushIterations must be non-negative');
    }

    _maxFlushIterations = maxFlushIterations;
  }

  @override
  int registerNode() {
    int id;

    if (_freeIds.isNotEmpty) {
      id = _freeIds.removeLast();
    } else {
      id = _nextNodeId;
      _nextNodeId += 1;

      // Grow all lists to accommodate the new ID.
      _dependents.add(null);
      _dependencies.add(null);
      _schedulables.add(null);
    }

    _dependents[id] = GrowableUint32List();
    _dependencies[id] = GrowableUint32List();

    return id;
  }

  @override
  void startTracking(int nodeId) => _compStack.add(nodeId);

  @override
  void endTracking() {
    if (_compStack.isEmpty) {
      throw StateError(
        'Tracking stack underflow: Unbalanced startTracking/endTracking calls. '
        'This is an internal framework bug.'
        '\n'
        'Please report this issue to the GitHub repository with a minimal '
        'reproducible example.',
      );
    }
    _compStack.removeLast();
  }

  @override
  void trackRead(int providerId) {
    if (_compStack.isEmpty) return;

    final consumerId = _compStack.last;
    final consumerDependencies = _dependencies[consumerId]!;

    // Only check the consumer's (smaller) dependency list for duplicates.
    // The provider's dependents list is guaranteed not to contain this
    // consumer because clearDependencies() is always called before
    // re-tracking. We only guard against the same provider being read
    // multiple times within a single computation (e.g. `a.value() + a.value()`).
    if (consumerDependencies.contains(providerId)) return;

    consumerDependencies.add(providerId);
    _dependents[providerId]!.add(consumerId);
  }

  @override
  GrowableUint32List getDependents(int nodeId) {
    if (nodeId >= _dependents.length) return .new(0);
    return _dependents[nodeId] ?? .new(0);
  }

  @override
  void scheduleUpdate(int nodeId) {
    if (nodeId >= _schedulables.length) return;

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
    if (nodeId < _schedulables.length) {
      _schedulables[nodeId] = node;
    }
  }

  @override
  void flush() {
    // Allow future mutations to schedule a fresh microtask.
    _isUpdateScheduled = false;
    _isFlushing = true;

    int iterations = 0;

    try {
      while (!_scheduler.isEmpty) {
        if (iterations > _maxFlushIterations) {
          // Purge the queue so we don't stay trapped on the next run
          _scheduler.clear();
          throw StateError(
            'Cyclic dependency detected: The reactive scheduler exceeded '
            '$_maxFlushIterations iterations in a single flush cycle.',
          );
        }
        iterations += 1;

        final id = _scheduler.pop();
        // `0` is the ring-buffer sentinel for an empty queue.
        if (id != 0) {
          _schedulables[id]?.execute();
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// Removes all **dependency** edges originating from [nodeId].
  ///
  /// **Performance note:** This method is O(k × d) where *k* is the number
  /// of dependencies being cleared and *d* is the average size of each
  /// provider's dependents list (due to the linear scan in
  /// [GrowableUint32List.remove]). For extremely dense graphs, a
  /// doubly-linked or index-based edge structure could reduce this to O(k).
  @override
  void clearDependencies(int nodeId) {
    if (nodeId >= _dependencies.length) return;

    final deps = _dependencies[nodeId];

    if (deps == null || deps.isEmpty) return;

    // For each provider this node previously depended on, remove the
    // reverse (dependent) link.
    for (var i = 0; i < deps.length; i++) {
      final providerId = deps[i];
      if (providerId < _dependents.length) {
        _dependents[providerId]?.remove(nodeId);
      }
    }

    deps.clear();
  }

  @override
  void clearDependents(int nodeId) {
    if (nodeId >= _dependents.length) return;

    final deps = _dependents[nodeId];

    if (deps == null || deps.isEmpty) return;

    // For each dependent, remove the reverse (dependency) link.
    for (var i = 0; i < deps.length; i++) {
      final dependentId = deps[i];
      if (dependentId < _dependencies.length) {
        _dependencies[dependentId]?.remove(nodeId);
      }
    }

    deps.clear();
  }

  @override
  void disposeNode(int nodeId) {
    clearDependencies(nodeId);
    clearDependents(nodeId);

    // Prevent the phantom node from executing if it's still in the
    // ring buffer. The stale ID will be a no-op when popped.
    final schedulable = nodeId < _schedulables.length
        ? _schedulables[nodeId]
        : null;
    final isPhantom = schedulable != null && schedulable.isScheduled;

    if (isPhantom) {
      schedulable.isScheduled = false;
    }

    if (nodeId < _dependents.length) _dependents[nodeId] = null;
    if (nodeId < _dependencies.length) _dependencies[nodeId] = null;
    if (nodeId < _schedulables.length) _schedulables[nodeId] = null;

    // Recycle the ID for future use, but only if it has no phantom entry
    // sitting in the ring buffer. Phantom IDs are sacrificed to avoid the
    // new node assigned that ID from receiving a spurious execution.
    if (!isPhantom) {
      _freeIds.add(nodeId);
    }
  }
}
