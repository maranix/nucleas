import 'package:test/test.dart';
import 'package:valence/valence.dart';

final class Increment implements Reducer<int> {
  const Increment();
  @override
  int reduce(int s) => s + 1;
}

final class SetValue implements Reducer<int> {
  const SetValue(this.value);
  final int value;
  @override
  int reduce(int _) => value;
}

void main() {
  group('store', () {
    test('returns initial value', () {
      final c = store<int>(0);
      expect(c(), 0);
    });

    test('dispatch updates value', () {
      final c = store<int>(0);
      c.dispatch(const Increment());
      expect(c(), 1);
    });

    test('no notification when value unchanged', () {
      final c = store<int>(0);
      var notifications = 0;
      reactor(() {
        c();
        notifications++;
      });
      notifications = 0; // reset after initial run

      c.dispatch(const SetValue(0));
      expect(notifications, 0);
    });

    test('undo reverts last dispatch', () {
      final c = store<int>(0);
      c.dispatch(const Increment());
      c.dispatch(const Increment());
      expect(c(), 2);
      c.undo();
      expect(c(), 1);
      c.undo();
      expect(c(), 0);
    });

    test('undo on empty history is a no-op', () {
      final c = store<int>(0);
      expect(() => c.undo(), returnsNormally);
      expect(c(), 0);
    });

    test('undo only affects this store', () {
      final a = store<int>(0);
      final b = store<int>(10);
      a.dispatch(const Increment());
      b.dispatch(const Increment());
      a.undo();
      expect(a(), 0);
      expect(b(), 11);
    });
  });
}
