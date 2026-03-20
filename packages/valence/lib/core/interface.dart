import 'package:valence/core/context.dart';

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

mixin BaseObserver implements Observer {
  List<Producer> _deps = [];
  List<Producer> _oldDeps = [];

  ValenceContext get ctx;

  @override
  void dependOn(Producer p) {
    final epoch = ctx.markEpoch;
    if (p.mark == epoch) return;

    _deps.add(p);
    p.addSub(this, epoch);
  }

  void trackDependencies(void Function() compute) {
    ctx.push(this);

    final epoch = ctx.updateMarkEpoch();

    _oldDeps = _deps;
    _deps = [];

    compute();

    ctx.pop();

    for (final dep in _oldDeps) {
      if (dep.mark != epoch) {
        dep.removeSub(this);
      }
    }
  }
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
