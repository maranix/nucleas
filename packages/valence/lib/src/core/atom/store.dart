import 'package:valence/src/constants.dart';
import 'package:valence/src/core/node/action.dart';
import 'package:valence/src/core/node/nodes.dart';
import 'package:valence/src/core/scope.dart';

Store<S, A> store<S, A extends Action<S>>(
  S val, {
  ValenceScope? scope,
  String? label,
}) => _StoreImpl(val, scope: scope ?? Valence.scope, label: label);

abstract interface class Store<S, A extends Action<S>> {
  Select<R> select<R>(R Function(S) fn, {String? label});

  Select<S> call();

  void dispatch(A action);

  void dispose();
}

abstract interface class Select<T> implements Subscribable<T> {
  void addListener(void Function(T) fn);

  void removeListener(void Function(T) fn);

  void dispose();
}

final class _StoreImpl<S, A extends Action<S>> extends SourceNode<S, A>
    implements Store<S, A> {
  _StoreImpl(super._state, {super.scope, super.label});

  @override
  Select<S> call() => select((s) => s);

  @override
  Select<R> select<R>(R Function(S) fn, {String? label}) =>
      _SelectorImpl(this, fn, label: label);
}

final class _SelectorImpl<S, T> extends SelectorNode<T, S>
    implements Select<T> {
  _SelectorImpl(super._store, super.fn, {super.label});
}
