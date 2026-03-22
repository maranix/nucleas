import 'package:valence/types.dart';

import 'store.dart';
import 'derive.dart';
import 'reactor.dart';
import 'scope.dart';

Store<S> store<S>(
  S initial, {
  Scope? scope,
  EqualityCallback<S>? equals,
}) {
  final s = scope ?? Valence.root;
  final st = Store<S>(s, initial, equals: equals);
  s.registerStore(st);
  return st;
}

Derive<T> derive<T>(
  ValueCallback<T> fn, {
  Scope? scope,
  EqualityCallback<T>? equals,
}) {
  final s = scope ?? Valence.root;
  final d = Derive<T>(s, fn, equals: equals);
  s.registerDerive(d);
  return d;
}

Reactor reactor(
  VoidCallback fn, {
  Scope? scope,
}) {
  final s = scope ?? Valence.root;
  final r = Reactor(s, fn);
  s.registerReactor(r);
  return r;
}

void batch(void Function() fn) {
  Valence.root.beginBatch();
  try {
    fn();
  } finally {
    if (Valence.root.endBatch()) {
      Valence.root.flushPending();
    }
  }
}
