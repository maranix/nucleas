import 'package:valence/src/constants.dart';
import 'package:valence/src/core/scope.dart';

void group(void Function() fn, {Scope? scope}) {
  final s = scope ?? rootScope;
  s.scheduler.batch(fn);
}
