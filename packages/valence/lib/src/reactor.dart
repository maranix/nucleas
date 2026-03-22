import 'package:valence/types.dart';

import 'core.dart';
import 'scope.dart';

final class Reactor implements ReactiveNode {
  Reactor(this._scope, this._fn) {
    run();
  }

  final Scope _scope;
  final VoidCallback _fn;

  int _depth = 0;

  @override
  bool isPending = false;

  List<Node> _dependencies = [];

  @override
  int get depth => _depth;

  @override
  void addDependent(ReactiveNode node) {}

  @override
  void removeDependent(ReactiveNode node) {}

  @override
  void recompute() => run();

  void run() {
    _scope.beginTracking();
    try {
      _fn();
    } finally {
      final newDependencies = _scope.endTracking();
      if (!_dependenciesUnchanged(newDependencies)) {
        _updateDependencies(newDependencies);
      }
    }
  }

  void _updateDependencies(List<Node> newDependencies) {
    if (_dependenciesUnchanged(newDependencies)) {
      _updateDepth(newDependencies);
      return;
    }

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
  }
}
