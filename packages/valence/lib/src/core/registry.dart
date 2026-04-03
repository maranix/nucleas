import 'package:valence/src/core/node/nodes.dart';

abstract interface class NodeRegistry {
  factory NodeRegistry() = _NodeRegistryImpl;

  void registerNode(Node node);

  void destroy(Node node);

  void dispose();
}

final class _NodeRegistryImpl implements NodeRegistry {
  final Set<Node> _nodes = .new();

  @override
  void registerNode(Node node) => _nodes.add(node);

  @override
  void destroy(Node node) {
    if (node is Upstream) {
      for (final parent in node.upstreamNodes.toList()) {
        // Remove itself from the parent nodes downstreamNodes list
        if (parent is Downstream) {
          parent.downstreamNodes.remove(node);
        }
      }

      node.upstreamNodes.clear();
    }

    if (node is SelectorNode) {
      // Remove itself from the list of downstreamNodes from the Store it was dependent on from.
      node.store.downstreamNodes.remove(node);
    }

    List<Node> children = [];

    if (node is Downstream) {
      children = node.downstreamNodes.toList();
      node.downstreamNodes.clear();
    }

    _nodes.remove(node);

    // Tell all the children of this node to dispose
    for (final child in children) {
      child.dispose();
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }

    _nodes.clear();
  }
}
