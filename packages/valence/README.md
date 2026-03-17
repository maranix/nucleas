# Valence

**High-performance, fine-grained reactive state for Dart & Flutter.**

Valence is a signal-based reactive runtime designed for predictable updates, extremely low overhead, minimal allocations, and deterministic execution.

---

## Installation

Add `valence` to your `pubspec.yaml`:

```yaml
dependencies:
  valence: ^1.0.0
```

Then run:

```bash
dart pub get
```

---

## Core Concepts

Valence is built on three primitives.

### Atom

An **Atom** is the smallest unit of mutable reactive state.

```dart
final counter = Atom<int>(0);

counter.update((c) => c + 1);

print(counter.value()); // 1
```

All mutations go through `update`, which accepts a function that receives the current value and returns the next one. If the new value is identical or equal to the old one, the update is skipped entirely — no downstream propagation occurs.

### Computed

A **Computed** derives its value from other reactive nodes. It is **lazy** and **cached** — the compute function only re-runs when a dependency has changed *and* the value is read.

```dart
final price    = Atom<double>(10);
final quantity = Atom<int>(2);

final total = Computed(() => price.value() * quantity.value());

print(total.value()); // 20.0
```

### Effect

An **Effect** runs a side-effect function whenever its dependencies change. Unlike `Computed`, effects are **eager** — they execute immediately on construction and again whenever a dependency is invalidated.

```dart
final counter = Atom<int>(0);

Effect(() {
  print('Counter is: ${counter.value()}');
});

counter.update((c) => c + 1); // Prints: Counter is: 1
```

---

## Reading Values

| Method   | Tracks dependency? | Use case                                  |
| -------- | :----------------: | ----------------------------------------- |
| `value()`| ✅                 | Inside `Computed` / `Effect` bodies        |
| `peek()` | ❌                 | Event handlers, logging, one-off reads     |

---

## Mutation Model

Valence enforces a **single mutation API** for atoms:

```dart
atom.update((current) => nextValue);
```

Examples:

```dart
// Increment
counter.update((c) => c + 1);

// Direct replacement
counter.update((_) => 42);
```

This guarantees predictable updates, deterministic execution, and easy debugging/instrumentation.

---

## Execution Model

Reactive updates follow this pipeline:

```
Atom.update()
      ↓
  Dependency graph lookup
      ↓
  RingBuffer enqueue (O(1))
      ↓
  scheduleMicrotask(flush)
      ↓
  Computed → mark dirty + propagate
      ↓
  Effect → re-execute side-effect
```

Updates within the same microtask are batched automatically — multiple atom mutations that occur synchronously result in a single flush cycle.

---

## Custom Reactive Context

By default all primitives share a global `defaultValenceContext`. For testing or isolated sub-systems you can create your own:

```dart
final ctx = ValenceContext();

final a = Atom<int>(0, context: ctx);
final c = Computed(() => a.value() * 2, ctx);

Effect(() {
  print(c.value());
}, ctx);
```

---

## API Reference

| Type                | Description                                       |
| ------------------- | ------------------------------------------------- |
| `Atom<T>`           | Mutable reactive state                            |
| `Computed<T>`       | Lazy, cached derived value                        |
| `Effect`            | Eager side-effect runner                           |
| `ValenceContext`   | Dependency graph & scheduler coordinator           |
| `Scheduler`         | Ring-buffer FIFO queue for update scheduling        |
| `SchedulableNode`   | Interface for nodes executable by the scheduler    |

---

## Performance Characteristics

| Operation            | Complexity       |
| -------------------- | ---------------- |
| Atom mutation        | O(dependents)    |
| Dependency tracking  | O(1)             |
| Scheduler enqueue    | O(1)             |
| Computed access      | O(1) amortised   |

---

## Example

```dart
import 'package:valence/valence.dart';

void main() {
  final price    = Atom<double>(10);
  final quantity = Atom<int>(2);

  final total = Computed(() => price.value() * quantity.value());

  Effect(() {
    print('Total: ${total.value()}');
  });

  price.update((p) => p + 5); // Prints: Total: 30.0
}
```

---

## License

Valence is released under the [MIT License](../../LICENSE).
