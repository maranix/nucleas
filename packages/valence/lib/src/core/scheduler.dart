import 'dart:async';

import 'package:valence/src/core/node/nodes.dart';

abstract interface class NodeScheduler {
  factory NodeScheduler() => _NodeSchedulerImpl();

  void scheduleNode(SchedulableNode node);

  void scheduleNodes(Iterable<SchedulableNode> nodes);
}

final class _NodeSchedulerImpl implements NodeScheduler {
  _NodeSchedulerImpl();

  final Set<SchedulableNode> _queue = .new();
  final Set<SchedulableNode> _dirtyNodes = .new();

  bool _flushing = false;

  @override
  void scheduleNode(SchedulableNode node) {
    if (_dirtyNodes.contains(node)) return;

    _queue.add(node);
    _dirtyNodes.add(node);

    _tryFlush();
  }

  @override
  void scheduleNodes(Iterable<SchedulableNode> nodes) {
    for (final node in nodes) {
      if (_dirtyNodes.contains(node)) continue;

      _queue.add(node);
      _dirtyNodes.add(node);
    }

    _tryFlush();
  }

  void _tryFlush() {
    if (_flushing) return;

    scheduleMicrotask(_flush);
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
      _dirtyNodes.remove(node);
      node.refresh();
    }

    _flush();
  }
}
