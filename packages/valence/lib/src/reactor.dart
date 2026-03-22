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
  Set<Node> _deps = {};

  @override
  int get depth => _depth;

  @override
  void addDependent(ReactiveNode node) {}

  @override
  void removeDependent(ReactiveNode node) {}

  @override
  void recompute() {
    run();
  }

  void run() {
    _scope.beginTracking();
    try {
      _fn();
    } finally {
      final newDeps = _scope.endTracking();
      _updateDeps(newDeps);
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
  }
}
