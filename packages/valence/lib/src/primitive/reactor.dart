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
/// re-subscribing to whatever sources were read during the latest run.
///
/// On recomputation, [Reactor] first probes its existing [Source]s
/// to check stability before committing to a full run — avoiding
/// unnecessary work when the source set has not changed.
/// {@endtemplate}
final class Reactor extends BaseDependent {
  /// Creates a new [Reactor].
  ///
  /// {@macro valence.Reactor}
  Reactor(this._fn, {super.scope}) {
    run();
  }

  final VoidCallback _fn;

  /// Runs the effect, tracking any [Source]s read during execution.
  ///
  /// After the run, subscribes to any new sources, unsubscribes from
  /// any dropped ones, and updates [depth] based on the new source set.
  void run() {
    _scope.graph.beginTracking();
    try {
      _fn();
    } finally {
      final newDependencies = _scope.graph.endTracking();
      if (!_sourcesUnchanged(newDependencies)) {
        _updateSources(newDependencies);
      }
    }

    _isStable = true;
  }

  @override
  void recompute() {
    if (_isStable) {
      // Probe the existing sources first — if they replay identically
      // there is no need for a full re-run.
      _scope.graph.beginProbe(_sources);
      _fn();
      if (_scope.graph.endProbe(_sources.length)) return;
      _isStable = false;
    }
    run();
  }
}
