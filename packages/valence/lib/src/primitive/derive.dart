import 'package:valence/src/config.dart';
import 'package:valence/src/engine/node.dart';
import 'package:valence/src/engine/scope.dart';
import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

/// Public interface for a derived (computed) reactive value.
///
/// Provides read-only access to a lazily computed, memoized value
/// and lifecycle management.
abstract interface class Derive<T> {
  T call();
}

/// Creates a new [Derive].
Derive<T> derive<T>(
  ValueCallback<T> fn, {
  Scope? scope,
  EqualityCallback<T>? equals,
  FilterCallback<T>? filter,
  String? debugLabel,
}) => _DeriveImpl<T>(
  fn,
  scope: scope,
  eq: equals,
  filter: filter,
  debugLabel: debugLabel,
);

final class _DeriveImpl<T> extends RelayNode<T> implements Derive<T> {
  _DeriveImpl(
    this._compute, {
    Scope? scope,
    EqualityCallback<T>? eq,
    FilterCallback<T>? filter,
    super.debugLabel,
  }) : _scope = scope ?? Valence.root,
       _equals = eq ?? defaultEquals,
       _filter = filter {
    _scope.addRoot(this);
  }

  final Scope _scope;
  final ValueCallback<T> _compute;
  final EqualityCallback<T> _equals;
  final FilterCallback<T>? _filter;

  late T _cachedValue;
  bool _isInitialized = false;

  @override
  Scope get scope => _scope;

  @override
  EqualityCallback<T> get equals => _equals;

  @override
  FilterCallback<T>? get filter => _filter;

  @override
  T call() {
    reportRead();

    // We only compute if someone actually asks for the value the very first time.
    if (!_isInitialized) {
      executeTracked(() {
        _cachedValue = _compute();
      });

      assert(
        _cachedValue is! Node,
        'Type Error: Illegal attempt to return a reactive Node from a Derive computation.',
      );

      _isInitialized = true;
    }

    return _cachedValue;
  }

  @override
  void recompute() {
    // If it was never read, it doesn't need to react to upstream changes yet.
    if (!_isInitialized) return;

    late T nextValue;

    executeTracked(() {
      nextValue = _compute();
    });

    // If the value didn't actually change, we just cache and exit cleanly
    if (equals(_cachedValue, nextValue)) return;
    if (filter != null && !filter!(nextValue)) return;

    _cachedValue = nextValue;

    notifyDependents();
  }
}
