import 'package:collection/collection.dart';
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

  // TODO(overhead): Think of a way to avoid using Set for de-duplication
  final Set<Dependent> _pendingNodes = {};

  @override
  bool get isBatching => _batchDepth > 0;

  @override
  void enqueue(Dependent node) {
    _pendingNodes.add(node);

    // Auto-flush if we aren't inside a batch
    if (!isBatching) _flush();
  }

  @override
  void batch(VoidCallback batchFn) {
    _batchDepth++;

    try {
      batchFn();
    } finally {
      _batchDepth--;

      if (_batchDepth == 0 && _pendingNodes.isNotEmpty) {
        _flush();
      }
    }
  }

  void _flush() {
    if (_pendingNodes.isEmpty) return;

    // TODO(overhead): Think of a way to avoid sorting and list conversion from set.
    final batch = _pendingNodes.sorted((a, b) => a.depth.compareTo(b.depth));
    _pendingNodes.clear();

    for (final node in batch) {
      node.recompute();
    }
  }
}
