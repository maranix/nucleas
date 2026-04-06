import 'package:meta/meta.dart';
import 'package:valence/src/constants.dart';
import 'package:valence/src/core/node/action.dart';
import 'package:valence/src/core/scope.dart';
import 'package:valence/src/utils/equality.dart';

part 'mixin.dart';

/// The universal contract for any node that can be subscribed to.
abstract interface class Subscribable<T> {
  T call();
}

abstract class Node {
  Node({ValenceScope? scope, String? label})
    : _scope = Scope.of(scope ?? Valence.scope),
      _label = label {
    _scope.registry.registerNode(this);
  }

  final Scope _scope;

  final String? _label;

  String get label => _label ?? runtimeType.toString();

  bool _disposed = false;

  /// Whether this node was disposed.
  bool get disposed => _disposed;

  /// Marks this node as disposed and tear down its dependents & dependencies
  @mustCallSuper
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _scope.registry.destroy(this);
  }
}

abstract base class SourceNode<T, A extends Action<T>> extends Node
    with DownstreamChain<SelectorNode> {
  SourceNode(this._state, {super.scope, super.label});

  T _state;

  void dispatch(A action) {
    final next = action.reduce(_state);

    if (_state == next) return;

    _state = next;

    for (final selector in downstream) {
      selector.notify();
    }
  }
}

abstract base class SelectorNode<T, S> extends Node
    with Value<T>, Listener<T>, DownstreamChain<Schedulable>, Lazy {
  SelectorNode(
    this._store,
    this._fn, {
    Scope? scope,
    bool Function(T, T)? equals,
    super.label,
  }) : _equals = equals ?? defaultEquals,
       super(scope: scope ?? _store._scope) {
    _store.downstream.add(this);
  }

  final SourceNode<S, Action<S>> _store;

  final T Function(S) _fn;

  final bool Function(T a, T b) _equals;

  SourceNode<S, Action<S>> get store => _store;

  @override
  T call() {
    if (!_initialized) {
      _value = _fn(_store._state);
      markInitialized();
    }

    return super.call();
  }

  void notify() {
    // There is no need to refresh this node since its value was never read
    if (!_initialized) return;

    final nextVal = _fn(_store._state);

    if (_initialized && _equals(_value, nextVal)) return;

    _value = nextVal;

    _scope.scheduler.scheduleNodes(downstream);

    _notifyListeners();
  }

  @override
  void dispose() {
    _listeners.clear();
    super.dispose();
  }
}

abstract base class RelayNode<T> extends Node
    with
        Value<T>,
        Listener<T>,
        DownstreamChain<Schedulable>,
        UpstreamChain,
        Schedulable,
        Lazy {
  RelayNode(this._fn, {super.scope, super.label});

  final T Function(S Function<S>(Subscribable<S>) sub) _fn;

  @override
  T call() {
    if (!_initialized) {
      _value = _fn(_listen);
      _commitDeps();
      markInitialized();
    }

    return super.call();
  }

  @override
  void refresh() {
    // There is no need to refresh this node since its value was never read
    if (!_initialized) return;

    _value = _fn(_listen);

    _commitDeps();
    _scope.scheduler.scheduleNodes(downstream);

    _notifyListeners();
  }

  @override
  void dispose() {
    _listeners.clear();
    super.dispose();
  }
}

abstract base class ObserverNode extends Node with UpstreamChain, Schedulable {
  ObserverNode(this._fn, {super.scope, super.label}) {
    refresh();
  }

  final void Function(S Function<S>(Subscribable<S>) sub) _fn;

  @override
  void refresh() {
    _fn(_listen);
    _commitDeps();
  }
}
