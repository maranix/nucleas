import 'package:flutter/widgets.dart';

import 'package:verion/verion.dart';
import 'package:verion_flutter/src/builders/derive_builder.dart';

class SourceBuilder<T, E extends SourceEvent<T>> extends StatelessWidget {
  const SourceBuilder({
    super.key,
    required this.source,
    required this.builder,
  });

  final Source<T, E> source;
  final Widget Function(T) builder;

  @override
  Widget build(BuildContext context) {
    return DeriveBuilder<T>(
      derive: (sub) => sub(source),
      builder: builder,
    );
  }
}
