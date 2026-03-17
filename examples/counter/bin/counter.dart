import 'package:valence/valence.dart';

void main() async {
  final counter = Atom(0);
  final count = Computed(() => counter.value() * 10);

  Effect(() {
    print("Effect fired! Computed count is: ${count.value()}");
  });

  print("--- Running Batched Updates ---");
  counter.update((c) => c + 1);
  await Future.delayed(.new(seconds: 1));
  counter.update((c) => c + 1);
  await Future.delayed(.new(seconds: 1));
  counter.update((c) => c + 1);
  await Future.delayed(.new(seconds: 1));

  print("--- Done ---");
}
