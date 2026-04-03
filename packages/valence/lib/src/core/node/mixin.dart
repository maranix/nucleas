part of 'nodes.dart';

mixin Upstream<T extends Node> on Node {
  Set<T> upstreamNodes = .new();
}

mixin Downstream<T extends Node> on Node {
  Set<T> downstreamNodes = .new();

  void _scheduleDownstreamNodes() {
    for (final node in downstreamNodes) {
      _scope.scheduler.scheduleNode(node);
    }
  }
}

mixin ListenableNode<T> on Node implements Listenable<T> {
  late T _cachedValue;

  @override
  T get value => _cachedValue;
}

mixin Refreshable on Node {
  final Set<Node> _currentDeps = .new();

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
    final curr = _currentDeps;

    final removed = old.difference(curr);
    final added = curr.difference(old);

    for (final parent in removed) {
      if (parent is Downstream) {
        parent.downstreamNodes.remove(this);
      }
    }

    for (final parent in added) {
      if (parent is Downstream) {
        parent.downstreamNodes.add(this);
      }
    }

    old
      ..clear()
      ..addAll(curr);

    int maxDepth = -1;
    for (final node in curr) {
      if (node.depth > maxDepth) {
        maxDepth = node.depth;
      }
    }

    depth = maxDepth + 1;

    _currentDeps.clear();
  }

  void refresh();
}
