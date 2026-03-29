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

  bool get disposed;
  void dispose();
}

/// Creates a new [Store].
Store<S, A> store<S, A extends Action<S>>(
  S initial, {
  Scope? scope,
  EqualityCallback<S>? equals,
  FilterCallback<S>? filter,
  String? debugLabel,
}) => _StoreImpl<S, A>(
  initial,
  scope: scope,
  eq: equals,
  filter: filter,
  debugLabel: debugLabel,
);

final class _StoreImpl<S, A extends Action<S>> extends OriginNode<S>
    implements Store<S, A> {
  _StoreImpl(
    this._value, {
    Scope? scope,
    EqualityCallback<S>? eq,
    FilterCallback<S>? filter,
    super.debugLabel,
  }) : assert(
         _value is! Node,
         'Type Error: Illegal attempt to store a reactive Node as state.'
         '\n'
         '\nStore, Derive, and Reaction define the graph structure and cannot'
         '\nbe contained within another Store. To combine sources, use a Derive instead.',
       ),
       _scope = scope ?? Valence.root,
       _equals = eq ?? defaultEquals,
       _filter = filter {
    _scope.addRoot(this);
  }

  final Scope _scope;
  final EqualityCallback<S> _equals;
  final FilterCallback<S>? _filter;

  S _value;

  @override
  Scope get scope => _scope;

  @override
  EqualityCallback<S> get equals => _equals;

  @override
  FilterCallback<S>? get filter => _filter;

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
      'Type Error: Illegal attempt to dispatch an action from within a reactive computation.'
      '\n'
      '\nDispatching actions from within a reactive computation can lead to'
      '\nnon-deterministic behavior and infinite loops.',
    );

    final next = action.reduce(_value);
    assert(
      next is! Node,
      'Type Error: Illegal attempt to store a reactive Node as state.',
    );

    if (equals(_value, next)) return;
    if (filter != null && !filter!(next)) return;

    _value = next;

    notifyDependents();
  }
}
