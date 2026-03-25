import 'package:graphs/graphs.dart' as graphs;

import 'package:valence/src/engine/graph.dart';
import 'package:valence/src/engine/node.dart';
import 'package:valence/src/engine/schedular.dart';

abstract interface class Scope {
  factory Scope() = _ScopeImpl;

  Graph get graph;
  Schedular get schedular;

  void addRoot(Source source);
  void dispose();
}

final class _ScopeImpl implements Scope {
  _ScopeImpl({Graph? graph, Schedular? schedular})
    : _graph = graph ?? Graph(),
      _schedular = schedular ?? Schedular();

  final Graph _graph;
  final Schedular _schedular;

  final List<Source> _roots = [];

  @override
  Graph get graph => _graph;

  @override
  Schedular get schedular => _schedular;

  @override
  void addRoot(Source source) => _roots.add(source);

  @override
  void dispose() {
    final sorted = graphs.topologicalSort<Node>(
      _roots,
      (node) => (node is Source) ? node.dependents : const [],
    );

    for (final node in sorted.reversed) {
      node.dispose();
    }

    _roots.clear();
  }
}
