import 'package:valence/src/config.dart';
import 'package:valence/src/engine/scope.dart';

Batch batch(
  void Function() fn, {
  bool lazy = false,
  Scope? scope,
}) => Batch(fn, scope: scope, lazy: lazy);

final class Batch {
  Batch(this.fn, {Scope? scope, bool lazy = false})
    : _scope = scope ?? Valence.root {
    if (!lazy) run();
  }

  final void Function() fn;
  final Scope _scope;

  void run() {
    _scope.schedular.batch(fn);
  }
}
