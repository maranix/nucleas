# Valence

**Valence** is a high-performance **fine-grained reactive runtime for Dart and Flutter** built around atomic state.

The runtime focuses on **predictable updates, extremely low overhead, minimal allocations and deterministic execution**.

---

# Core Concepts

Valence is built on three primitives.

## Atom

Atoms represent the **smallest unit of mutable reactive state**.

```dart
final counter = Atom<int>(0);

counter.update((c) => c + 1);

print(counter.get());
```

All mutations go through `update`.

---

## Computed

Computed values derive state from other atoms.

They are **lazy and cached**.

```dart
final price = Atom<double>(10);
final quantity = Atom<int>(2);

final total = Computed(() {
  return price.get() * quantity.get();
});

print(total.get());
```

Computed values recompute only when dependencies change.

---

## Effect

Effects run when reactive state changes.

Useful for:

* UI updates
* logging
* side effects

```dart
Effect(() {
  print("Total changed: ${total.get()}");
});
```

---

# Mutation Model

Valence enforces a **single mutation API**.

```dart
atom.update(fn)
```

Example:

```dart
price.update((p) => p + 5);
```

Direct assignments:

```dart
price.update((_) => 120);
```

This ensures:

* predictable updates
* deterministic execution
* easy debugging
* instrumentation support

---

# Batch Updates

Multiple mutations can be grouped into a single reactive update.

```dart
batch(() {
  price.update((_) => 100);
  quantity.update((_) => 3);
});
```

This prevents unnecessary recomputation.

---

# Execution Model

Reactive updates follow this pipeline:

```
Atom.update()
      ↓
Dependency tracking
      ↓
RingBuffer queue
      ↓
Scheduler
      ↓
Computed recomputation
      ↓
Effects execution
```

Valence uses a **lock-free RingBuffer scheduler** internally for extremely fast update propagation.

---

# Performance Goals

Valence is designed for both UI and real-time systems.

Target characteristics:

```
Atom mutation        O(dependents)
Dependency tracking  O(1)
Scheduler enqueue    O(1)
Computed access      O(1) amortized
```

The runtime handles:

* simple CRUD apps
* Flutter UI
* high-frequency telemetry
* streaming dashboards

with the same architecture.

---

# Example

A small reactive example:

```dart
final price = Atom<double>(10);
final quantity = Atom<int>(2);

final total = Computed(() => price.get() * quantity.get());

Effect(() {
  print("Total: ${total.get()}");
});

price.update((p) => p + 5);
```

Output:

```
Total: 30
```

---

# Philosophy

Valence follows a few core design principles:

* **explicit mutation**
* **pure derived computation**
* **isolated side effects**
* **fine-grained dependency tracking**
* **minimal public API**

This keeps the runtime predictable and easy to reason about.

---

# Public API

The entire runtime exposes only a few primitives:

```
Atom<T>
Computed<T>
Effect()
batch()
dispose()
```

Everything else remains internal.

---

# Roadmap

Future capabilities may include:

* Flutter widgets integration
* devtools graph inspector
* time-travel debugging
* event replay
* reactive collections

---

# License

Valence is licensed under `MIT License`.
