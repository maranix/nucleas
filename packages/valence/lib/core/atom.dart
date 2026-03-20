import 'package:valence/constants.dart' show Valence;
import 'package:valence/core/context.dart';
import 'package:valence/core/interface.dart';
import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

final class Atom<T> extends BaseProducer {
  Atom(this._value, {ValenceContext? ctx, EqualityFn? eq})
    : _ctx = ctx ?? Valence.ctx,
      _eq = eq ?? defaultEquals;

  final ValenceContext _ctx;

  final EqualityFn _eq;

  T _value;

  T value() {
    _ctx.startTracking(this);

    return _value;
  }

  void update(MutatorFn<T> fn) {
    final next = fn(_value);

    if (_eq(_value, next)) return;

    _value = next;

    updateVersion();
    notify();
  }
}
