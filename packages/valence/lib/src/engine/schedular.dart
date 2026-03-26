import 'package:valence/src/engine/node.dart';
import 'package:valence/types.dart';

abstract interface class Schedular {
  factory Schedular() = _SchedularImpl;

  bool get isBatching;

  void enqueue(Dependent node);
  void enqueueAll(List<Dependent> nodes);
  void batch(VoidCallback batchFn);
}

final class _SchedularImpl implements Schedular {
  int _batchDepth = 0;
  bool _isFlushing = false;

  int _minDepth = -1;
  int _maxDepth = -1;

  List<Dependent> _queue = [];
  List<Dependent> _processingQueue = [];

  @override
  bool get isBatching => _batchDepth > 0;

  @pragma('vm:prefer-inline')
  @override
  void enqueue(Dependent node) {
    _enqueueDependent(node);
    _flushIfReady();
  }

  @pragma('vm:prefer-inline')
  @override
  void enqueueAll(List<Dependent> nodes) {
    if (nodes.isEmpty) return;

    _batchDepth++;

    for (var i = 0; i < nodes.length; i++) {
      _enqueueDependent(nodes[i]);
    }

    _batchDepth--;

    _flushIfReady();
  }

  @pragma('vm:prefer-inline')
  @override
  void batch(VoidCallback batchFn) {
    _batchDepth++;

    try {
      batchFn();
    } finally {
      _batchDepth--;

      _flushIfReady();
    }
  }

  @pragma('vm:prefer-inline')
  void _enqueueDependent(Dependent node) {
    if (node.isLeaf && !isBatching) {
      node.recompute();
      return;
    }

    if (node.isScheduled || node.disposed) return;

    node.isScheduled = true;
    _queue.add(node);

    final d = node.depth;
    if (_minDepth == -1 || d < _minDepth) _minDepth = d;
    if (d > _maxDepth) _maxDepth = d;
  }

  @pragma("vm:prefer-inline")
  void _flushIfReady() {
    if (_queue.isEmpty) return;
    if (isBatching) return;
    if (_isFlushing) return;

    _flush();
  }

  void _flush() {
    _isFlushing = true;

    while (_queue.isNotEmpty) {
      if (_minDepth != _maxDepth) {
        _queue.sort((a, b) => a.depth.compareTo(b.depth));
      }

      final batch = _queue;
      _queue = _processingQueue;
      _processingQueue = batch;

      _minDepth = -1;
      _maxDepth = -1;

      for (var i = 0; i < batch.length; i++) {
        final node = batch[i];
        if (!node.isScheduled || node.disposed) continue;

        node.isScheduled = false;
        node.recompute();
      }

      _processingQueue = [];
    }

    _isFlushing = false;
  }
}
