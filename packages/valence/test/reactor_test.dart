import 'package:test/test.dart';
import 'package:valence/valence.dart';

final class Increment extends Action<int> {
  const Increment();

  @override
  String get debugLabel => 'Increment';

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
  group('reactor', () {
    test('runs immediately on creation', () {
      final c = store(0);
      var runs = 0;
      reactor(() {
        c();
        runs++;
      });
      expect(runs, 1);
    });

    test('re-runs when dependency changes', () {
      final c = store(0);
      var runs = 0;
      reactor(() {
        c();
        runs++;
      });
      c.dispatch(const Increment());
      expect(runs, 2);
    });

    test('captures latest value', () {
      final c = store(0);
      final seen = <int>[];
      reactor(() => seen.add(c()));
      c.dispatch(const Increment());
      c.dispatch(const Increment());
      expect(seen, [0, 1, 2]);
    });

    test('dispose stops re-runs', () {
      final c = store(0);
      var runs = 0;
      final r = reactor(() {
        c();
        runs++;
      });
      r.dispose();
      c.dispatch(const Increment());
      expect(runs, 1); // only the initial run
    });

    test('conditional tracking — unsubscribes from old branch', () {
      final flag = store(true);
      final a = store(0);
      final b = store(0);
      final seen = <String>[];

      reactor(() {
        if (flag()) {
          seen.add('a:${a()}');
        } else {
          seen.add('b:${b()}');
        }
      });

      a.dispatch(const Increment());
      expect(seen.last, 'a:1');

      flag.dispatch(const SetBool(false));
      b.dispatch(const Increment());
      expect(seen.last, 'b:1');

      a.dispatch(const Increment()); // no longer subscribed to a
      expect(seen.last, 'b:1');
    });
  });
}
