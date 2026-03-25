import 'package:valence/src/engine/node.dart';
import 'package:valence/types.dart';

final class GraphFrame {
  final int epoch;

  final List<Source> sources = [];

  GraphFrame(this.epoch);
}

abstract interface class Graph {
  factory Graph() = _GraphImpl;

  /// Whether a computation is currently being tracked.
  bool get isTracking;

  /// Executes a computation and returns the unique sources read.
  List<Source> track(VoidCallback computation);

  /// Records a source as a dependency in the current tracking context.
  void record(Source source);
}

final class _GraphImpl implements Graph {
  final List<GraphFrame> _stack = [];

  int _currentEpoch = 0;

  @override
  bool get isTracking => _stack.isNotEmpty;

  @override
  List<Source> track(VoidCallback computation) {
    _currentEpoch++;

    final frame = GraphFrame(_currentEpoch);
    _stack.add(frame);

    try {
      computation();
      return frame.sources;
    } finally {
      _stack.removeLast();
    }
  }

  @override
  void record(Source source) {
    if (_stack.isEmpty) return;

    final currFrame = _stack.last;
    if (source.lastAccessedEpoch == currFrame.epoch) return;

    source.lastAccessedEpoch = currFrame.epoch;
    currFrame.sources.add(source);
  }
}
