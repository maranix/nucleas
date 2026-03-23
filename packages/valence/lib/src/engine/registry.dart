import 'package:valence/src/primitive/store.dart';
import 'package:valence/src/primitive/derive.dart';
import 'package:valence/src/primitive/reactor.dart';

abstract interface class Registry {
  factory Registry() = _RegistryImpl;

  void registerStore(Store store);
  void registerDerive(Derive derive);
  void registerReactor(Reactor reactor);

  void dispose();
}

final class _RegistryImpl implements Registry {
  final List<Store> _storeList = [];
  final List<Derive> _deriveList = [];
  final List<Reactor> _reactorList = [];

  @override
  void registerDerive(Derive derive) => _deriveList.add(derive);

  @override
  void registerReactor(Reactor reactor) => _reactorList.add(reactor);

  @override
  void registerStore(Store store) => _storeList.add(store);

  @override
  void dispose() {
    for (final s in _storeList) {
      s.dispose();
    }
    for (final r in _reactorList) {
      r.dispose();
    }

    _deriveList.sort((a, b) => b.depth.compareTo(a.depth));

    for (final d in _deriveList) {
      d.dispose();
    }

    _storeList.clear();
    _deriveList.clear();
    _reactorList.clear();
  }
}
