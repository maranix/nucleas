abstract interface class IdPool {
  factory IdPool() = _IdPoolImpl;

  int acquire();

  void release(int id);
}

final class _IdPoolImpl implements IdPool {
  int _nextId = 0;

  final List<int> _recycledIds = [];

  @override
  int acquire() {
    if (_recycledIds.isNotEmpty) {
      return _recycledIds.removeLast();
    }

    return _nextId++;
  }

  @override
  void release(int id) => _recycledIds.add(id);
}
