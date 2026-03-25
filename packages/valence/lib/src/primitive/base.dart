import 'dart:math' as math;

import 'package:valence/src/config.dart';
import 'package:valence/src/engine/node.dart';
import 'package:valence/src/engine/scope.dart';
import 'package:valence/src/primitive/action.dart';
import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

part 'store.dart';
part 'reactor.dart';
part 'derive.dart';

abstract base class BaseSource<S> implements Source {
  BaseSource({Scope? scope, EqualityCallback<S>? equals})
    : _scope = scope ?? Valence.root,
      _equals = equals ?? defaultEquals {
    _scope.addRoot(this);
  }

  final Scope _scope;
  final EqualityCallback<S> _equals;
  final List<Dependent> _dependents = [];

  int _lastAccessedEpoch = -1;

  @override
  int get lastAccessedEpoch => _lastAccessedEpoch;

  @override
  set lastAccessedEpoch(int epoch) => _lastAccessedEpoch = epoch;

  @override
  void reportRead() {
    _scope.graph.record(this);
  }

  @override
  Iterable<Dependent> get dependents => _dependents;

  @override
  void addDependent(Dependent node) => _dependents.add(node);

  @override
  void removeDependent(Dependent node) {
    final i = _dependents.indexOf(node);
    if (i < 0) return;

    _dependents[i] = _dependents.last;
    _dependents.removeLast();
  }

  @override
  void notifyDependents() {
    _scope.schedular.batch(() {
      for (var i = 0; i < _dependents.length; i++) {
        _scope.schedular.enqueue(_dependents[i]);
      }
    });
  }

  @override
  void dispose() => _dependents.clear();
}

abstract base class BaseDependent with DependentMixin {
  BaseDependent({Scope? scope}) : _scope = scope ?? Valence.root;

  late final int _id;

  @override
  int get id => _id;

  @override
  final Scope _scope;

  @override
  void dispose() {
    _unsubcribeFromSources();
  }
}

mixin DependentMixin implements Dependent {
  Scope get _scope;

  int _depth = 0;

  List<Source> _sources = [];

  @override
  int get depth => _depth;

  void _updateSources(List<Source> sources) {
    final derives = sources.whereType<Dependent>();

    if (_sourcesUnchanged(sources)) {
      _updateDepth(derives);
      return;
    }

    for (final old in _sources) {
      if (!sources.contains(old)) {
        old.removeDependent(this);
      }
    }

    for (final newSrc in sources) {
      if (!_sources.contains(newSrc)) {
        newSrc.addDependent(this);
      }
    }

    _sources = sources;
    _updateDepth(derives);
  }

  bool _sourcesUnchanged(List<Source> sources) {
    if (sources.length != _sources.length) return false;

    for (var i = 0; i < sources.length; i++) {
      if (!identical(sources[i], _sources[i])) return false;
    }

    return true;
  }

  /// Runs the effect, tracking any [Source]s read during execution.
  ///
  /// After the run, subscribes to any new sources, unsubscribes from
  /// any dropped ones, and updates [depth] based on the new source set.
  void _updateDepth(Iterable<Dependent> dependents) {
    var maxDepth = 0;

    for (final dependent in dependents) {
      maxDepth = math.max(dependent.depth, maxDepth);
    }

    _depth = maxDepth + 1;
  }

  void _unsubcribeFromSources() {
    for (final source in _sources) {
      source.removeDependent(this);
    }
    _sources.clear();
  }

  @override
  void executeTracked(VoidCallback computation) {
    final sources = _scope.graph.track(computation);
    _updateSources(sources);
  }
}
