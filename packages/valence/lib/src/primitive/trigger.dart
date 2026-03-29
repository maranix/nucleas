import 'dart:async';

import 'package:valence/src/primitive/action.dart';
import 'package:valence/src/primitive/derive.dart';
import 'package:valence/src/primitive/resource.dart';
import 'package:valence/src/primitive/reactor.dart';
import 'package:valence/src/primitive/store.dart';

extension DeriveTrigger<T> on Derive<T> {
  Reactor trigger<S, A extends Action<S>>({
    required Store<S, A> store,
    required A Function(T) then,
  }) => reactor(() {
    final val = this();

    scheduleMicrotask(() => store.dispatch(then(val)));
  });
}

extension ResourceTrigger<T> on Resource<T> {
  Reactor trigger<S, A extends Action<S>>({
    required Store<S, A> store,
    required A Function(T) then,
  }) => reactor(() {
    final state = this();

    if (state is ResourceLoaded<T>) {
      scheduleMicrotask(() => store.dispatch(then(state.data)));
    }
  });
}
