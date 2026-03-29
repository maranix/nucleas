import 'package:meta/meta.dart';
import 'package:valence/src/engine/scope.dart';
import 'package:valence/types.dart';

abstract base class BaseNode implements Node {
  BaseNode({String? debugLabel}) : _debugLabel = debugLabel;

  final String? _debugLabel;

  @override
  String get debugLabel => _debugLabel ?? runtimeType.toString();
}

abstract base class OriginNode<T> extends BaseNode
    with SourceMixin, DisposeMixin, EqualityMixin<T>, FilterMixin<T> {
  OriginNode({super.debugLabel});

  @override
  int get depth => 0;

  @override
  void dispose() {
    if (disposed) return;
    markDisposed();
    clearDependents();
  }
}

abstract base class RelayNode<T> extends BaseNode
    with SourceMixin, SubscriberMixin, DisposeMixin, EqualityMixin<T>, FilterMixin<T> {
  RelayNode({super.debugLabel});

  @override
  void dispose() {
    if (disposed) return;
    markDisposed();
    clearDependents();
    unsubscribeFromSources();
  }
}

abstract base class ObserverNode extends BaseNode
    with SubscriberMixin, DisposeMixin {
  ObserverNode({super.debugLabel});

  @override
  void dispose() {
    if (disposed) return;
    markDisposed();
    unsubscribeFromSources();
  }
}

/// Represents a node in the dependency graph.
abstract interface class Node {
  String get debugLabel;

  /// The depth of this node in the dependency graph.
  ///
  /// This is used for topological sorting during the update phase to ensure
  /// that all sources are updated before their dependents.
  int get depth;

  bool get disposed;

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
  set lastAccessedEpoch(int epoch);

  /// Internal marker used by the dependent to diff source nodes in O(1).
  int get trackingEpoch;
  set trackingEpoch(int epoch);

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

  void propagateDepth(int depth);
}

/// Represents a node that depends on one or more [Source]s and [Dependent]s.
///
/// A [Dependent] listens to sources and other dependents and reacts to their
/// changes, typically by scheduling a recomputation of its own state.
abstract interface class Dependent implements Node {
  bool get isScheduled;
  set isScheduled(bool value);

  /// Recomputes the node's state based on the current values of its sources.
  ///
  /// This method is called by the reactive engine during the update phase.
  void recompute();

  /// Wraps a [computation], tracks any Sources read during its execution,
  /// and automatically updates the dependency subscriptions.
  void executeTracked(VoidCallback computation);

  void updateDepth(int depth);
}

/// Provides value equality comparison via an [equals] callback.
///
/// The concrete class must supply the [equals] getter, typically from
/// a constructor parameter or a default like [defaultEquals].
mixin EqualityMixin<T> on Node {
  /// The equality function used to compare values of type [T].
  @protected
  EqualityCallback<T> get equals;
}

/// Provides conditionally halting of the value update via a [filter] callback.
///
/// If [filter] returns false, the node drops the pending state
/// and skips notifying its dependents.
mixin FilterMixin<T> on Node {
  /// The filter condition evaluated for any incoming state of type [T].
  @protected
  FilterCallback<T>? get filter;
}

/// Manages disposal state for a [Node].
///
/// Provides [disposed] tracking and a [markDisposed] method to flag the
/// node as disposed. The concrete class is responsible for implementing
/// [dispose] and calling [markDisposed] within it.
mixin DisposeMixin implements Node {
  bool _disposed = false;

  @override
  bool get disposed => _disposed;

  /// Marks this node as disposed.
  @protected
  void markDisposed() => _disposed = true;
}

