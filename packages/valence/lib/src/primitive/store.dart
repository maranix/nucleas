part of 'base.dart';

Store<S> store<S>(
  S initial, {
  Scope? scope,
  EqualityCallback<S>? equals,
}) => Store<S>(initial, scope: scope, equals: equals);

final class Store<S> extends BaseSource<S> {
  Store(this._value, {super.scope, super.equals});

  S _value;
  final List<S> _history = [];

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
  }

  void undo() {
    if (_history.isEmpty) return;
    _value = _history.removeLast();
    for (var i = 0; i < _dependents.length; i++) {
      _scope.schedular.enqueue(_dependents[i]);
    }
  }
}
