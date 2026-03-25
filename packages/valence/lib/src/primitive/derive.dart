part of 'base.dart';

Derive<T> derive<T>(
  ValueCallback<T> fn, {
  Scope? scope,
  EqualityCallback<T>? equals,
}) => Derive<T>(fn, scope: scope, equals: equals);

final class Derive<T> extends BaseSource<T> with DependentMixin {
  Derive(this._compute, {super.scope, super.equals}) {
    // Run once immediately to establish the initial dependency graph
    // and calculate the starting value.
    recompute();
  }

  final ValueCallback<T> _compute;

  late T _cachedValue;

  bool _isInitialized = false;

  T call() {
    reportRead();
    return _cachedValue;
  }

  @override
  void recompute() {
    late T nextValue;

    executeTracked(() {
      nextValue = _compute();
    });

    if (_isInitialized && _equals(_cachedValue, nextValue)) return;

    _cachedValue = nextValue;
    _isInitialized = true;

    _scope.schedular.batch(() {
      for (var i = 0; i < _dependents.length; i++) {
        _scope.schedular.enqueue(_dependents[i]);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();

    _unsubcribeFromSources();
  }
}
