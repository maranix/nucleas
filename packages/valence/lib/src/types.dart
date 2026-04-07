import 'package:valence/src/core/node/nodes.dart';

typedef SubscribeCallback = S Function<S>(Subscribable<S>);

typedef EqualityCallback<T> = bool Function(T a, T b);
