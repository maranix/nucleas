import 'package:valence/src/engine/node.dart';
import 'package:valence/types.dart';

final class _GraphFrame {
  final int epoch;

  final List<Source> sources = [];

  final _GraphFrame? _parent;

  _GraphFrame(this.epoch, this._parent);
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
  _GraphFrame? _currentFrame;

  int _currentEpoch = 0;

  @override
  bool get isTracking => _currentFrame != null;

  @override
  List<Source> track(VoidCallback computation) {
    _currentEpoch++;

    final frame = _GraphFrame(_currentEpoch, _currentFrame);
    _currentFrame = frame;

    try {
      computation();
      return frame.sources;
    } finally {
      _currentFrame = frame._parent;
    }
  }

  @pragma("vm:prefer-inline")
  @override
  void record(Source source) {
    final frame = _currentFrame;
    if (frame == null) return;

    if (source.lastAccessedEpoch == frame.epoch) return;

    source.lastAccessedEpoch = frame.epoch;
    frame.sources.add(source);
  }
}
