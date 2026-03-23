abstract interface class Node {
  void addDependent(ReactiveNode node);
  void removeDependent(ReactiveNode node);
}

abstract interface class ReactiveNode implements Node {
  int get depth;
  bool get isPending;
  set isPending(bool value);
  void recompute();
}
