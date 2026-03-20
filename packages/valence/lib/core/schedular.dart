import 'dart:async';

import 'package:valence/core/effect.dart';


abstract interface class Schedular {
  bool get isScheduled;
  void schedule(Effect o);
  void flush();
}

final class EffectQueue {
  List<Effect?> _buffer;
  int _head = 0;
  int _tail = 0;
  int _mask;

  EffectQueue(int capacity)
    : _buffer = List.filled(capacity, null),
      _mask = capacity - 1;

  void push(Effect e) {
    _buffer[_tail] = e;
    _tail = (_tail + 1) & _mask;

    if (_tail == _head) _grow();
  }

  Effect? pop() {
    if (_head == _tail) return null;

    final e = _buffer[_head];
    _buffer[_head] = null;
    _head = (_head + 1) & _mask;
    return e;
  }

  bool get isEmpty => _head == _tail;

  void _grow() {
    final old = _buffer;
    final newCap = old.length << 1;
    final newBuf = List<Effect?>.filled(newCap, null);

    int i = 0;
    while (!isEmpty) {
      newBuf[i++] = pop();
    }

    _buffer = newBuf;
    _head = 0;
    _tail = i;
    _mask = newCap - 1;
  }
}

final class ValenceSchedular implements Schedular {
  final EffectQueue _effectQueue = EffectQueue(1024);



  bool _isScheduled = false;

  @override
  bool get isScheduled => _isScheduled;

  @override
  void schedule(Effect s) {
    _effectQueue.push(s);

    flush();
  }

  @override
  void flush() {
    if (_isScheduled) return;

    _isScheduled = true;

    scheduleMicrotask(_flush);
  }

  void _flush() {
    _isScheduled = false;

    while (true) {
      final effect = _effectQueue.pop();
      if (effect == null) break;

      effect.run();
    }
  }
}
