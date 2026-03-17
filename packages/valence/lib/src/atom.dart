import 'package:valence/src/context.dart';

/// A function that transforms an atom's current value into a new value.
///
/// Passed to [Atom.update] to perform mutations. The function receives the
/// current value and must return the next value.
///
/// ```dart
/// final counter = Atom<int>(0);
/// counter.update((current) => current + 1);
/// ```
typedef AtomMutator<T> = T Function(T currentValue);

/// The fundamental unit of **mutable** reactive state.
///
/// An [Atom] holds a single value of type [T] and participates in the
/// reactive dependency graph. When the value changes via [update],
/// all downstream [Computed] and [Effect] nodes are automatically
/// scheduled for re-evaluation.
///
/// ## Reading values
///
/// * [value] — reads the current value **and** registers a dependency if
///   called inside a [Computed] or [Effect] body.
/// * [peek] — reads the current value **without** registering a dependency.
///   Use this when you need the value for a one-off operation and do not
///   want to subscribe to future changes.
///
/// ## Mutating values
///
/// All mutations go through [update], which accepts an [AtomMutator]
/// function. If the new value is identical or equal to the current value,
/// the update is skipped and no downstream propagation occurs.
///
/// ```dart
/// final name = Atom<String>('Alice');
///
/// name.update((current) => current.toUpperCase()); // Triggers dependents.
/// name.update((current) => current);               // No-op (same value).
/// ```
///
/// ## Lifecycle
///
/// Call [dispose] when the atom is no longer needed to remove it from the
/// dependency graph and free associated bookkeeping.
abstract interface class Atom<T> {
  /// Creates a new atom initialised to [value].
  ///
  /// By default the atom uses [defaultValenceContext]. Pass a custom
  /// [context] if you need isolated reactive sub-systems (e.g. in tests).
  factory Atom(T value, {ValenceContext? context}) = _AtomImpl;

  /// Returns the current value and registers a dependency on this atom
  /// in the active tracking scope.
  ///
  /// If called outside a tracking scope (i.e. not inside a [Computed] or
  /// [Effect] body), the value is returned without side effects.
  T value();

  /// Returns the current value **without** registering a dependency.
  ///
  /// Useful for reading state in event handlers, logging, or other contexts
  /// where reactive subscription is not desired.
  T peek();

  /// Applies [mutator] to the current value and, if the value changes,
  /// schedules all dependent nodes for re-evaluation.
  ///
  /// A change is detected by first checking [identical] (reference equality)
  /// and then the `==` operator. If neither indicates a change, propagation
  /// is skipped entirely.
  void update(AtomMutator<T> mutator);

  /// Removes this atom from the dependency graph.
  ///
  /// After disposal the atom should not be read or updated.
  void dispose();
}

/// Default implementation of [Atom].
final class _AtomImpl<T> implements Atom<T> {
  _AtomImpl(this._value, {ValenceContext? context})
    : _context = context ?? defaultValenceContext {
    _id = _context.registerNode();
  }

  /// The unique node ID assigned by the [ValenceContext].
  late final int _id;

  /// The reactive context this atom is registered with.
  final ValenceContext _context;

  /// The current stored value.
  T _value;

  @override
  T value() {
    _context.trackRead(_id);
    return _value;
  }

  @override
  T peek() => _value;

  @override
  void update(AtomMutator<T> mutator) {
    final next = mutator(_value);

    // Skip propagation if the value hasn't actually changed.
    if (identical(_value, next) || _value == next) return;

    _value = next;

    // Notify all downstream dependents.
    final deps = _context.getDependents(_id);
    for (var i = 0; i < deps.length; i++) {
      _context.scheduleUpdate(deps[i]);
    }
  }

  @override
  void dispose() => _context.disposeNode(_id);
}
