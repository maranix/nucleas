import 'dart:async';

import 'package:valence/src/core/node/nodes.dart';

abstract interface class NodeScheduler {
  factory NodeScheduler() => _NodeSchedulerImpl();

  void scheduleNode(Node node);

  void scheduleNodes(List<Node> nodes);
}

final class _NodeSchedulerImpl implements NodeScheduler {
  _NodeSchedulerImpl();

  final Set<Node> _queue = .new();
  final Set<Node> _dirtyNodes = .new();

  bool _flushing = false;

  @override
  void scheduleNode(Node node) {
    if (_dirtyNodes.contains(node)) return;

    _queue.add(node);
    _dirtyNodes.add(node);

    if (!_flushing) {
      scheduleMicrotask(_flush);
    }
  }

  @override
  void scheduleNodes(List<Node> nodes) {
    for (final node in nodes) {
      _queue.add(node);
      _dirtyNodes.add(node);
    }

    if (!_flushing) {
      scheduleMicrotask(_flush);
    }
  }

  void _flush() {
    if (_queue.isEmpty) {
      _flushing = false;
      return;
    }

    _flushing = true;

    final batch = _queue.toList();
    _queue.clear();

    batch.sort((a, b) {
      return a.depth.compareTo(b.depth);
    });

    for (final node in batch) {
      if (node is! Refreshable) continue;

      _dirtyNodes.remove(node);
      node.refresh();
    }

    _flush();
  }
}
