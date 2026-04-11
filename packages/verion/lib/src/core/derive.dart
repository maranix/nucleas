import 'package:verion/src/core/base.dart';
import 'package:verion/src/observer.dart';
import 'package:verion/src/types.dart';
import 'package:verion/src/utils/equality.dart';

abstract interface class Derive<T> implements ReadableVerion<T> {
  void addListener(ValueCallback<T> fn);
  void removeListener(ValueCallback<T> fn);
  void notifyListeners();
}

Derive<T> derive<T>(
  T Function(SubscribeCallback sub) fn, {
  EqualityCallback<T>? notifyWhen,
  String? label,
}) => DeriveBase(fn, notifyWhen: notifyWhen, label: label);

final class DeriveBase<T> extends ReadableVerion<T>
    with Parents, Children, ListenableVerion<T>
    implements Derive<T> {
  DeriveBase(this._fn, {EqualityCallback<T>? notifyWhen, super.label})
    : _equals = notifyWhen ?? defaultEquals {
    // Notify observer
    VerionObserver.instance?.onDeriveCreated(this);
  }

  final EqualityCallback<T> _equals;

  final T Function(SubscribeCallback sub) _fn;

  bool _initialized = false;

  late T _value;

  List<VerionBase> _subscriptions = [];

  @override
  T get value {
    throwOnDisposed("read");

    if (!_initialized) {
      _value = _fn(_subscribe);
      _initialized = true;

      diffSubs(_subscriptions);
      _subscriptions = [];
    }

    return _value;
  }

  @override
  void refresh() {
    throwOnDisposed("refresh");

    final next = _fn(_subscribe);

    diffSubs(_subscriptions);
    _subscriptions = [];

    if (_equals(next, value)) return;

    VerionObserver.instance?.onDeriveUpdated(this, _value, next);

    _value = next;

    // Schedule childrens of this node
    if (hasChildren) {
      scope.scheduler.scheduleNodes(children);
    }

    // Schedule listeners of this node to run during post flush operation
    scope.scheduler.schedulePostFlushListener(this);
  }

  @override
  void dispose() {
    VerionObserver.instance?.onDeriveDisposed(this);

    super.dispose();
  }

  @override
  void updateDepth(int parentDepth) {
    super.updateDepth(parentDepth);

    if (hasChildren) {
      for (var i = 0; i < children.length; i++) {
        children[i].updateDepth(depth);
      }
    }
  }

  S _subscribe<S>(ReadableVerion<S> node) {
    throwOnDisposed("subscribe");

    VerionObserver.instance?.onDeriveSubscribed(this, node);

    if (!_subscriptions.contains(node)) {
      _subscriptions.add(node);
    }

    return node.value;
  }
}
