abstract base class Action<S> {
  const Action();

  String get debugLabel => runtimeType.toString();

  S reduce(S state);

  void onDispatch() {}
}
