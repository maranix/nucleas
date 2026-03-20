import 'package:valence/constants.dart';
import 'package:valence/core/context.dart';
import 'package:valence/core/interface.dart';
import 'package:valence/types.dart';

final class Computed<T> extends BaseProducer implements Observer, Readable<T> {
  Computed(this._compute, {ValenceContext? ctx}) : _ctx = ctx ?? Valence.ctx;

  final ValueCallback<T> _compute;
  final ValenceContext _ctx;

  // Write buffer
  List<Producer> _deps = [];

  // Read Buffer
  List<Producer> _oldDeps = [];

  T? _value;
  bool _dirty = true;

  void _recompute() {
    _dirty = false;

    _ctx.push(this);

    final epoch = _ctx.updateMarkEpoch();

    _oldDeps = _deps;
    _deps = [];

    final next = _compute();

    _ctx.pop();

    for (final dep in _oldDeps) {
      if (dep.mark != epoch) {
        dep.removeSub(this);
      }
    }

    _value = next;
    updateVersion();
  }

  @override
  T value() {
    _ctx.startTracking(this);

    if (_dirty) {
      _recompute();
    }

    return _value as T;
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
  void markDirty() {
    if (_dirty) return;

    _dirty = true;

    notify();
  }
}
