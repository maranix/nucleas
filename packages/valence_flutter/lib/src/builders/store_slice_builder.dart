import 'package:flutter/widgets.dart';
import 'package:valence/valence.dart';

import 'package:valence_flutter/src/types.dart';

class StoreSliceBuilder<T> extends StatefulWidget {
  const StoreSliceBuilder({
    super.key,
    required this.slice,
    required this.builder,
  });

  final StoreSlice<T> slice;
  final WidgetValueBuilder<T> builder;

  @override
  State<StoreSliceBuilder<T>> createState() => _StoreSliceBuilderState<T>();
}

class _StoreSliceBuilderState<T> extends State<StoreSliceBuilder<T>> {
  late T _value;

  void _onChangeListener(T value) {
    setState(() {
      _value = value;
    });
  }

  @override
  void initState() {
    super.initState();

    _value = widget.slice();
    widget.slice.addListener(_onChangeListener);
  }

  @override
  void dispose() {
    widget.slice.removeListener(_onChangeListener);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_value);
  }
}
