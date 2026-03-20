import 'package:valence/constants.dart';
import 'package:valence/core/context.dart';
import 'package:valence/core/interface.dart';
import 'package:valence/types.dart';

final class Effect with BaseObserver {
  Effect(this._fn, {ValenceContext? ctx}) : _ctx = ctx ?? Valence.ctx {
    _ctx.schedular.schedule(this);
  }

  final VoidCallback _fn;

  final ValenceContext _ctx;

  @override
  ValenceContext get ctx => _ctx;

  bool _dirty = true;
  bool _isScheduled = false;

  bool get isScheduled => _isScheduled;

  void setScheduled(bool value) {
    _isScheduled = value;
  }

  @override
  void markDirty() {
    if (_dirty && _isScheduled) return;

    _dirty = true;
    
    if (!_isScheduled) {
      _isScheduled = true;
      _ctx.schedular.schedule(this);
    }
  }

  void run() {
    if (!_dirty) return;

    _dirty = false;
    _isScheduled = false;

    trackDependencies(_fn);
  }
}
