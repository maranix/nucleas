part of 'nodes.dart';

mixin Upstream<T extends Node> on Node {
  List<T> upstreamNodes = [];
}

mixin Downstream<T extends Node> on Node {
  List<T> downstreamNodes = [];
}

mixin ListenableNode<T> on Node implements Listenable<T> {
  late T _cachedValue;

  @override
  T get value => _cachedValue;
}

mixin SchedulableNode on Node {
  int depth = 0;

  bool isScheduled = false;

  final List<Node> _currentDeps = [];

  S _listen<S>(Listenable<S> node) {
    _currentDeps.add(node as Node);
    return node.value;
  }

  void _commitDeps() {
    if (this is! Upstream) {
      _currentDeps.clear();
      return;
    }

    final self = this as Upstream;
    final old = self.upstreamNodes;
    final newDeps = _currentDeps;

    bool changed = old.length != newDeps.length;

    if (!changed) {
      for (int i = 0; i < old.length; i++) {
        if (old[i] != newDeps[i]) {
          changed = true;
          break;
        }
      }
    }

    if (!changed) {
      _currentDeps.clear();
      return;
    }

    for (final parent in old) {
      if (!newDeps.contains(parent) && parent is Downstream) {
        parent.downstreamNodes.remove(this);
      }
    }

    int maxDepth = -1;
    for (final parent in newDeps) {
      if (!old.contains(parent) && parent is Downstream) {
        parent.downstreamNodes.add(this);
      }

      if (parent is SchedulableNode && parent.depth > maxDepth) {
        maxDepth = parent.depth;
      }
    }

    self.upstreamNodes = newDeps.toList();

    depth = maxDepth + 1;
    _currentDeps.clear();
  }

  void refresh();
}
