/// **Valence** — High-performance, fine-grained reactive state for Dart &
/// Flutter.
///
/// Valence is a signal-based reactive runtime built around three primitives:
///
/// * [Atom] — mutable reactive state.
/// * [Computed] — lazily recomputed derived values.
/// * [Effect] — eager side-effects that re-run on dependency changes.
///
/// All reactive updates flow through a dependency graph managed by a
/// [ValenceContext] and are batched via a lock-free ring-buffer
/// [Scheduler] for minimal allocation overhead.
///
/// ## Quick start
///
/// ```dart
/// import 'package:valence/valence.dart';
///
/// final count = Atom<int>(0);
/// final doubled = Computed(() => count.value() * 2);
///
/// Effect(() {
///   print('Doubled: ${doubled.value()}');
/// });
///
/// count.update((c) => c + 1); // Prints: Doubled: 2
/// ```
///
/// See the package README for a full guide.
library;

import 'package:valence/src/context.dart';

export 'src/atom.dart';
export 'src/computed.dart';
export 'src/context.dart' show ValenceContext;
export 'src/effect.dart';
export 'src/scheduler.dart' show Scheduler, SchedulableNode, SchedulerCapacity;

abstract final class Valence {
  /// Drains the scheduler queue and executes all pending [SchedulableNode]s
  /// in FIFO order.
  static void flush() => defaultValenceContext.flush();

  /// Sets the maximum number of times [flush] will run before throwing.
  ///
  /// This is a safety mechanism to prevent infinite loops in case of
  /// cyclic dependencies.
  ///
  /// The default value is `100_000`.
  ///
  /// Throws [ArgumentError] if [count] is negative.
  static void setMaxFlushIterations(int count) =>
      defaultValenceContext.setMaxFlushIterations(count);
}
