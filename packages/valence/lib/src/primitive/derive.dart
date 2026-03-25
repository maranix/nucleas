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

  T call() {
    reportRead();

    // We only compute if someone actually asks for the value the very first time.
    if (!_isInitialized) {
      executeTracked(() {
        _cachedValue = _compute();
      });
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
    if (_equals(_cachedValue, nextValue)) return;

    _cachedValue = nextValue;

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
