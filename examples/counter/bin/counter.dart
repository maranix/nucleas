import 'package:valence/valence.dart';

final class Increment extends Action<int> {
  const Increment();

  @override
  int reduce(int state) => state + 1;
}

final class Decrement extends Action<int> {
  const Decrement();

  @override
  int reduce(int state) => state - 1;
}

void main() async {
  final counter = store(0);
  final count = derive(() => counter() * 10);

  reactor(() {
    print("Effect fired! Computed count is: ${count()}");
  });

  print("--- Running Batched Updates ---");
  counter.dispatch(const Increment());
  await Future.delayed(.new(seconds: 1));
  counter.dispatch(const Increment());
  await Future.delayed(.new(seconds: 1));
  counter.dispatch(const Increment());
  await Future.delayed(.new(seconds: 1));

  print("--- Done ---");
}
