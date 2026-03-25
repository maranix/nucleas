import 'package:valence/src/engine/node.dart';
import 'package:valence/types.dart';

abstract interface class Schedular {
  factory Schedular() = _SchedularImpl;

  bool get isBatching;

  void enqueue(Dependent node);
  void batch(VoidCallback batchFn);
}

final class _SchedularImpl implements Schedular {
  int _batchDepth = 0;
  bool _isFlushing = false;

  final List<Dependent> _queue = [];

  @override
  bool get isBatching => _batchDepth > 0;

  @override
  void enqueue(Dependent node) {
    if (node.isScheduled || node.isDisposed) return;

    node.isScheduled = true;
    _queue.add(node);

    if (_batchDepth == 0 && !_isFlushing) _flush();
  }

  @override
  void batch(VoidCallback batchFn) {
    _batchDepth++;

    try {
      batchFn();
    } finally {
      _batchDepth--;

      // Don't auto-flush if we are already in the middle of a flush!
      if (_batchDepth == 0 && _queue.isNotEmpty && !_isFlushing) {
        _flush();
      }
    }
  }

  void _flush() {
    _isFlushing = true;
    try {
      while (_queue.isNotEmpty) {
        _queue.sort((a, b) => a.depth.compareTo(b.depth));

        final batch = _queue.toList();
        _queue.clear();

        for (var i = 0; i < batch.length; i++) {
          final node = batch[i];
          if (!node.isScheduled || node.isDisposed) continue;

          node.isScheduled = false;
          node.recompute();
        }
      }
    } finally {
      _isFlushing = false;
    }
  }
}
