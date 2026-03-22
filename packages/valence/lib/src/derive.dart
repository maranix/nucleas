import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

import 'core.dart';
import 'scope.dart';

final class Derive<T> implements ReactiveNode {
  Derive(this._scope, this._compute, {EqualityCallback<T>? equals})
    : _equals = equals ?? defaultEquals {
    _scope.beginTracking();
    try {
      _cachedValue = _compute();
    } finally {
      final deps = _scope.endTracking();
      _updateDeps(deps);
    }
  }

  final Scope _scope;
  final ValueCallback<T> _compute;
  final EqualityCallback<T> _equals;

  T? _cachedValue;
  int _depth = 0;
  Set<Node> _deps = {};
  final Set<ReactiveNode> _dependents = {};

  @override
  int get depth => _depth;

  @override
  void addDependent(ReactiveNode node) => _dependents.add(node);

  @override
  void removeDependent(ReactiveNode node) => _dependents.remove(node);

  T call() {
    _scope.recordRead(this);
    return _cachedValue as T;
  }

  @override
  void recompute() {
    _scope.beginTracking();
    late T next;
    try {
      next = _compute();
    } finally {
      final newDeps = _scope.endTracking();
      _updateDeps(newDeps);
    }

    if (_equals(_cachedValue as T, next)) return;

    _cachedValue = next;
    for (final dep in _dependents) {
      _scope.enqueue(dep);
    }
  }

  void _updateDeps(Set<Node> newDeps) {
    for (final dep in _deps) {
      if (!newDeps.contains(dep)) {
        dep.removeDependent(this);
      }
    }
    var maxDepth = 0;
    for (final dep in newDeps) {
      if (!_deps.contains(dep)) {
        dep.addDependent(this);
      }
      final d = dep is ReactiveNode ? dep.depth : 0;
      if (d > maxDepth) maxDepth = d;
    }
    _deps = newDeps;
    _depth = maxDepth + 1;
  }

  void dispose() {
    for (final dep in _deps) {
      dep.removeDependent(this);
    }
    _deps.clear();
    _dependents.clear();
  }
}