/// Implements [Source] dependent-management and graph integration.
///
/// Provides dependent list management ([addDependent], [removeDependent],
/// [notifyDependents]), read-tracking ([reportRead], [lastAccessedEpoch]),
/// and a protected [clearDependents] for use during disposal.
///
/// Requires a concrete [scope] getter to be provided by the class.
mixin SourceMixin on Node implements Source {
  /// The [Scope] this source belongs to.
  Scope get scope;

  int _lastAccessedEpoch = -1;

  int _trackingEpoch = 0;

  final List<Dependent> _dependents = [];

  @override
  Iterable<Dependent> get dependents => _dependents;

  @override
  int get lastAccessedEpoch => _lastAccessedEpoch;

  @override
  set lastAccessedEpoch(int epoch) => _lastAccessedEpoch = epoch;

  @override
  int get trackingEpoch => _trackingEpoch;

  @override
  set trackingEpoch(int epoch) => _trackingEpoch = epoch;

  @override
  void addDependent(Dependent node) {
    _dependents.add(node);
  }

  @override
  void removeDependent(Dependent node) {
    final i = _dependents.indexOf(node);
    if (i < 0) return;

    _dependents[i] = _dependents.last;
    _dependents.removeLast();
  }

  @override
  void reportRead() {
    scope.graph.record(this);
  }

  /// Pushes a new minimum depth to all dependents.
  /// If a dependent's depth is already higher, it ignores it.
  @override
  void propagateDepth(int newDepth) {
    for (var i = 0; i < _dependents.length; i++) {
      _dependents[i].updateDepth(newDepth);
    }
  }

  @override
  void notifyDependents() {
    if (_dependents.isEmpty) return;
    scope.schedular.enqueueAll(_dependents);
  }

  /// Clears the dependents list. Call during disposal.
  @protected
  void clearDependents() {
    _dependents.clear();
  }
}

/// Implements [Dependent] dependency-tracking behaviour.
///
/// Provides [executeTracked] which records which [Source]s are read during
/// a computation and automatically maintains the subscription set and graph
/// [depth]. Exposes [unsubscribeFromSources] for use during disposal.
///
/// Requires a concrete [scope] getter to be provided by the class.
mixin SubscriberMixin on Node implements Dependent {
  static int _globalTrackingEpoch = 0;

  /// The [Scope] this dependent belongs to.
  Scope get scope;

  int _depth = 0;
  bool _isScheduled = false;
  List<Source> _sources = [];

  @override
  bool get isScheduled => _isScheduled;

  @override
  set isScheduled(bool value) => _isScheduled = value;

  @override
  int get depth => _depth;

  /// Unsubscribes this node from all currently tracked [Source]s.
  @protected
  void unsubscribeFromSources() {
    for (var i = 0; i < _sources.length; i++) {
      _sources[i].removeDependent(this);
    }
    _sources.clear();
  }

  void _updateSources(List<Source> sources) {
    if (sources.isEmpty) return;

    if (_sourcesUnchanged(sources)) {
      _updateDepth(sources);
      return;
    }

    _globalTrackingEpoch += 2;
    final currTrackingEpoch = _globalTrackingEpoch;

    for (var i = 0; i < sources.length; i++) {
      sources[i].trackingEpoch = currTrackingEpoch;
    }

    for (var i = 0; i < _sources.length; i++) {
      final oldSrc = _sources[i];

      if (oldSrc.trackingEpoch == currTrackingEpoch) {
        oldSrc.trackingEpoch = currTrackingEpoch + 1;
      } else {
        oldSrc.removeDependent(this);
      }
    }

    for (var i = 0; i < sources.length; i++) {
      final newSrc = sources[i];

      if (newSrc.trackingEpoch == currTrackingEpoch) {
        newSrc.addDependent(this);
      }
    }

    _sources = sources;
    _updateDepth(sources);
  }

  bool _sourcesUnchanged(List<Source> sources) {
    if (sources.length != _sources.length) return false;

    for (var i = 0; i < sources.length; i++) {
      if (!identical(sources[i], _sources[i])) return false;
    }

    return true;
  }

  /// Recomputes the [depth] of this node from the maximum depth among
  /// its dependent-typed sources.
  void _updateDepth(List<Source> sources) {
    var maxDepth = 0;

    for (var i = 0; i < sources.length; i++) {
      final src = sources[i];
      if (src.depth > maxDepth) maxDepth = src.depth;
    }

    final newDepth = maxDepth + 1;

    if (newDepth > _depth) {
      _depth = newDepth;

      if (this is Source) {
        (this as Source).propagateDepth(newDepth);
      }
    }
  }

  @override
  void updateDepth(int depth) {
    assert(
      _depth < 100,
      'Circular dependency detected! Depth exceeded 100 levels.',
    );

    if (depth >= _depth) {
      _depth = depth + 1;

      if (this is Source) {
        (this as Source).propagateDepth(_depth);
      }
    }
  }

  @override
  void executeTracked(VoidCallback computation) {
    final sources = scope.graph.track(computation);
    _updateSources(sources);
  }
}
