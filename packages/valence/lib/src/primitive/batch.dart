import 'package:valence/src/config.dart';
import 'package:valence/src/engine/scope.dart';

void batch(void Function() fn, {Scope? scope}) {
  final s = scope ?? Valence.root;
  s.schedular.beginBatch();

  try {
    fn();
  } finally {
    if (s.schedular.endBatch()) {
      s.schedular.flush();
    }
  }
}
