import 'package:valence/src/constants.dart';
import 'package:valence/src/core/scope.dart';

void group(void Function() fn, {ValenceScope? scope}) {
  final s = Scope.of(scope ?? Valence.scope);
  s.scheduler.batch(fn);
}
