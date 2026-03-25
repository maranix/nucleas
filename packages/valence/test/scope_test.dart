import 'package:test/test.dart';
import 'package:valence/valence.dart';

final class Increment extends Action<int> {
  const Increment();

  @override
  int reduce(int s) => s + 1;
}

void main() {
  group('scope', () {
    test('reactor in disposed scope no longer runs', () {
      final scope = Scope();
      final c = store(0, scope: scope);
      var runs = 0;

      reactor(() {
        c();
        runs++;
      }, scope: scope);
      expect(runs, 1);

      scope.dispose();

      c.dispatch(const Increment());
      expect(runs, 1); // reactor was disposed, did not re-run
    });

    test('disposing a scope does not affect root scope nodes', () {
      final rootStore = store(0);
      var rootRuns = 0;
      reactor(() {
        rootStore();
        rootRuns++;
      });

      final scope = Scope();
      store(0, scope: scope); // owned by child scope
      scope.dispose();

      rootStore.dispatch(const Increment());
      expect(rootRuns, 2); // root reactor unaffected
    });

    test('dispose is safe to call on empty scope', () {
      final scope = Scope();
      expect(() => scope.dispose(), returnsNormally);
    });
  });
}
