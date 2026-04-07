import 'package:valence/src/core/node/nodes.dart';
import 'package:valence/src/core/scope.dart';
import 'package:valence/src/types.dart';

Watch watch(
  void Function(SubscribeCallback) fn, {
  ValenceScope? scope,
  String? label,
}) => _WatchImpl(fn, scope: scope, label: label);

abstract interface class Watch {
  void dispose();
}

final class _WatchImpl extends ObserverNode implements Watch {
  _WatchImpl(super._fn, {super.scope, super.label});
}
