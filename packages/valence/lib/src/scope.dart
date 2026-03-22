import 'core.dart';
import 'reactor.dart';
import 'store.dart';
import 'derive.dart';

final class Scope {
  Scope._root() : _isRoot = true, _parent = null;
  Scope._child(this._parent) : _isRoot = false;

  factory Scope({Scope? parent}) => Scope._child(parent ?? Valence.root);

  final bool _isRoot;
  final Scope? _parent;

  Scope get _core => _parent?._core ?? this;

  // --- Execution & Tracking State ---

  final List<Set<Node>> trackingStack = [];
  bool get isTracking => _core.trackingStack.isNotEmpty;

  void beginTracking() => _core.trackingStack.add({});
  Set<Node> endTracking() => _core.trackingStack.removeLast();

  void recordRead(Node node) {
    if (_core.trackingStack.isNotEmpty) {
      _core.trackingStack.last.add(node);
    }
  }

  // --- Flush Queue & Batching ---

  final Set<ReactiveNode> _pendingSet = {};
  final List<ReactiveNode> _pendingList = [];
  int _batchDepth = 0;

  bool get isBatching => _core._batchDepth > 0;

  void beginBatch() => _core._batchDepth++;

  bool endBatch() {
    _core._batchDepth--;
    return _core._batchDepth == 0;
  }

  void enqueue(ReactiveNode node) {
    if (!_core._pendingSet.add(node)) return;
    var i = _core._pendingList.length;
    while (i > 0 && _core._pendingList[i - 1].depth > node.depth) i--;
    _core._pendingList.insert(i, node);
  }

  void flushPending() {
    while (_core._pendingList.isNotEmpty) {
      final snapshot = List<ReactiveNode>.of(_core._pendingList);
      _core._pendingList.clear();
      _core._pendingSet.clear();
      for (final node in snapshot) {
        node.recompute();
      }
    }
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
