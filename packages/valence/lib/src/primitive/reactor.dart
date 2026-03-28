import 'package:valence/src/config.dart';
import 'package:valence/src/engine/node.dart';
import 'package:valence/src/engine/scope.dart';
import 'package:valence/types.dart';

/// Public interface for a reactor (side-effect runner).
///
/// A reactor cannot be read — it is always a leaf node.
/// Provides lifecycle management only.
abstract interface class Reactor {
  bool get disposed;
  void dispose();
}

/// Creates a new [Reactor].
///
/// {@macro valence.Reactor}
Reactor reactor(
  VoidCallback fn, {
  Scope? scope,
}) => _ReactorImpl(fn, scope: scope);

/// {@template valence.Reactor}
/// A terminal node in the reactive graph that runs a side effect.
///
/// [Reactor] is a pure [Dependent] — it subscribes to [Source]s
/// during its computation but exposes nothing downstream.
/// Nothing can read from a [Reactor]; it is always a leaf node.
///
/// It reruns its effect whenever any of its [Source]s change,
/// automatically tracking and re-subscribing to whatever sources
/// are read during the latest execution using O(1) epoch deduplication.
/// {@endtemplate}
final class _ReactorImpl with DisposeMixin, SubscriberMixin implements Reactor {
  _ReactorImpl(this._fn, {Scope? scope}) : _scope = scope ?? Valence.root {
    recompute();
  }

  final VoidCallback _fn;
  final Scope _scope;

  @override
  bool get isLeaf => true;

  @override
  Scope get scope => _scope;

  @override
  void recompute() {
    executeTracked(_fn);
  }

  @override
  void dispose() {
    if (disposed) return;
    markDisposed();
    unsubscribeFromSources();
  }
}
