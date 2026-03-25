import 'package:test/test.dart';
import 'package:valence/types.dart';
import 'package:valence/valence.dart';

sealed class CounterAction extends Action<int> {
  const CounterAction();
}

final class CounterReset extends CounterAction {
  @override
  int reduce(int _) => 0;
}

sealed class CounterLinearAction extends CounterAction {
  const CounterLinearAction();
}

final class Increment extends CounterLinearAction {
  const Increment();
  @override
  int reduce(int s) => s + 1;
}

final class Decrement extends CounterLinearAction {
  const Decrement();
  @override
  int reduce(int s) => s - 1;
}

sealed class CounterNonLinearAction extends CounterAction {
  const CounterNonLinearAction();
}

final class Multiply extends CounterNonLinearAction {
  const Multiply(this.factor);
  final int factor;
  @override
  int reduce(int s) => s * factor;
}

final class SetValue extends Action<int> {
  const SetValue(this.val);
  final int val;
  @override
  int reduce(int _) => val;
}

final class _NoOpListAction extends Action<List<int>> {
  const _NoOpListAction(this._dispatchHook);

  final VoidCallback _dispatchHook;

  @override
  List<int> reduce(List<int> s) => s;

  @override
  void onDispatch() => _dispatchHook();
}

void main() {
  group('Store: Dispatch & Type Safety', () {
    test('returns initial value', () {
      final c = store(0);
      expect(c(), 0);
    });

    test('generic store accepts any action', () {
      // Defaulting to Action<int>
      final c = store(10);
      c.dispatch(const Increment()); // Linear
      c.dispatch(const Multiply(2)); // Non-Linear
      c.dispatch(const SetValue(0)); // Generic
      expect(c(), 0);
    });
  });

  group('Store: Reactivity', () {
    test('no notification when value unchanged (Identity)', () {
      final c = store(10);
      var notifications = 0;

      reactor(() {
        c();
        notifications++;
      });

      notifications = 0; // Reset after initial reactor run

      c.dispatch(const SetValue(10)); // Same value
      expect(
        notifications,
        0,
        reason: 'Should not notify if state is identical',
      );
    });

    test('reactor reacts to dispatch', () {
      final c = store(0);
      int? lastSeen;

      reactor(() => lastSeen = c());

      c.dispatch(const Increment());
      expect(lastSeen, 1);
    });
  });

  group('Store: History (Undo)', () {
    test('undo', () {
      final c = store(0);

      c.dispatch(const Increment()); // 1
      c.dispatch(const Increment()); // 2
      expect(c(), 2);

      c.undo();
      expect(c(), 1);
    });

    test('undo on empty history is a no-op', () {
      final c = store(0);
      expect(() => c.undo(), returnsNormally);
      expect(c(), 0);
    });
  });

  group('Edge Cases', () {
    test('Multiple stores do not share history nodes', () {
      final a = store(0);
      final b = store(10);

      a.dispatch(const Increment());
      b.dispatch(const Increment());

      a.undo();
      expect(a(), 0);
      expect(
        b(),
        11,
        reason: 'Store B history should be untouched by Store A undo',
      );
    });

    test('Store handles complex state objects', () {
      // Testing with a List or Map to ensure identity checks work
      final listStore = store<List<int>, Action<List<int>>>([1, 2]);
      var called = false;

      final before = listStore();

      // Action that returns the same instance
      listStore.dispatch(
        _NoOpListAction(() {
          called = true;
        }),
      );
      expect(called, true);

      final after = listStore();

      expect(identical(before, after), true);
    });
  });
}
