part of 'base.dart';

/// Creates a new [Reactor].
///
/// {@macro valence.Reactor}
Reactor reactor(
  VoidCallback fn, {
  Scope? scope,
}) => Reactor(fn, scope: scope);

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
final class Reactor extends BaseDependent {
  /// Creates a new [Reactor].
  ///
  /// {@macro valence.Reactor}
  Reactor(this._fn, {super.scope}) {
    recompute();
  }

  final VoidCallback _fn;

  @override
  void recompute() {
    executeTracked(_fn);
  }
}
