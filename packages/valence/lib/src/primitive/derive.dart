import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

import '../engine/node.dart';
import '../config.dart';
import '../engine/scope.dart';

Derive<T> derive<T>(
  ValueCallback<T> fn, {
  Scope? scope,
  EqualityCallback<T>? equals,
}) => Derive<T>(fn, scope: scope, equals: equals);

final class Derive<T> implements ReactiveNode {
  Derive(this._compute, {Scope? scope, EqualityCallback<T>? equals})
    : _scope = scope ?? Valence.root,
      _equals = equals ?? defaultEquals {
    _scope.registerDerive(this);
    _scope.graph.beginTracking();
    try {
      _cachedValue = _compute();
    } finally {
      final deps = _scope.graph.endTracking();
      _updateDependencies(deps);
    }
  }

  final Scope _scope;
  final ValueCallback<T> _compute;
  final EqualityCallback<T> _equals;

  T? _cachedValue;
  int _depth = 0;

  bool _isStable = false;

  List<Node> _dependencies = [];
  final List<ReactiveNode> _dependents = [];

  @override
  bool isPending = false;

  @override
  int get depth => _depth;

  @override
  void addDependent(ReactiveNode node) => _dependents.add(node);

  @override
  void removeDependent(ReactiveNode node) => _dependents.remove(node);

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
      if (!_dependenciesUnchanged(newDependencies)) {
        _updateDependencies(newDependencies);
        _isStable = false;
      } else {
        _isStable = true;
      }
    }
  }

  void _updateDependencies(List<Node> newDependencies) {
    final newSet = newDependencies.toSet();
    final oldSet = _dependencies.toSet();

    for (final dep in newSet) {
      if (!oldSet.contains(dep)) dep.addDependent(this);
    }

    for (final dep in oldSet) {
      if (!newSet.contains(dep)) dep.removeDependent(this);
    }

    _dependencies = newDependencies;
    _updateDepth(newDependencies);
  }

  bool _dependenciesUnchanged(List<Node> newDependencies) {
    if (newDependencies.length != _dependencies.length) return false;

    for (var i = 0; i < newDependencies.length; i++) {
      if (!identical(newDependencies[i], _dependencies[i])) return false;
    }

    return true;
  }

  void _updateDepth(List<Node> dependencies) {
    var maxDepth = 0;
    for (var i = 0; i < dependencies.length; i++) {
      final dep = dependencies[i];

      final d = dep is ReactiveNode ? dep.depth : 0;
      if (d > maxDepth) maxDepth = d;
    }

    _depth = maxDepth + 1;
  }

  void dispose() {
    for (final dep in _dependencies) {
      dep.removeDependent(this);
    }

    _dependencies.clear();
    _dependents.clear();
  }
}
