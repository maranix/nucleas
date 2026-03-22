import 'core.dart';
import 'reactor.dart';
import 'store.dart';
import 'derive.dart';

final class Scope {
  Scope._root() : _isRoot = true {
    _core = this;
  }
  Scope._child(Scope parent) : _isRoot = false {
    _core = parent._core;
  }

  factory Scope({Scope? parent}) => Scope._child(parent ?? Valence.root);

  final bool _isRoot;

  late final Scope _core;

  // --- Execution & Tracking State ---

  final List<List<Node>> _trackingStack = [];

  bool get isTracking => _core._trackingStack.isNotEmpty;

  void beginTracking() => _core._trackingStack.add([]);

  List<Node> endTracking() => _core._trackingStack.removeLast();

  void recordRead(Node node) {
    if (_core._trackingStack.isEmpty) return;

    final list = _core._trackingStack.last;
    for (var i = 0; i < list.length; i++) {
      if (identical(list[i], node)) return;
    }
    list.add(node);
  }

  // --- Flush Queue & Batching ---

  final List<ReactiveNode> _pendingList = [];
  int _batchDepth = 0;

  bool get isBatching => _core._batchDepth > 0;

  void beginBatch() => _core._batchDepth++;

  bool endBatch() {
    _core._batchDepth--;
    return _core._batchDepth == 0;
  }

  void enqueue(ReactiveNode node) {
    if (node.isPending) return;
    node.isPending = true;

    var i = _core._pendingList.length;
    while (i > 0 && _core._pendingList[i - 1].depth > node.depth) {
      i--;
    }
    if (i == _core._pendingList.length) {
      _core._pendingList.add(node);
    } else {
      _core._pendingList.insert(i, node);
    }
  }

  void flushPending() {
    var i = 0;
    while (i < _core._pendingList.length) {
      final node = _core._pendingList[i++];
      node.isPending = false;
      node.recompute();
    }
    _core._pendingList.clear();
  }

  // --- Ownership ---

  final List<Store> _stores = [];
  final List<Derive> _derives = [];
  final List<Reactor> _reactors = [];

  void registerStore(Store s) => _stores.add(s);
  void registerDerive(Derive d) => _derives.add(d);
  void registerReactor(Reactor r) => _reactors.add(r);

  void dispose() {
    assert(!_isRoot, 'Valence.root cannot be disposed.');

    for (final r in _reactors) {
      r.dispose();
    }
    _derives.sort((a, b) => b.depth.compareTo(a.depth));
    for (final d in _derives) {
      d.dispose();
    }

    for (final s in _stores) {
      s.dispose();
    }

    _stores.clear();
    _derives.clear();
    _reactors.clear();
  }
}

abstract final class Valence {
  static final Scope root = Scope._root();
}
