part of 'base.dart';

Derive<T> derive<T>(
  ValueCallback<T> fn, {
  Scope? scope,
  EqualityCallback<T>? equals,
}) => Derive<T>(fn, scope: scope, equals: equals);

final class Derive<T> extends BaseSource<T> with DependentMixin {
  Derive(this._compute, {super.scope, super.equals}) {
    _cachedValue = _retrackAndCompute();
    _id = _scope.idPool.acquire();
  }

  late final int _id;

  @override
  int get id => _id;

  final ValueCallback<T> _compute;

  T? _cachedValue;

  T call() {
    _scope.graph.recordSource(this);
    return _cachedValue as T;
  }

  @override
  void recompute() {
    final next = switch (_isStable) {
      true => _compute(),
      false => _retrackAndCompute(),
    };

    if (_equals(_cachedValue as T, next)) return;
    _cachedValue = next;

    for (var i = 0; i < _dependents.length; i++) {
      _scope.schedular.enqueue(_dependents[i]);
    }
  }

  T _retrackAndCompute() {
    _scope.graph.beginTracking();

    try {
      return _compute();
    } finally {
      final newDependencies = _scope.graph.endTracking();
      if (!_sourcesUnchanged(newDependencies)) {
        _updateSources(newDependencies);
        _isStable = false;
      } else {
        _isStable = true;
      }
    }
  }

  @override
  void dispose() {
    _unsubcribeFromSources();

    _scope.schedular.cancel(id);
    _scope.idPool.release(id);
    super.dispose();
  }
}
