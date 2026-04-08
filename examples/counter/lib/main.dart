import 'package:flutter/material.dart';
import 'package:valence_flutter/valence_flutter.dart';

enum CounterStoreEvent implements StoreEvent<int> {
  increment,
  decrement;

  @override
  int reduce(int count) => switch (this) {
    .increment => count + 1,
    .decrement => count - 1,
  };
}

void main() {
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CounterPage());
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final counterStore = store<int, CounterStoreEvent>(0);

  @override
  void dispose() {
    counterStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Counter")),
      body: Center(
        child: StoreBuilder(
          store: counterStore,
          builder: (count) =>
              Text('$count', style: Theme.of(context).textTheme.displayLarge),
        ),
      ),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => counterStore.dispatch(.increment),
          ),
          const SizedBox(height: 4),
          FloatingActionButton(
            child: const Icon(Icons.remove),
            onPressed: () => counterStore.dispatch(.decrement),
          ),
        ],
      ),
    );
  }
}
