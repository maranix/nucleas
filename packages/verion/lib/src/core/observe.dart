import 'package:verion/src/core/base.dart';
import 'package:verion/src/types.dart';

abstract interface class Observe {
  bool get disposed;

  void dispose();
}

Observe observe(void Function(SubscribeCallback sub) fn, {String? label}) =>
    ObserveBase(fn, label: label);

final class ObserveBase extends VerionBase with Parents implements Observe {
  ObserveBase(this._fn, {super.label}) {
    refresh();
  }

  final void Function(SubscribeCallback sub) _fn;

  // Dynamic Dependency
  //
  // Used for tracking newly subscribed parents when this is refreshed
  List<VerionBase> _subscriptions = [];

  @override
  void refresh() {
    throwOnDisposed("refresh");

    _fn(_subscribe);

    diffSubs(_subscriptions);
    _subscriptions = [];
  }

  S _subscribe<S>(ReadableVerion<S> node) {
    throwOnDisposed("subscribe");

    if (!_subscriptions.contains(node)) {
      _subscriptions.add(node);
    }

    return node.value;
  }
}
