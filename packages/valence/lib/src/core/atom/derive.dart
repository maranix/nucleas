import 'package:valence/src/core/node/nodes.dart';
import 'package:valence/src/core/scope.dart';
import 'package:valence/src/types.dart';

Derive<T> derive<T>(
  T Function(SubscribeCallback) fn, {
  ValenceScope? scope,
  String? label,
}) => _DeriveImpl(fn, scope: scope, label: label);

abstract interface class Derive<T> implements Subscribable<T> {
  void addListener(void Function(T) fn);

  void removeListener(void Function(T) fn);

  void dispose();
}

final class _DeriveImpl<T> extends RelayNode<T> implements Derive<T> {
  _DeriveImpl(super._fn, {super.scope, super.label});
}
