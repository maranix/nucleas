import 'dart:typed_data';

/// Describes the capacity strategy of the scheduler.
///
/// [fixed] means the scheduler will throw a [StateError] if the buffer is full.
/// [growable] means the scheduler will grow the buffer as needed.
enum SchedulerCapacity { fixed, growable }

/// An interface for reactive nodes that can be scheduled for execution.
///
/// Both [Computed] and [Effect] implement this interface so that the
/// [ValenceContext] can enqueue them for deferred execution during a flush
/// cycle.
abstract interface class SchedulableNode {
  /// Whether this node is currently enqueued in the scheduler.
  ///
  /// Used to prevent duplicate scheduling of the same node within a single
  /// update cycle.
  bool get isScheduled;

  /// Sets the scheduling state of this node.
  set isScheduled(bool value);

  /// Called by the scheduler during a [ValenceContext.flush] cycle.
  ///
  /// For [Computed] nodes this marks the value as dirty and propagates
  /// invalidation to downstream dependents. For [Effect] nodes this
  /// re-executes the side-effect function.
  void execute();
}

/// A FIFO queue for scheduling reactive node updates.
///
/// The default implementation uses a fixed-capacity ring buffer backed by a
/// [Uint32List] for zero-allocation enqueue/dequeue operations.
///
/// The capacity **must** be a positive power of two so that modular arithmetic
/// can be implemented with a bitmask instead of the modulo operator.
///
/// The default capacity is `1024`, which supports up to 1 024 pending updates
/// per flush cycle.
///
/// The default capacity strategy is [SchedulerCapacity.fixed].
abstract interface class Scheduler {
  /// Creates a ring-buffer–backed [Scheduler] with the given [capacity].
  ///
  /// [capacity] must be a positive power of two (e.g. 1024, 2048).
  /// Defaults to `1024`, which supports up to 1 024 pending updates per
  /// flush cycle.
  factory Scheduler([
    int capacity = 1024,
    SchedulerCapacity capacityStrategy = SchedulerCapacity.fixed,
  ]) => switch (capacityStrategy) {
    .fixed => _RingBufferSchedulerImpl(capacity),
    .growable => _GrowableRingBufferSchedulerImpl(capacity),
  };

  /// Whether the queue is empty.
  bool get isEmpty;

  /// Whether the queue has reached its maximum capacity.
  bool get isFull;

  /// Enqueues a [nodeId] for processing.
  ///
  /// Throws a [StateError] if the buffer is full.
  void push(int nodeId);

  /// Dequeues and returns the next node ID.
  ///
  /// Returns `0` if the buffer is empty. Since valid node IDs start at `1`,
  /// a return value of `0` is an unambiguous sentinel for "nothing to process".
  int pop();

  /// Resets the buffer, discarding all pending updates.
  void clear();
}

/// A lock-free, fixed-capacity ring buffer implementing [Scheduler].
///
/// Internally the buffer uses a [Uint32List] and a bitmask (`_mask`) to
/// wrap head/tail indices without the cost of a modulo operation.
///
/// **Overflow behaviour**: throws a [StateError] rather than silently
/// dropping updates — this makes it easy to detect reactive update bursts
/// that exceed the configured capacity.
final class _RingBufferSchedulerImpl implements Scheduler {
  /// Creates a ring buffer with the given [capacity].
  ///
  /// Asserts at construction time that [capacity] is a positive power of two.
  _RingBufferSchedulerImpl(int capacity)
    : assert(
        (capacity > 0) && ((capacity & capacity - 1) == 0),
        'RingBuffer capacity must be a positive power of two.',
      ),
      _data = .new(capacity),
      _mask = capacity - 1;

  /// The backing typed-data buffer for node IDs.
  final Uint32List _data;

  /// Bitmask used to wrap indices: equivalent to `index % capacity` when
  /// capacity is a power of two.
  final int _mask;

  /// Absolute index of the front of the queue.
  int _head = 0;

  /// Absolute index one past the end of the queue.
  int _tail = 0;

  @override
  bool get isEmpty => _head == _tail;

  @override
  bool get isFull => (_tail - _head) == _data.length;

  @override
  void push(int nodeId) {
    if (isFull) {
      throw StateError(
        'RingBuffer overflow: reactive update burst exceeded capacity '
        '(${_data.length}).',
      );
    }

    _data[_tail & _mask] = nodeId;
    _tail += 1;
  }

  @override
  int pop() {
    if (isEmpty) {
      clear();
      return 0;
    }

    final nodeId = _data[_head & _mask];
    _head += 1;

    return nodeId;
  }

  @override
  void clear() {
    _head = 0;
    _tail = 0;
  }
}

/// A growable ring buffer implementing [Scheduler].
///
/// Internally the buffer uses a [Uint32List] and a bitmask (`_mask`) to
/// wrap head/tail indices without the cost of a modulo operation.
final class _GrowableRingBufferSchedulerImpl implements Scheduler {
  /// Creates a growable ring buffer with the given [capacity].
  ///
  /// Asserts at construction time that [capacity] is a positive power of two.
  _GrowableRingBufferSchedulerImpl(int capacity)
    : assert(
        (capacity > 0) && ((capacity & capacity - 1) == 0),
        'RingBuffer capacity must be a positive power of two.',
      ),
      _data = .new(capacity),
      _mask = capacity - 1;

  /// The backing typed-data buffer for node IDs.
  Uint32List _data;

  /// Bitmask used to wrap indices: equivalent to `index % capacity` when
  /// capacity is a power of two.
  int _mask;

  /// Absolute index of the front of the queue.
  int _head = 0;

  /// Absolute index one past the end of the queue.
  int _tail = 0;

  @override
  bool get isEmpty => _head == _tail;

  @override
  bool get isFull => (_tail - _head) == _data.length;

  @override
  void push(int nodeId) {
    if (isFull) {
      final int oldLength = _data.length;
      final Uint32List newData = .new(_data.length * 2);

      // Copy the elements from the old buffer to the new buffer in logical order
      for (var i = 0; i < oldLength; i++) {
        newData[i] = _data[(_head + i) & _mask];
      }

      _data = newData;
      _mask = newData.length - 1;

      // Reset the pointers to match the newly unwrapped, flat memory layout
      _head = 0;
      _tail = oldLength;
    }

    _data[_tail & _mask] = nodeId;
    _tail += 1;
  }

  @override
  int pop() {
    if (isEmpty) {
      clear();
      return 0;
    }

    final nodeId = _data[_head & _mask];
    _head += 1;

    return nodeId;
  }

  @override
  void clear() {
    _head = 0;
    _tail = 0;
  }
}
