import 'package:valence/src/primitive/derive.dart';
import 'package:valence/src/primitive/store.dart';
import 'package:valence/src/primitive/reactor.dart';
import 'package:valence/src/engine/graph.dart';
import 'package:valence/src/engine/registry.dart';
import 'package:valence/src/engine/schedular.dart';

abstract interface class Scope {
  factory Scope() = _ScopeImpl;

  Graph get graph;
  Schedular get schedular;

  void registerStore(Store store);
  void registerDerive(Derive store);
  void registerReactor(Reactor store);

  void dispose();
}

final class _ScopeImpl implements Scope {
  _ScopeImpl({Graph? graph, Schedular? schedular})
    : _graph = graph ?? Graph(),
      _schedular = schedular ?? Schedular(),
      _registry = Registry();

  final Graph _graph;
  final Schedular _schedular;
  final Registry _registry;

  @override
  Graph get graph => _graph;

  @override
  Schedular get schedular => _schedular;

  @override
  void registerDerive(Derive derive) => _registry.registerDerive(derive);

  @override
  void registerReactor(Reactor reactor) => _registry.registerReactor(reactor);

  @override
  void registerStore(Store store) => _registry.registerStore(store);

  @override
  void dispose() => _registry.dispose();
}
