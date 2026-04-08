import 'package:valence/src/constants.dart';
import 'package:valence/src/core/node/nodes.dart';
import 'package:valence/src/core/scope.dart';
import 'package:valence/src/types.dart';

Store<T, E> store<T, E extends StoreEvent<T>>(
  T val, {
  ValenceScope? scope,
  String? label,
}) => _StoreImpl(
  val,
  scope: scope ?? Valence.scope,
  label: label,
);

abstract interface class StoreEvent<T> implements SourceEvent<T> {}

abstract interface class Store<T, E extends StoreEvent<T>> {
  StoreSlice<R> slice<R>(
    R Function(T) fn, {
    EqualityCallback<R>? equals,
    String? label,
  });

  StoreSlice<T> call();

  void dispatch(E event);

  void dispose();
}

abstract interface class StoreSlice<T> implements Subscribable<T> {
  void addListener(void Function(T) fn);

  void removeListener(void Function(T) fn);

  void dispose();
}

final class _StoreImpl<T, E extends StoreEvent<T>> extends SourceNode<T, E>
    implements Store<T, E> {
  _StoreImpl(super._state, {super.scope, super.label});

  @override
  StoreSlice<T> call() => slice((s) => s);

  @override
  StoreSlice<R> slice<R>(
    R Function(T) fn, {
    EqualityCallback<R>? equals,
    String? label,
  }) => _StoreSliceImpl(this, fn, equals: equals, label: label);
}

final class _StoreSliceImpl<R, T> extends SelectorNode<T, R>
    implements StoreSlice<T> {
  _StoreSliceImpl(super._store, super.fn, {super.equals, super.label});
}
