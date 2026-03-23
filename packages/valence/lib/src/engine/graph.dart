import 'package:valence/src/engine/node.dart';

abstract interface class Graph {
  factory Graph() = _GraphImpl;

  bool get isTracking;

  void beginTracking();
  List<Node> endTracking();

  void beginProbe(List<Node> sources);
  bool endProbe(int count);

  void recordSource(Node source);
}

final class _GraphImpl implements Graph {
  List<Node>? _probed;
  int _cursor = 0;
  bool _consistent = true;

  final List<List<Node>> _trackingStack = [];

  @override
  bool get isTracking => _trackingStack.isNotEmpty;

  @override
  void beginTracking() => _trackingStack.add([]);

  @override
  List<Node> endTracking() => _trackingStack.removeLast();

  @override
  void beginProbe(List<Node> sources) {
    _probed = sources;
    _cursor = 0;
    _consistent = true;
  }

  @override
  bool endProbe(int count) {
    _probed = null;
    return _consistent && _cursor == count;
  }

  @override
  void recordSource(Node source) {
    if (_trackingStack.isEmpty) {
      _validateProbedSouce(source);
      return;
    }

    final list = _trackingStack.last;
    for (final node in list) {
      if (identical(node, source)) return;
    }

    list.add(source);
  }

  void _validateProbedSouce(Node source) {
    if (_probed == null || !_consistent) return;

    if (_cursor >= _probed!.length || !identical(_probed![_cursor], source)) {
      _consistent = false;
      return;
    }

    _cursor++;
  }
}
