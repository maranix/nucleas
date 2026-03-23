import 'package:valence/src/engine/node.dart';

abstract interface class Schedular {
  factory Schedular() = _SchedularImpl;

  bool get isBatching;

  void beginBatch();
  bool endBatch();

  void enqueue(ReactiveNode node);
  void flush();
}

final class _SchedularImpl implements Schedular {
  int _batchDepth = 0;

  final List<ReactiveNode> _pendingNodes = [];

  @override
  bool get isBatching => _batchDepth > 0;

  @override
  void beginBatch() => _batchDepth++;

  @override
  bool endBatch() {
    _batchDepth--;
    return _batchDepth == 0;
  }

  @override
  void enqueue(ReactiveNode node) {
    if (node.isPending) return;

    node.isPending = true;

    if (_pendingNodes.isEmpty) {
      _pendingNodes.add(node);
      return;
    }

    var i = _pendingNodes.length;
    while (i >= 0 && _pendingNodes[i - 1].depth > node.depth) {
      i--;
    }

    if (i == _pendingNodes.length) {
      _pendingNodes.add(node);
    } else {
      _pendingNodes.insert(i, node);
    }
  }

  @override
  void flush() {
    var i = 0;
    while (i < _pendingNodes.length) {
      final node = _pendingNodes[i];

      node.isPending = false;
      node.recompute();
      i++;
    }

    _pendingNodes.clear();
  }
}
