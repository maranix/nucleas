import 'package:valence/src/context.dart';
import 'package:valence/src/scheduler.dart';

/// A reactive side-effect that re-runs whenever its dependencies change.
///
/// An [Effect] wraps a void function that reads reactive state ([Atom] and/or
/// [Computed] values). Dependencies are tracked automatically during
/// execution, and whenever any dependency changes, the function is scheduled
/// to run again.
///
/// Unlike [Computed], an effect is **eager** — it executes immediately during
/// construction and again on every dependency change (after the current
/// microtask flush), rather than deferring work until a read.
///
/// ## Typical uses
///
/// * Logging state changes
/// * Syncing state to external systems (network, local storage)
/// * Triggering UI rebuilds in Flutter
///
/// ```dart
/// final counter = Atom<int>(0);
///
/// Effect(() {
///   print('Counter is: ${counter.value()}');
/// });
///
/// counter.update((c) => c + 1); // Prints: Counter is: 1
/// ```
///
/// ## Lifecycle
///
/// Call [dispose] when the effect is no longer needed. This removes it from
/// the dependency graph and prevents future executions.
abstract interface class Effect implements SchedulableNode {
  /// Creates a new [Effect] that runs [effectFn].
  ///
  /// The function is invoked **immediately** during construction to establish
  /// initial dependencies and perform the first side-effect.
  ///
  /// If [context] is `null`, [defaultValenceContext] is used.
  factory Effect(void Function() effectFn, [ValenceContext? context]) =
      _EffectImpl;

  /// Removes this effect from the dependency graph and prevents future
  /// executions.
  void dispose();
}

/// Default implementation of [Effect].
///
/// On each execution cycle, dependencies from the previous run are cleared
/// and re-established from scratch. This ensures that conditional branches
/// in the effect function produce accurate dependency sets.
final class _EffectImpl implements Effect {
  _EffectImpl(
    void Function() effectFn, [
    ValenceContext? context,
  ]) : _fn = effectFn,
       _context = context ?? defaultValenceContext {
    _id = _context.registerNode();
    _context.registerSchedulableNode(_id, this);

    // Run immediately to establish initial dependencies.
    execute();
  }

  /// The side-effect function supplied by the caller.
  final void Function() _fn;

  /// The reactive context this effect is registered with.
  final ValenceContext _context;

  /// The unique node ID assigned by the context.
  late final int _id;

  /// Whether this node is currently enqueued in the scheduler.
  bool _isScheduled = false;

  @override
  bool get isScheduled => _isScheduled;

  @override
  set isScheduled(bool value) {
    _isScheduled = value;
  }

  @override
  void execute() {
    isScheduled = false;

    // Clear old dependency edges so that stale subscriptions are pruned.
    _context.clearDependencies(_id);

    _context.startTracking(_id);
    try {
      _fn();
    } finally {
      _context.endTracking();
    }
  }

  @override
  void dispose() {
    _context.disposeNode(_id);
  }
}
