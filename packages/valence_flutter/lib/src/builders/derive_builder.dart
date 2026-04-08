import 'package:flutter/widgets.dart';
import 'package:valence/valence.dart';

class DeriveBuilder<T> extends StatefulWidget {
  const DeriveBuilder({
    super.key,
    required this.derive,
    required this.builder,
  });

  final T Function(SubscribeCallback) derive;
  final Widget Function(T) builder;

  @override
  State<DeriveBuilder<T>> createState() => _DeriveBuilderState<T>();
}

class _DeriveBuilderState<T> extends State<DeriveBuilder<T>> {
  late final Derive<T> _derive;
  late T _value;

  void _onChangeListener(T value) {
    setState(() {
      _value = value;
    });
  }

  @override
  void initState() {
    super.initState();

    _derive = derive(widget.derive);
    _derive.addListener(_onChangeListener);

    _value = _derive();
  }

  @override
  void dispose() {
    _derive.removeListener(_onChangeListener);
    _derive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_value);
  }
}
