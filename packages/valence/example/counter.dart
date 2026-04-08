import 'package:valence/valence.dart';

enum CounterStoreEvent implements StoreEvent<int> {
  increment,
  decrement
  ;

  @override
  int reduce(int count) => switch (this) {
    .increment => count + 1,
    .decrement => count + 1,
  };
}

final List<CounterStoreEvent> actions = [
  .increment,
  .increment,
  .decrement,
  .increment,
  .increment,
  .increment,
];

void main() async {
  final countStore = store<int, CounterStoreEvent>(0);

  final countSlice = countStore();

  final countSquared = derive((sub) {
    final count = sub(countSlice);
    return count * 2;
  });

  watch((sub) {
    final count = sub(countSlice);
    final squaredCount = sub(countSquared);

    print("Count: $count\tSquared:$squaredCount");
  });

  while (actions.isNotEmpty) {
    countStore.dispatch(actions.removeLast());

    await Future.delayed(.new(seconds: 1));
  }
}
