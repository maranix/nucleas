import 'package:valence/src/core/node/nodes.dart';

typedef Reducer<T, E> = T Function(T state, E event);

typedef SubscribeCallback = S Function<S>(Subscribable<S>);

typedef EqualityCallback<T> = bool Function(T a, T b);
