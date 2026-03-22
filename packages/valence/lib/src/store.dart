import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

import 'core.dart';
import 'scope.dart';
import 'reducer.dart';

final class Store<S> implements Node {
  Store(this._scope, this._value, {EqualityCallback<S>? equals})
    : _equals = equals ?? defaultEquals;

  final Scope _scope;
  S _value;

  final EqualityCallback<S> _equals;
  final List<S> _history = [];
  final Set<ReactiveNode> _dependents = {};

  @override
  void addDependent(ReactiveNode node) => _dependents.add(node);

  @override
  void removeDependent(ReactiveNode node) => _dependents.remove(node);

  S call() {
    _scope.recordRead(this);
    return _value;
  }

  void dispatch(Reducer<S> reducer) {
    assert(
      !_scope.isTracking,
      'dispatch() called inside a reactive computation.',
    );

    final next = reducer.reduce(_value);
    if (_equals(_value, next)) return;

    _history.add(_value);
    _value = next;

    for (final dep in _dependents) {
      _scope.enqueue(dep);
    }
    if (!_scope.isBatching) _scope.flushPending();
  }

  void undo() {
    if (_history.isEmpty) return;
    _value = _history.removeLast();
    for (final dep in _dependents) {
      _scope.enqueue(dep);
    }
    if (!_scope.isBatching) _scope.flushPending();
  }

  void dispose() {
    _dependents.clear();
  }
}
