part of 'base.dart';

Store<S, A> store<S, A extends Action<S>>(
  S initial, {
  Scope? scope,
  EqualityCallback<S>? equals,
}) => Store<S, A>(initial, scope: scope, equals: equals);

final class Store<S, A extends Action<S>> extends BaseSource<S> {
  Store(this._value, {super.scope, super.equals});

  S _value;
  final List<S> _history = [];

  S call() {
    _scope.graph.recordSource(this);
    return _value;
  }

  void dispatch(A action) {
    assert(
      !_scope.graph.isTracking,
      'dispatch() called inside a reactive computation.',
    );

    action.onDispatch();

    final next = action.reduce(_value);
    if (_equals(_value, next)) return;

    _history.add(_value);
    _value = next;

    _scope.schedular.batch(() {
      for (var i = 0; i < _dependents.length; i++) {
        _scope.schedular.enqueue(_dependents[i]);
      }
    });
  }

  void undo() {
    if (_history.isEmpty) return;
    _value = _history.removeLast();

    _scope.schedular.batch(() {
      for (var i = 0; i < _dependents.length; i++) {
        _scope.schedular.enqueue(_dependents[i]);
      }
    });
  }
}
