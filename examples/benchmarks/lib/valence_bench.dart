import 'package:valence/valence.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

final class Increment extends Action<int> {
  const Increment();

  @override
  int reduce(int state) => state + 1;
}

class ValenceDispatchBenchmark extends BenchmarkBase {
  ValenceDispatchBenchmark() : super('Valence: Dispatch');

  late Store<int, Increment> s;

  @override
  void setup() => s = store(0);

  @override
  void run() => s.dispatch(const Increment());
}

class ValenceDiamondBenchmark extends BenchmarkBase {
  ValenceDiamondBenchmark() : super('Valence: Diamond Dependency');
  late Store<int, Increment> s;
  late Derive<int> d1;
  late Derive<int> d2;
  late Derive<int> d3;
  late Reactor r;
  int runs = 0;

  @override
  void setup() {
    s = store(0);
    d1 = derive(() => s() + 1);
    d2 = derive(() => s() + 2);
    d3 = derive(() => d1() + d2());
    r = reactor(() {
      d3();
      runs++;
    });
  }

  @override
  void run() => s.dispatch(const Increment());
}

class ValenceDeepBenchmark extends BenchmarkBase {
  ValenceDeepBenchmark() : super('Valence: Deep Chain (10)');
  late Store<int, Increment> s;
  late Reactor r;
  int runs = 0;

  @override
  void setup() {
    s = store(0);
    var current = derive(() => s() + 1);
    for (var i = 0; i < 9; i++) {
      final prev = current;
      current = derive(() => prev() + 1);
    }
    r = reactor(() {
      current();
      runs++;
    });
  }

  @override
  void run() => s.dispatch(const Increment());
}

class ValenceFanOutBenchmark extends BenchmarkBase {
  ValenceFanOutBenchmark() : super('Valence: Broad Fan-out (100)');
  late Store s;
  final List<Reactor> reactors = [];
  int runs = 0;

  @override
  void setup() {
    s = store(0);
    for (var i = 0; i < 100; i++) {
      reactors.add(
        reactor(() {
          s();
          runs++;
        }),
      );
    }
  }

  @override
  void run() => s.dispatch(const Increment());
}
