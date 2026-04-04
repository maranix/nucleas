import 'package:valence/src/core/scope.dart';

abstract final class Valence {
  static final ValenceScope scope = Scope();

  static int maxCircularDepedencyIteration = 100_000;
}
