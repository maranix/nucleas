import 'package:meta/meta.dart';
import 'package:valence/src/constants.dart';
import 'package:valence/src/core/node/action.dart';
import 'package:valence/src/core/scope.dart';

part 'mixin.dart';

/// The universal contract for any node that can be subscribed to.
abstract interface class Listenable<T> {
  T get value;
}

abstract class Node {
  Node({Scope? scope, String? label})
    : _scope = (scope ?? rootScope),
      _label = label {
    _scope.registry.registerNode(this);
  }

  final Scope _scope;

  final String? _label;

  String get label => _label ?? runtimeType.toString();

  bool _disposed = false;

  /// Whether this node was disposed.
  bool get disposed => _disposed;

  // Depth of this node, in the Graph
  int depth = 0;

  /// Marks this node as disposed and tear down its dependents & dependencies
  @mustCallSuper
  void dispose() {
    if (_disposed) return;

    depth = 0;
    _disposed = true;

    _scope.registry.destroy(this);
  }
}

abstract base class SourceNode<T, A extends Action<T>> extends Node
    with Downstream<SelectorNode> {
  SourceNode(this._state, {super.scope, super.label});

  T _state;

  Scope get scope => _scope;

  void dispatch(A action) {
    final next = action.reduce(_state);

    if (identical(_state, next)) return;

    _state = next;

    for (final selector in downstreamNodes) {
      selector.notify();
    }
  }
}

abstract base class SelectorNode<T, S> extends Node
    with ListenableNode<T>, Downstream {
  SelectorNode(this._store, this._fn, {super.scope, super.label}) {
    _cachedValue = _fn(_store._state);
    _store.downstreamNodes.add(this);
  }

  final SourceNode<S, Action<S>> _store;

  final T Function(S) _fn;

  SourceNode<S, Action<S>> get store => _store;

  void notify() {
    final nextVal = _fn(_store._state);

    if (identical(nextVal, _cachedValue)) return;

    _cachedValue = nextVal;

    _scheduleDownstreamNodes();
  }
}

abstract base class RelayNode<T> extends Node
    with ListenableNode<T>, Upstream, Downstream, Refreshable {
  RelayNode(this._fn, {super.scope, super.label}) {
    _cachedValue = _fn(_listen);
    _commitDeps();
  }

  final T Function(S Function<S>(Listenable<S>) sub) _fn;

  @override
  void refresh() {
    _cachedValue = _fn(_listen);

    _commitDeps();
    _scheduleDownstreamNodes();
  }
}

abstract base class ObserverNode extends Node with Upstream, Refreshable {
  ObserverNode(this._fn, {super.scope, super.label}) {
    refresh();
  }

  final void Function(S Function<S>(Listenable<S>) sub) _fn;

  @override
  void refresh() {
    _fn(_listen);
    _commitDeps();
  }
}
