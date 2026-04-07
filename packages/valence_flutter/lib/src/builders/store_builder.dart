import 'package:flutter/widgets.dart' hide Action;
import 'package:valence/valence.dart';

class StoreBuilder<T> extends StatefulWidget {
  const StoreBuilder({
    super.key,
    required this.store,
    required this.builder,
    this.filter,
  });

  final Store<T, Action> store;
  final Widget Function(T) builder;
  final R Function<R>(T)? filter;

  @override
  State<StoreBuilder<T>> createState() => _StoreBuilderState<T>();
}

class _StoreBuilderState<T> extends State<StoreBuilder<T>> {
  late final Select<T> _select;
  late T _value;

  void _onChangeListener(T value) {
    setState(() {
      _value = value;
    });
  }

  @override
  void initState() {
    super.initState();

    if (widget.filter != null) {
      _select = widget.store.select(widget.filter!);
    } else {
      _select = widget.store();
    }

    _value = _select();

    _select.addListener(_onChangeListener);
  }

  @override
  void dispose() {
    _select.removeListener(_onChangeListener);
    _select.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_value);
  }
}
