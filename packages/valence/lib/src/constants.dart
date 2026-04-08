import 'dart:async';

import 'package:valence/src/core/scope.dart';

abstract final class Valence {
  static final ValenceScope scope = Scope();

  static int maxCircularDependencyIteration = 100_000;

  static void reportError(Object error, StackTrace stackTrace) =>
      scheduleMicrotask(() => Error.throwWithStackTrace(error, stackTrace));
}
