import 'package:valence/constants.dart';
import 'package:valence/core/context.dart';
import 'package:valence/core/interface.dart';
import 'package:valence/types.dart';

final class Effect implements Observer, SideEffect {
  Effect(this._fn, {ValenceContext? ctx}) : _ctx = ctx ?? Valence.ctx {
    _ctx.schedular.schedule(this);
  }

  final VoidCallback _fn;

  final ValenceContext _ctx;

  List<Producer> _deps = [];
  List<Producer> _oldDeps = [];

  bool _dirty = true;

  int _queueEpoch = 0;

  @override
  int get queueEpoch => _queueEpoch;

  @override
  void setQueueEpoch(int epoch) {
    _queueEpoch = epoch;
  }

  @override
  void markDirty() {
    if (_dirty) return;

    _dirty = true;

    _ctx.schedular.schedule(this);
  }

  // Register dependency on Producer
  @override
  void dependOn(Producer p) {
    final epoch = _ctx.markEpoch;
    if (p.mark == epoch) return;

    _deps.add(p);
    p.addSub(this, epoch);
  }

  @override
  void run() {
    if (!_dirty) return;

    _dirty = false;

    _ctx.push(this);

    final epoch = _ctx.updateMarkEpoch();

    _oldDeps = _deps;
    _deps = [];

    _fn();

    _ctx.pop();

    for (final dep in _oldDeps) {
      if (dep.mark != epoch) {
        dep.removeSub(this);
      }
    }
  }
}
