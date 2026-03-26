import 'package:valence/src/config.dart';
import 'package:valence/src/engine/node.dart';
import 'package:valence/src/engine/scope.dart';
import 'package:valence/src/primitive/action.dart';
import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

/// Public interface for a reactive store.
///
/// Provides read access via [call], state mutation via [dispatch],
/// undo support, and lifecycle management.
abstract interface class Store<S, A extends Action<S>> {
  S call();
  void dispatch(A action);
  void undo();
  bool get disposed;
  void dispose();
}

/// Creates a new [Store].
Store<S, A> store<S, A extends Action<S>>(
  S initial, {
  Scope? scope,
  EqualityCallback<S>? equals,
}) => _StoreImpl<S, A>(initial, scope: scope, eq: equals);

final class _StoreImpl<S, A extends Action<S>>
    with DisposeMixin, SourceMixin, EqualityMixin<S>
    implements Source, Store<S, A> {
  _StoreImpl(this._value, {Scope? scope, EqualityCallback<S>? eq})
    : _scope = scope ?? Valence.root,
      _equals = eq ?? defaultEquals {
    _scope.addRoot(this);
  }

  final Scope _scope;
  final EqualityCallback<S> _equals;

  S _value;
  final List<S> _history = [];

  @override
  int get depth => 0;

  @override
  Scope get scope => _scope;

  @override
  EqualityCallback<S> get equals => _equals;

  @override
  S call() {
    reportRead();
    return _value;
  }

  @override
  void dispatch(A action) {
    assert(!disposed, 'Cannot dispatch an action to a disposed Store.');
    assert(
      !scope.graph.isTracking,
      'dispatch() called inside a reactive computation.',
    );

    action.onDispatch();

    final next = action.reduce(_value);
    if (equals(_value, next)) return;

    _history.add(_value);
    _value = next;

    notifyDependents();
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    _value = _history.removeLast();

    notifyDependents();
  }

  @override
  void dispose() {
    if (disposed) return;
    markDisposed();
    clearDependents();
  }
}
