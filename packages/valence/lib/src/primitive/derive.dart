part of 'base.dart';

Derive<T> derive<T>(
  ValueCallback<T> fn, {
  Scope? scope,
  EqualityCallback<T>? equals,
}) => Derive<T>(fn, scope: scope, equals: equals);

final class Derive<T> extends BaseSource<T> with DependentMixin {
  Derive(this._compute, {super.scope, super.equals});

  final ValueCallback<T> _compute;

  late T _cachedValue;

  bool _isInitialized = false;

  bool _isDirty = true;

  T call() {
    reportRead();

    if (_isDirty) {
      _forceRecompute();
    }

    return _cachedValue;
  }

  @override
  void recompute() {
    if (_isDirty) return;

    _isDirty = true;

    _scope.schedular.batch(() {
      for (var i = 0; i < _dependents.length; i++) {
        _scope.schedular.enqueue(_dependents[i]);
      }
    });
  }

  void _forceRecompute() {
    late T nextValue;

    executeTracked(() {
      nextValue = _compute();
    });

    _isDirty = false;

    // If the value didn't actually change, we just cache and exit cleanly
    if (_isInitialized && _equals(_cachedValue, nextValue)) return;

    _cachedValue = nextValue;
    _isInitialized = true;
  }

  @override
  void dispose() {
    super.dispose();

    _unsubcribeFromSources();
  }
}
