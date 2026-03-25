import 'package:valence/src/engine/node.dart';
import 'package:valence/types.dart';

abstract interface class Schedular {
  factory Schedular() = _SchedularImpl;

  bool get isBatching;

  void enqueue(Dependent node);
  void cancel(int id);
  void batch(VoidCallback batchFn);
}

final class _SchedularImpl implements Schedular {
  int _batchDepth = 0;
  bool _isFlushing = false;

  // Buckets: index is depth. e.g., _buckets[3] contains all nodes with depth 3.
  final List<List<Dependent>> _buckets = [];
  final List<bool> _mask = [];

  int _minDepth = -1;
  int _maxDepth = -1;

  @override
  bool get isBatching => _batchDepth > 0;

  @override
  void enqueue(Dependent node) {
    // 1. O(1) Deduplication
    if (node.id < _mask.length && _mask[node.id]) return;

    // Grow mask
    if (node.id >= _mask.length) {
      _mask.addAll(List.filled((node.id - _mask.length) + 64, false));
    }
    _mask[node.id] = true;

    // 2. O(1) Bucket Placement (No sorting!)
    final d = node.depth;
    if (d >= _buckets.length) {
      _buckets.addAll(List.generate((d - _buckets.length) + 1, (_) => []));
    }
    _buckets[d].add(node);

    // Track range to avoid scanning empty buckets
    if (_minDepth == -1 || d < _minDepth) _minDepth = d;
    if (d > _maxDepth) _maxDepth = d;

    if (_batchDepth == 0 && !_isFlushing) _flush();
  }

  @override
  void cancel(int id) {
    if (id < _mask.length && _mask[id]) {
      _mask[id] = false;
    }
  }

  @override
  void batch(VoidCallback batchFn) {
    _batchDepth++;

    try {
      batchFn();
    } finally {
      _batchDepth--;

      // Don't auto-flush if we are already in the middle of a flush!
      if (_batchDepth == 0 && _buckets.isNotEmpty && !_isFlushing) {
        _flush();
      }
    }
  }

  void _flush() {
    _isFlushing = true;
    try {
      int d = _minDepth;

      while (d != -1 && d <= _maxDepth) {
        _minDepth = -1; // Reset to catch any newly enqueued minimums

        if (d >= _buckets.length || _buckets[d].isEmpty) {
          d++;
          continue;
        }

        final nodes = List<Dependent>.from(_buckets[d]);
        _buckets[d].clear();

        for (var i = 0; i < nodes.length; i++) {
          final node = nodes[i];

          if (!_mask[node.id]) continue;

          _mask[node.id] = false;
          node.recompute();
        }

        // Did a recompute enqueue a dependency at a shallower depth?
        if (_minDepth != -1 && _minDepth <= d) {
          d = _minDepth; // Jump back to maintain topological order
        } else {
          d++; // Move to the next depth bucket
        }
      }
    } finally {
      _isFlushing = false;
      _minDepth = -1;
      _maxDepth = -1;
    }
  }
}
