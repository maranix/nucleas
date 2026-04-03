import 'package:valence/src/constants.dart';
import 'package:valence/src/core/scope.dart';

void batch(void Function() fn, {Scope? scope}) {
  final s = scope ?? rootScope;
  s.scheduler.batch(fn);
}
