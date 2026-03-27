abstract base class Action<T> {
  const Action({this.label});

  factory Action.run({required T Function(T) handler, String? label}) =
      DelegateAction;

  factory Action.batch({required List<Action<T>> actions, String? label}) =
      BatchAction;

  final String? label;

  String get debugLabel => label ?? runtimeType.toString();

  T reduce(T state);
}

final class DelegateAction<T> extends Action<T> {
  DelegateAction({required this.handler, super.label});

  final T Function(T) handler;

  @override
  T reduce(T state) => handler(state);
}

final class BatchAction<T> extends Action<T> {
  BatchAction({required this.actions, super.label});

  final List<Action<T>> actions;

  @override
  T reduce(T state) {
    var curr = state;
    for (final action in actions) {
      curr = action.reduce(curr);
    }

    return curr;
  }
}
