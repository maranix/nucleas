import 'package:valence/src/core/atom/derive.dart';
import 'package:valence/src/core/scope.dart';

typedef PoolFn<K, T> =
    Derive<T> Function(
      K, [
      ValenceScope? scope,
      String? label,
    ]);

Pool<K, T> pool<K, T>(PoolFn<K, T> fn, {ValenceScope? scope, String? label}) =>
    _PoolImpl(fn, scope: scope, label: label);

abstract interface class Pool<K, T> {
  factory Pool(PoolFn<K, T> fn, {ValenceScope? scope, String? label}) =>
      _PoolImpl(fn);

  Derive<T> call(K key);

  void remove(K key);

  void dispose();
}

final class _PoolImpl<K, T> implements Pool<K, T> {
  _PoolImpl(
    this._fn, {
    ValenceScope? scope,
    String? label,
  }) : _scope = scope,
       _label = label;

  final PoolFn<K, T> _fn;

  final Map<K, Derive<T>> _cache = .new();

  final ValenceScope? _scope;

  final String? _label;

  @override
  Derive<T> call(K key) =>
      _cache.putIfAbsent(key, () => _fn(key, _scope, _label));

  @override
  void remove(K key) => _cache.remove(key);

  @override
  void dispose() {
    for (final entry in _cache.entries) {
      entry.value.dispose();
    }

    _cache.clear();
  }
}
