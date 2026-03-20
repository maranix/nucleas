import 'package:valence/core/effect.dart';
import 'package:valence/types.dart';

abstract interface class Producer {
  int get version;
  int get mark;
  int get subEpoch;

  void updateVersion();
  void updateSubEpoch(int epoch);

  void addSub(Observer o, int epoch);
  void removeSub(Observer o);
}

abstract interface class Observer {
  void dependOn(Producer p);
  void markDirty();
}

abstract interface class Mutable<T> {
  void update(MutatorFn<T> fn);
}

abstract interface class Readable<T> {
  T value();
}

abstract interface class SideEffect {
  int get queueEpoch;

  void setQueueEpoch(int epoch);

  void run();
}

abstract interface class Schedular {
  bool get isScheduled;
  void schedule(Effect o);
  void flush();
}

abstract base class BaseProducer implements Producer {
  int _version = 0;
  int _mark = 0; // mark-sweep

  int _subEpoch = 0; // dedupe subscriptions

  final List<Observer> _subs = [];

  @override
  int get mark => _mark;

  @override
  int get version => _version;

  @override
  int get subEpoch => _subEpoch;

  @override
  void addSub(Observer o, int epoch) {
    _mark = epoch;

    if (_subEpoch == epoch) return;

    _subEpoch = epoch;
    _subs.add(o);
  }

  @override
  void removeSub(Observer o) => _subs.remove(o);

  @override
  void updateVersion() => _version++;

  @override
  void updateSubEpoch(int epoch) => _subEpoch = epoch;

  void notify() {
    for (final s in _subs) {
      s.markDirty();
    }
  }
}
