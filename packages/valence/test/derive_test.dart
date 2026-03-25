import 'package:test/test.dart';
import 'package:valence/valence.dart';

final class Increment extends Action<int> {
  const Increment();

  @override
  int reduce(int s) => s + 1;
}

final class SetBool extends Action<bool> {
  const SetBool(this.value);

  final bool value;

  @override
  bool reduce(bool _) => value;
}

void main() {
  group('derive', () {
    test('computes initial value', () {
      final c = store(2);
      final d = derive(() => c() * 2);
      expect(d(), 4);
    });

    test('updates when dependency changes', () {
      final c = store(0);
      final d = derive(() => c() * 2);
      c.dispatch(const Increment());
      expect(d(), 2);
    });

    test('chains — derive of derive', () {
      final c = store(1);
      final d1 = derive(() => c() + 1);
      final d2 = derive(() => d1() * 2);
      expect(d2(), 4);
      c.dispatch(const Increment());
      expect(d1(), 3);
      expect(d2(), 6);
    });

    test('glitch free — diamond dependency never sees stale state', () {
      final s = store(0);
      final d1 = derive(() => s() + 1);
      final d2 = derive(() => s() + d1());

      final seen = <int>[];
      reactor(() => seen.add(d2()));

      s.dispatch(const Increment());

      // d2 = s() + d1() = 1 + 2 = 3. Must never be seen as 2 (stale d1).
      expect(seen.last, 3);
      expect(seen.every((v) => v == 1 || v == 3), true);
    });

    test('conditional tracking — unsubscribes from unused branch', () {
      final flag = store(false);
      final data = store(0);
      var computeCount = 0;

      derive(() {
        computeCount++;
        return flag() ? data() : -1;
      });

      final before = computeCount;
      data.dispatch(const Increment()); // flag is false — should not recompute
      expect(computeCount, before);

      flag.dispatch(const SetBool(true));
      data.dispatch(const Increment()); // now subscribed
      expect(computeCount, before + 2);
    });

    test('propagation cut — no downstream update when value unchanged', () {
      final s = store(0);
      final constant = derive(() {
        s();
        return 42;
      });
      var runs = 0;
      reactor(() {
        constant();
        runs++;
      });

      final before = runs;
      s.dispatch(const Increment());
      expect(runs, before); // constant did not change, reactor did not re-run
    });
  });
}
