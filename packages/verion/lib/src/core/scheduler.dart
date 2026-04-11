import 'dart:async';

import 'package:verion/src/core/base.dart';
import 'package:verion/src/core/core.dart';
import 'package:verion/src/types.dart';

abstract interface class Scheduler {
  factory Scheduler() = _SchedulerImpl;

  void scheduleNode(VerionBase node);
  void scheduleNodes(Iterable<VerionBase> nodes);
  void schedulePostFlushListener(ListenableVerion nodes);
  void batch(VoidCallback fn);
  void flush();
  void dispose();
}

final class _SchedulerImpl implements Scheduler {
  int _lowestDepth = 0;
  int _batchDepth = 0;

  bool get _batching => _batchDepth > 0;

  bool _flushing = false;
  bool _flushScheduled = false;

  final List<List<VerionBase>> _buckets = [];
  final Set<VerionBase> _queued = .new();
  final Set<ListenableVerion> _listeners = .new();

  @override
  void scheduleNode(VerionBase node) {
    if (node.disposed || _queued.contains(node)) return;

    final depth = node.depth;

    _ensureBucketCapacity(depth);

    _buckets[depth].add(node);
    _queued.add(node);

    _updateLowestDepth(depth);
    _tryFlush();
  }

  @override
  void scheduleNodes(Iterable<VerionBase> nodes) {
    for (final node in nodes) {
      if (node.disposed || _queued.contains(node)) continue;

      final depth = node.depth;

      _ensureBucketCapacity(depth);

      _buckets[depth].add(node);
      _queued.add(node);

      _updateLowestDepth(depth);
    }

    _tryFlush();
  }

  @override
  void schedulePostFlushListener(ListenableVerion node) {
    if (node.disposed || _listeners.contains(node)) return;

    _listeners.add(node);
  }

  @override
  void batch(VoidCallback fn) {
    _batchDepth += 1;

    try {
      fn();
    } finally {
      _batchDepth -= 1;

      if (!_batching) {
        _tryFlush();
      }
    }
  }

  @override
  void flush() {
    if (_flushing) return;

    _flushing = true;
    _flushScheduled = false;

    int i = 0;
    int d = _lowestDepth;

    try {
      while (d < _buckets.length) {
        final bucket = _buckets[d];

        // If this bucket is empty move to the next one
        if (bucket.isEmpty) {
          d += 1;
          _lowestDepth = d;
          continue;
        }

        final node = bucket.removeLast();
        if (i > 100_000) {
          throw VerionCircularDependencyDetected(node);
        }

        _queued.remove(node);

        if (node.disposed) continue;

        node.refresh();

        // If a new node was queued at a lower at a depth during flush
        // rewind back and start flushing from [_lowestDepth] to maintain consistency
        if (_lowestDepth < d) {
          d = _lowestDepth;
        }

        i += 1;
      }
    } finally {
      _flushing = false;
      _lowestDepth = 0;

      for (final listener in _listeners) {
        listener.notifyListeners();
      }

      _listeners.clear();
    }
  }

  @override
  void dispose() {
    _batchDepth = 0;
    _lowestDepth = 0;
    _flushing = false;
    _flushScheduled = false;

    _listeners.clear();
    _queued.clear();
    _buckets.clear();
  }

  void _tryFlush() {
    if (_flushing || _batching || _flushScheduled) return;

    _flushScheduled = true;

    scheduleMicrotask(flush);
  }

  void _ensureBucketCapacity(int depth) {
    while (depth >= _buckets.length) {
      _buckets.add([]);
    }
  }

  void _updateLowestDepth(int depth) {
    if (_queued.isEmpty || depth < _lowestDepth) {
      _lowestDepth = depth;
    }
  }
}
