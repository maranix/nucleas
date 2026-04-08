import 'package:flutter/widgets.dart';
import 'package:valence/valence.dart';

class StoreBuilder<T, E extends StoreEvent<T>> extends StatefulWidget {
  const StoreBuilder({
    super.key,
    required this.store,
    required this.builder,
  });

  final Store<T, E> store;
  final Widget Function(T) builder;

  @override
  State<StoreBuilder<T, E>> createState() => _StoreBuilderState<T, E>();
}

class _StoreBuilderState<T, E extends StoreEvent<T>>
    extends State<StoreBuilder<T, E>> {
  late final StoreSlice<T> _slice;
  late T _value;

  void _onChangeListener(T value) {
    setState(() {
      _value = value;
    });
  }

  @override
  void initState() {
    super.initState();

    _slice = widget.store();
    _slice.addListener(_onChangeListener);

    _value = _slice();
  }

  @override
  void dispose() {
    _slice.removeListener(_onChangeListener);
    _slice.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_value);
  }
}
