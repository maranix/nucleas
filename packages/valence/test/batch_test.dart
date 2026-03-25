import 'package:test/test.dart';
import 'package:valence/valence.dart';

final class Increment extends Action<int> {
  const Increment();

  @override
  int reduce(int s) => s + 1;
}

void main() {
  group('batch', () {
    test('reactor runs once for multiple dispatches', () {
      final a = store(0);
      final b = store(0);
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
      final c = store(0);
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
      final a = store(0);
      final b = store(0);
      int? seenA, seenB;

      reactor(() {
        seenA = a();
        seenB = b();
      });

      Batch(() {
        a.dispatch(const Increment());
        b.dispatch(const Increment());
      });

      expect(seenA, 1);
      expect(seenB, 1);
    });
  });

  test('lazy batch runs only when accessed', () {
    final a = store(0);
    final b = store(0);
    var runs = 0;

    reactor(() {
      a();
      b();
      runs++;
    });
    expect(runs, 1);

    final lazyB = batch(lazy: true, () {
      a.dispatch(const Increment());
      b.dispatch(const Increment());
    });

    // reactor is not lazy, it runs immediately to form dependencies
    // with sources used inside the callback
    expect(runs, 1);
    expect(a(), 0);
    expect(b(), 0);

    lazyB.run();

    expect(runs, 2);
    expect(a(), 1);
    expect(b(), 1);
  });
}
