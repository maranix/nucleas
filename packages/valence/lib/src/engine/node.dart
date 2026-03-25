import 'package:valence/types.dart';

/// Represents a node in the dependency graph.
abstract interface class Node {
  bool get isDisposed;

  /// Disposes the node and cleans up any resources it holds.
  void dispose();
}

/// Represents a data source in the dependency graph.
///
/// A [Source] can have multiple [Dependent] nodes attached to it. When the
/// source's value changes, it is responsible for notifying its dependents
/// so they can recompute or update their state.
abstract interface class Source implements Node {
  /// Internal marker used by the Graph for O(1) deduplication.
  int get lastAccessedEpoch;
  set lastAccessedEpoch(int value);

  /// The dependents of this source.
  Iterable<Dependent> get dependents;

  /// Registers a [Dependent] node to receive updates from this source.
  void addDependent(Dependent node);

  /// Unregisters a previously registered [Dependent] node so it no longer
  /// receives updates from this source.
  void removeDependent(Dependent node);

  void notifyDependents();

  /// Reports to the current scope's graph that this source was read.
  void reportRead();
}

/// Represents a node that depends on one or more [Source]s and [Dependent]s.
///
/// A [Dependent] listens to sources and other dependents and reacts to their
/// changes, typically by scheduling a recomputation of its own state.
abstract interface class Dependent implements Node {
  bool get isScheduled;
  set isScheduled(bool value);

  /// The depth of this node in the dependency graph.
  ///
  /// This is used for topological sorting during the update phase to ensure
  /// that all sources are updated before their dependents.
  int get depth;

  /// Recomputes the node's state based on the current values of its sources.
  ///
  /// This method is called by the reactive engine during the update phase.
  void recompute();

  /// Wraps a [computation], tracks any Sources read during its execution,
  /// and automatically updates the dependency subscriptions.
  void executeTracked(VoidCallback computation);
}
