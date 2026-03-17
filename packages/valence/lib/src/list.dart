import 'dart:typed_data';

/// A high-performance, manually managed growable list backed by a [Uint32List].
///
/// Unlike Dart's standard [List], this implementation avoids boxing overhead
/// by storing raw unsigned 32-bit integers directly in typed-data memory.
/// This makes it ideal for storing node IDs in the reactive dependency graph
/// where allocation pressure and cache locality matter.
///
/// The list doubles its capacity on overflow (amortised O(1) `add`).
/// Removal uses a swap-with-last strategy for O(1) deletion at the cost of
/// element ordering — which is acceptable for unordered sets of node IDs.
///
/// **This is an internal data structure and is not exported from the library.**
final class GrowableUint32List {
  /// Creates a new [GrowableUint32List] with the given [initialCapacity].
  ///
  /// The [initialCapacity] determines the size of the initial backing buffer.
  /// A small default of 4 is used to avoid over-allocating for nodes with
  /// few dependencies.
  GrowableUint32List([int initialCapacity = 4]) : _data = .new(initialCapacity);

  /// The backing typed-data buffer.
  ///
  /// Replaced with a larger buffer when capacity is exceeded.
  Uint32List _data;

  /// The number of elements currently stored in the list.
  int _length = 0;

  /// The number of elements in this list.
  int get length => _length;

  /// Whether this list contains no elements.
  bool get isEmpty => _length == 0;

  /// Whether this list contains at least one element.
  bool get isNotEmpty => _length > 0;

  /// Returns the element at the given [index].
  ///
  /// Does **not** perform bounds checking for performance reasons.
  /// Callers must ensure `0 <= index < length`.
  int operator [](int index) => _data[index];

  /// Returns the last element in the list.
  ///
  /// Throws a [StateError] if the list is empty.
  int get last {
    if (isEmpty) throw StateError('No elements');

    return _data[_length - 1];
  }

  /// Appends [value] to the end of this list.
  ///
  /// If the backing buffer is full, a new buffer with double the capacity
  /// is allocated and the existing elements are copied over.
  ///
  /// Amortised time complexity: **O(1)**.
  void add(int value) {
    if (_length == _data.length) {
      final newData = Uint32List(_data.length * 2);
      newData.setAll(0, _data);
      _data = newData;
    }

    _data[_length] = value;
    _length += 1;
  }

  /// Removes the first occurrence of [value] from this list.
  ///
  /// Uses a **swap-with-last** strategy: the element to remove is overwritten
  /// with the last element, then the length is decremented. This gives O(1)
  /// removal but does **not** preserve element order.
  ///
  /// If [value] is not found, this method is a no-op.
  void remove(int value) {
    for (var i = 0; i < _length; i++) {
      if (_data[i] == value) {
        _data[i] = _data[_length - 1];
        _length -= 1;
        return;
      }
    }
  }

  /// Removes and returns the last element of this list.
  ///
  /// Throws a [StateError] if the list is empty.
  int removeLast() {
    if (_length == 0) throw StateError('No elements');

    final item = _data[_length - 1];
    _length -= 1;

    return item;
  }

  /// Returns `true` if this list contains [value].
  ///
  /// Performs a linear scan. Time complexity: **O(n)**.
  bool contains(int value) {
    for (var i = 0; i < _length; i++) {
      if (_data[i] == value) return true;
    }

    return false;
  }

  /// Removes all elements from this list.
  ///
  /// The backing buffer is retained; only the logical length is reset to zero.
  void clear() {
    _length = 0;
  }
}
