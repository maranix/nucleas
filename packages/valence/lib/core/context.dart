import 'package:valence/core/interface.dart';
import 'package:valence/core/schedular.dart';

abstract interface class ValenceContext {
  factory ValenceContext() = _ValenceContextImpl;

  int get markEpoch;

  Observer? get current;

  Observer get requireCurrent;

  Schedular get schedular;

  void push(Observer o);

  void pop();

  void startTracking(Producer p);

  int updateMarkEpoch();

  void flush();
}

final class _ValenceContextImpl implements ValenceContext {
  _ValenceContextImpl();

  final List<Observer> _stack = [];

  final Schedular _schedular = ValenceSchedular();

  int _markEpoch = 1;

  @override
  Observer? get current => _stack.isEmpty ? null : _stack.last;

  @override
  Observer get requireCurrent {
    if (_stack.isEmpty) {
      throw StateError("No active observer in ValenceContext");
    }

    return _stack.last;
  }

  @override
  int get markEpoch => _markEpoch;

  @override
  Schedular get schedular => _schedular;

  @override
  void push(Observer o) => _stack.add(o);

  @override
  void pop() => _stack.removeLast();

  @override
  void startTracking(Producer p) {
    if (current != null) {
      requireCurrent.dependOn(p);
    }
  }

  @override
  int updateMarkEpoch() => ++_markEpoch; // Post-increment

  @override
  void flush() => _schedular.flush();
}
