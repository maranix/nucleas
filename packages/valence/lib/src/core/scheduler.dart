import 'dart:async';

import 'package:valence/src/constants.dart';
import 'package:valence/src/core/node/nodes.dart';

abstract interface class NodeScheduler {
  factory NodeScheduler() => _NodeSchedulerImpl();

  void scheduleNode(Schedulable node);

  void scheduleNodes(Iterable<Schedulable> nodes);

  void batch(void Function() fn);

  void addPostFlushListener(Listener node);
}

final class _NodeSchedulerImpl implements NodeScheduler {
  _NodeSchedulerImpl();

  int _lowestQueuedDepth = 0;
  int _batchDepth = 0;

  bool _flushing = false;
  bool get _batching => _batchDepth > 0;
  bool _flushScheduled = false;

  final List<List<Schedulable>> _buckets = [];
  final Set<Listener> _postFlushListeners = .new();

  @override
  void scheduleNode(Schedulable node) {
    if (node.isScheduled) return;
    node.isScheduled = true;

    final depth = node.depth;

    _ensureBucketCapacity(depth);

    _buckets[depth].add(node);

    if (depth < _lowestQueuedDepth) {
      _lowestQueuedDepth = depth;
    }

    _tryFlush();
  }

  @override
  void scheduleNodes(Iterable<Schedulable> nodes) {
    if (nodes.isEmpty) return;

    for (final node in nodes) {
      if (node.isScheduled) continue;
      node.isScheduled = true;

      final depth = node.depth;

      _ensureBucketCapacity(depth);

      _buckets[depth].add(node);

      if (depth < _lowestQueuedDepth) {
        _lowestQueuedDepth = depth;
      }
    }

    _tryFlush();
  }

  @override
  void batch(void Function() fn) {
    _batchDepth++;

    try {
      fn();
    } finally {
      _batchDepth--;

      if (!_batching) {
        _tryFlush();
      }
    }
  }

  @override
  void addPostFlushListener(Listener node) {
    _postFlushListeners.add(node);
  }

  void _ensureBucketCapacity(int depth) {
    while (_buckets.length <= depth) {
      _buckets.add([]);
    }
  }

  void _tryFlush() {
    if (_flushing || _batching || _flushScheduled) return;

    _flushScheduled = true;

    scheduleMicrotask(_flush);
  }

  void _flush() {
    if (_flushing) return;
    _flushScheduled = false;
    _flushing = true;

    int i = 0;
    int d = _lowestQueuedDepth;

    try {
      while (d < _buckets.length) {
        if (++i > Valence.maxCircularDependencyIteration) {
          _flushing = false;
          throw StateError(
            'Valence: Circular dependency detected or infinite update loop. '
            'The scheduler exceeded ${Valence.maxCircularDependencyIteration} iterations.',
          );
        }

        final bucket = _buckets[d];

        if (bucket.isEmpty) {
          d++;
          _lowestQueuedDepth = d;
          continue;
        }

        final node = bucket.removeLast();
        node.isScheduled = false;

        node.refresh();

        if (_lowestQueuedDepth < d) {
          d = _lowestQueuedDepth;
        }
      }

      for (final node in _postFlushListeners) {
        node.notifyListeners();
      }
    } finally {
      _postFlushListeners.clear();

      _lowestQueuedDepth = _buckets.length;
      _flushing = false;
    }
  }
}
