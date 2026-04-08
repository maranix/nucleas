part of 'nodes.dart';

mixin Value<T> on Node implements Subscribable<T> {
  late T _value;

  @override
  T call() => _value;
}

mixin UpstreamChain<T extends Node> on Node {
  List<T> upstream = [];
}

mixin DownstreamChain<T extends Node> on Node {
  List<T> downstream = [];
}

mixin Listener<T> on Value<T> implements Subscribable<T> {
  final List<void Function(T)> _listeners = [];

  void addListener(void Function(T) fn) => _listeners.add(fn);

  void removeListener(void Function(T) fn) => _listeners.remove(fn);

  void _scheduleListeners() {
    if (_listeners.isEmpty) return;

    _scope.scheduler.addPostFlushListener(this);
  }

  void notifyListeners() {
    final listeners = _listeners.toList();

    for (final listener in listeners) {
      try {
        listener(_value);
      } catch (e, s) {
        Valence.reportError(e, s);
      }
    }
  }
}

mixin Schedulable on Node, UpstreamChain {
  int depth = 0;

  bool isScheduled = false;

  final List<Node> _currentDeps = [];

  S _listen<S>(Subscribable<S> node) {
    _currentDeps.add(node as Node);
    return node();
  }

  void _commitDeps() {
    final currDeps = upstream;
    final newDeps = _currentDeps;

    bool changed = currDeps.length != newDeps.length;

    if (!changed) {
      for (int i = 0; i < currDeps.length; i++) {
        if (currDeps[i] != newDeps[i]) {
          changed = true;
          break;
        }
      }
    }

    if (!changed) {
      _currentDeps.clear();
      return;
    }

    for (final parent in currDeps) {
      if (!newDeps.contains(parent) && parent is DownstreamChain) {
        parent.downstream.remove(this);
      }
    }

    int maxDepth = -1;
    for (final parent in newDeps) {
      if (!currDeps.contains(parent) && parent is DownstreamChain) {
        parent.downstream.add(this);
      }

      if (parent is Schedulable && parent.depth > maxDepth) {
        maxDepth = parent.depth;
      }
    }

    upstream = newDeps.toList();

    _updateDepth(maxDepth + 1);

    _currentDeps.clear();
  }

  void _updateDepth(int newDepth) {
    if (newDepth <= depth) return;

    depth = newDepth;

    if (this is DownstreamChain<Schedulable>) {
      for (final child in (this as DownstreamChain<Schedulable>).downstream) {
        final requiredChildDepth = depth + 1;

        if (child.depth < requiredChildDepth) {
          child._updateDepth(requiredChildDepth);
        }
      }
    }
  }

  void refresh();
}

mixin Lazy {
  bool _initialized = false;

  void markInitialized() {
    _initialized = true;
  }
}
