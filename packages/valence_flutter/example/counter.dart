import 'package:flutter/material.dart' hide Action;
import 'package:valence_flutter/valence_flutter.dart';

sealed class CounterAction extends Action<int> {}

final class CounterIncrement extends CounterAction {
  @override
  int reduce(int state) => state + 1;
}

final class CounterDecrement extends CounterAction {
  @override
  int reduce(int state) => state - 1;
}

void main() {
  runApp(
    const CounterApp(),
  );
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final counterStore = store<int, CounterAction>(0);

  @override
  void dispose() {
    counterStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Counter",
        ),
      ),
      body: Center(
        child: DeriveBuilder(
          derive: (sub) => sub(counterStore()),
          builder: (count) => Text(
            '$count',
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
      ),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => counterStore.dispatch(CounterIncrement()),
          ),
          const SizedBox(height: 4),
          FloatingActionButton(
            child: const Icon(Icons.remove),
            onPressed: () => counterStore.dispatch(CounterDecrement()),
          ),
        ],
      ),
    );
  }
}
