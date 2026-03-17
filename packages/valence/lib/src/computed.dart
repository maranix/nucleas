import 'package:valence/src/context.dart';
import 'package:valence/src/scheduler.dart';

/// A **lazily recomputed**, cached derived value within the reactive graph.
///
/// A [Computed] wraps a pure function that derives its value from one or more
/// upstream [Atom] or [Computed] nodes. Dependencies are tracked
/// automatically — the compute function is re-executed only when at least
/// one dependency has changed.
///
/// ## Lazy evaluation
///
/// Unlike [Effect], a [Computed] does **not** re-execute its function as soon
/// as a dependency changes. Instead, it marks itself as _dirty_ and defers
/// recomputation until the next time [value] is read. This avoids redundant
/// work when multiple upstream atoms change in the same update cycle.
///
/// ## Propagation
///
/// A [Computed] also acts as a provider: other [Computed] and [Effect] nodes
/// can depend on it. When a computed becomes dirty it propagates the
/// invalidation to its own dependents so that they too are scheduled for
/// re-evaluation.
///
/// ```dart
/// final price    = Atom<double>(10);
/// final quantity = Atom<int>(2);
///
/// final total = Computed(() => price.value() * quantity.value());
///
/// print(total.value()); // 20.0
/// ```
///
/// ## Lifecycle
///
/// Call [dispose] when the computed is no longer needed to unlink it from
/// the dependency graph.
abstract interface class Computed<T> implements SchedulableNode {
  /// Creates a new [Computed] that derives its value by calling [computeFn].
  ///
  /// The function is invoked immediately during construction to establish
  /// initial dependencies and cache the first result.
  ///
  /// If [context] is `null`, [defaultReactiveContext] is used.
  factory Computed(T Function() computeFn, [ReactiveContext? context]) =
      _ComputedImpl;

  /// Returns the cached value, recomputing first if dirty.
  ///
  /// Also registers a dependency on this computed in the active tracking
  /// scope (if any).
  T value();

  /// Removes this computed from the dependency graph.
  void dispose();
}

/// Default implementation of [Computed].
///
/// The node participates in the scheduler via [SchedulableNode]. During a
/// flush cycle its [execute] method marks it dirty and propagates the
/// invalidation downstream — the actual recomputation is deferred until
/// [value] is next read.
final class _ComputedImpl<T> implements Computed<T> {
  _ComputedImpl(
    T Function() computeFn, [
    ReactiveContext? context,
  ]) : _fn = computeFn,
       _context = context ?? defaultReactiveContext {
    _id = _context.registerNode();
    _context.registerSchedulableNode(_id, this);

    // Perform the initial computation to establish dependencies.
    _recompute();
  }

  /// The pure derivation function supplied by the caller.
  final T Function() _fn;

  /// The reactive context this node is registered with.
  final ReactiveContext _context;

  /// The unique node ID assigned by the context.
  late final int _id;

  /// The most recently computed value.
  late T _cached;

  /// Whether at least one upstream dependency has changed since the last
  /// [_recompute].
  bool _dirty = false;

  /// Whether this node is currently enqueued in the scheduler.
  bool _isScheduled = false;

  /// Clears stale dependencies, re-runs [_fn], and caches the result.
  ///
  /// Dependencies are re-established from scratch on each call to
  /// [_recompute] by wrapping the function invocation in a
  /// [ReactiveContext.startTracking] / [ReactiveContext.endTracking] pair.
  void _recompute() {
    _context.clearDependencies(_id);

    _context.startTracking(_id);
    try {
      _cached = _fn();
      _dirty = false;
    } finally {
      _context.endTracking();
    }
  }

  @override
  bool get isScheduled => _isScheduled;

  @override
  set isScheduled(bool value) {
    _isScheduled = value;
  }

  @override
  T value() {
    // Register this computed as a dependency of whichever node is currently
    // being tracked (if any).
    _context.trackRead(_id);

    if (_dirty) _recompute();

    return _cached;
  }

  @override
  void execute() {
    isScheduled = false;

    // If already dirty there's nothing more to do — we'll recompute lazily
    // when [value] is next called.
    if (_dirty) return;
    _dirty = true;

    // Propagate the invalidation to downstream dependents.
    final deps = _context.getDependents(_id);
    for (var i = 0; i < deps.length; i++) {
      _context.scheduleUpdate(deps[i]);
    }
  }

  @override
  void dispose() => _context.disposeNode(_id);
}
