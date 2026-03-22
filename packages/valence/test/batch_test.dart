import 'package:test/test.dart';
import 'package:valence/valence.dart';

final class Increment implements Reducer<int> {
  const Increment();
  @override
  int reduce(int s) => s + 1;
}

void main() {
  group('batch', () {
    test('reactor runs once for multiple dispatches', () {
      final a = store<int>(0);
      final b = store<int>(0);
      var runs = 0;

      reactor(() {
        a();
        b();
        runs++;
      });
      expect(runs, 1);

      batch(() {
        a.dispatch(const Increment());
        b.dispatch(const Increment());
      });

      expect(runs, 2);
      expect(a(), 1);
      expect(b(), 1);
    });

    test('nested batch collapses into outermost', () {
      final c = store<int>(0);
      var runs = 0;
      reactor(() {
        c();
        runs++;
      });

      batch(() {
        batch(() {
          c.dispatch(const Increment());
          c.dispatch(const Increment());
        });
        c.dispatch(const Increment());
      });

      expect(runs, 2); // initial + one flush after outermost batch
      expect(c(), 3);
    });

    test('reactor sees final state of all stores', () {
      final a = store<int>(0);
      final b = store<int>(0);
      int? seenA, seenB;

      reactor(() {
        seenA = a();
        seenB = b();
      });

      batch(() {
        a.dispatch(const Increment());
        b.dispatch(const Increment());
      });

      expect(seenA, 1);
      expect(seenB, 1);
    });
  });
}
