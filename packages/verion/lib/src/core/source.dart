import 'package:meta/meta.dart';
import 'package:verion/src/core/base.dart';
import 'package:verion/src/core/core.dart';
import 'package:verion/src/observer.dart';
import 'package:verion/src/types.dart';
import 'package:verion/src/utils/equality.dart';

abstract interface class Source<T, E extends SourceEvent<T>>
    implements ReadableVerion<T> {
  void dispatch(E event);

  void addListener(ValueCallback<T> fn);
  void removeListener(ValueCallback<T> fn);
  void notifyListeners();
}

Source<T, E> source<T, E extends SourceEvent<T>>(
  T value, {
  EqualityCallback<T>? notifyWhen,
  String? label,
}) => SourceBase(value, notifyWhen: notifyWhen, label: label);

mixin SourceEvent<T> {
  @mustBeOverridden
  T reduce(T value);
}

final class SourceBase<T, E extends SourceEvent<T>> extends ReadableVerion<T>
    with ListenableVerion<T>, Children
    implements Source<T, E> {
  SourceBase(this._value, {EqualityCallback<T>? notifyWhen, super.label})
    : _equals = notifyWhen ?? defaultEquals {
    /// Register this in the graph

    // Notify observer
    VerionObserver.instance?.onSourceCreated(this, value);
  }

  T _value;

  final EqualityCallback<T> _equals;

  @override
  int get depth => 0;

  @override
  T get value {
    throwOnDisposed("read");

    return _value;
  }

  @override
  void refresh() {
    throw VerionUnsupportedOperationError(this, "refresh");
  }

  @override
  void dispatch(E event) {
    throwOnDisposed("dispatch");

    final next = event.reduce(value);

    if (_equals(next, value)) return;

    // Notify observer
    VerionObserver.instance?.onSourceUpdated(this, event, _value, next);

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
    // Notify observer
    VerionObserver.instance?.onSourceDiposed(this);

    super.dispose();
  }

  @override
  void updateDepth(int parentDepth) {
    throw VerionUnsupportedOperationError(
      this,
      "updateDepth. A Source node is a root and cannot have its depth modified.",
    );
  }
}
