import 'dart:async';

import 'package:collection/collection.dart';
import 'package:valence/src/core/node/nodes.dart';

abstract interface class NodeScheduler {
  factory NodeScheduler() => _NodeSchedulerImpl();

  void scheduleNode(SchedulableNode node);

  void scheduleNodes(Iterable<SchedulableNode> nodes);
}

final class _NodeSchedulerImpl implements NodeScheduler {
  _NodeSchedulerImpl();

  final PriorityQueue<SchedulableNode> _queue = .new(
    (a, b) => a.depth.compareTo(b.depth),
  );

  bool _flushing = false;

  @override
  void scheduleNode(SchedulableNode node) {
    if (node.isScheduled) return;

    node.isScheduled = true;
    _queue.add(node);

    _tryFlush();
  }

  @override
  void scheduleNodes(Iterable<SchedulableNode> nodes) {
    for (final node in nodes) {
      if (node.isScheduled) continue;

      node.isScheduled = true;
      _queue.add(node);
    }

    _tryFlush();
  }

  void _tryFlush() {
    if (_flushing) return;

    scheduleMicrotask(_flush);
  }

  void _flush() {
    if (_flushing) return;

    _flushing = true;

    while (_queue.isNotEmpty) {
      final node = _queue.removeFirst();
      node.isScheduled = false;

      node.refresh();
    }

    _flushing = false;
  }
}
