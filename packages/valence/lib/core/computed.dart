import 'package:valence/constants.dart';
import 'package:valence/core/context.dart';
import 'package:valence/core/interface.dart';
import 'package:valence/types.dart';

final class Computed<T> extends BaseProducer with BaseObserver {
  Computed(this._compute, {ValenceContext? ctx}) : _ctx = ctx ?? Valence.ctx;

  final ValueCallback<T> _compute;
  final ValenceContext _ctx;

  @override
  ValenceContext get ctx => _ctx;

  T? _value;
  bool _dirty = true;

  void _recompute() {
    _dirty = false;

    trackDependencies(() {
      _value = _compute();
    });

    updateVersion();
  }

  T value() {
    _ctx.startTracking(this);

    if (_dirty) {
      _recompute();
    }

    return _value as T;
  }



  @override
  void markDirty() {
    if (_dirty) return;

    _dirty = true;

    notify();
  }
}
