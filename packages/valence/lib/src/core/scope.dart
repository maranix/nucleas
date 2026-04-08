import 'package:meta/meta.dart';
import 'package:valence/src/core/registry.dart';
import 'package:valence/src/core/scheduler.dart';

/// Returns a new instance of [ValenceScope].
ValenceScope createScope() => .new();

abstract interface class ValenceScope {
  factory ValenceScope() = _ScopeImpl;

  @mustCallSuper
  void dispose();
}

abstract interface class Scope implements ValenceScope {
  factory Scope() = _ScopeImpl;

  static Scope of(ValenceScope scope) => scope as Scope;

  NodeRegistry get registry;

  NodeScheduler get scheduler;
}

final class _ScopeImpl implements Scope, ValenceScope {
  _ScopeImpl({NodeRegistry? registry, NodeScheduler? scheduler})
    : _registry = registry ?? .new(),
      _scheduler = scheduler ?? .new();

  final NodeRegistry _registry;

  final NodeScheduler _scheduler;

  @override
  NodeRegistry get registry => _registry;

  @override
  NodeScheduler get scheduler => _scheduler;

  @override
  void dispose() {
    _registry.dispose();
  }
}
