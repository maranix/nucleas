import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

import '../engine/node.dart';
import '../config.dart';
import '../engine/scope.dart';
import 'reducer.dart';

Store<S> store<S>(
  S initial, {
  Scope? scope,
  EqualityCallback<S>? equals,
}) => Store<S>(initial, scope: scope, equals: equals);

final class Store<S> implements Node {
  Store(this._value, {Scope? scope, EqualityCallback<S>? equals})
    : _scope = scope ?? Valence.root,
      _equals = equals ?? defaultEquals {
    _scope.registerStore(this);
  }

  final Scope _scope;
  S _value;

  final EqualityCallback<S> _equals;
  final List<S> _history = [];
  final List<ReactiveNode> _dependents = [];

  @override
  void addDependent(ReactiveNode node) => _dependents.add(node);

  @override
  void removeDependent(ReactiveNode node) {
    final i = _dependents.indexOf(node);
    if (i < 0) return;

    _dependents[i] = _dependents.last;
    _dependents.removeLast();
  }

  S call() {
    _scope.graph.recordSource(this);
    return _value;
  }

  void dispatch(Reducer<S> reducer) {
    assert(
      !_scope.graph.isTracking,
      'dispatch() called inside a reactive computation.',
    );

    final next = reducer.reduce(_value);
    if (_equals(_value, next)) return;

    _history.add(_value);
    _value = next;

    for (var i = 0; i < _dependents.length; i++) {
      _scope.schedular.enqueue(_dependents[i]);
    }

    if (!_scope.schedular.isBatching) _scope.schedular.flush();
  }

  void undo() {
    if (_history.isEmpty) return;
    _value = _history.removeLast();
    for (var i = 0; i < _dependents.length; i++) {
      _scope.schedular.enqueue(_dependents[i]);
    }
    if (!_scope.schedular.isBatching) _scope.schedular.flush();
  }

  void dispose() {
    _dependents.clear();
  }
}
