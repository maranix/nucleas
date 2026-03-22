abstract interface class Node {
  void addDependent(ReactiveNode node);
  void removeDependent(ReactiveNode node);
}

abstract interface class ReactiveNode implements Node {
  int get depth;
  void recompute();
}
