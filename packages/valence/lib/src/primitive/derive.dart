part of 'base.dart';

Derive<T> derive<T>(
  ValueCallback<T> fn, {
  Scope? scope,
  EqualityCallback<T>? equals,
}) => Derive<T>(fn, scope: scope, equals: equals);

final class Derive<T> extends BaseSource<T> with DependentMixin {
  Derive(this._compute, {super.scope, super.equals}) {
    _cachedValue = _retrackAndCompute();
  }

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
    for (final source in _sources) {
      source.removeDependent(this);
    }

    _sources.clear();
    _dependents.clear();
  }
}
