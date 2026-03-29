import 'dart:async';

import 'package:valence/src/config.dart';
import 'package:valence/src/engine/node.dart';
import 'package:valence/src/engine/scope.dart';
import 'package:valence/types.dart';
import 'package:valence/utils/equality.dart';

abstract interface class Resource<T> {
  ResourceState<T> call();
}

Resource<T> resource<T>(
  Future<T> Function() compute, {
  Scope? scope,
  EqualityCallback<T>? equals,
  FilterCallback<T>? filter,
  String? debugLabel,
}) => _ResourceImpl<T>(
  compute,
  scope: scope,
  equals: equals,
  filter: filter,
  debugLabel: debugLabel,
);

final class _ResourceImpl<T> extends RelayNode<T> implements Resource<T> {
  _ResourceImpl(
    this._compute, {
    Scope? scope,
    EqualityCallback<T>? equals,
    FilterCallback<T>? filter,
    super.debugLabel,
  }) : _scope = scope ?? Valence.root,
       _equals = equals ?? defaultEquals,
       _filter = filter {
    _scope.addRoot(this);
  }

  final Future<T> Function() _compute;

  final Scope _scope;

  final EqualityCallback<T> _equals;
  final FilterCallback<T>? _filter;

  ResourceState<T> _state = .loading();

  bool _initialized = false;

  int _executionId = 0;

  @override
  Scope get scope => _scope;
  @override
  EqualityCallback<T> get equals => _equals;
  @override
  FilterCallback<T>? get filter => _filter;

  @override
  ResourceState<T> call() {
    reportRead();

    if (!_initialized) {
      _run();
      _initialized = true;
    }

    return _state;
  }

  @override
  void recompute() {
    if (!_initialized) return;
    _run();
  }

  void _run() {
    _executionId++;

    final currentId = _executionId;

    late Future<T> future;
    executeTracked(() {
      future = _compute();
    });

    final ResourceState<T> loadingState = .loading(_state.data);
    if (_state != loadingState) {
      _state = loadingState;
      notifyDependents();
    }

    future.then(
      (data) => _handleFutureResult(data, currentId),
      onError: (error, stackTrace) =>
          _handleError(error, stackTrace, currentId),
    );
  }

  void _handleFutureResult(T data, int futureId) {
    if (_executionId != futureId) return;

    assert(
      data is! Node,
      'Type Error: Illegal attempt to return a reactive Node from a Resource computation.',
    );

    final unchanged = switch (_state) {
      ResourceLoaded(data: final oldData) => equals(oldData, data),
      _ => false,
    };

    if (unchanged) return;
    if (filter != null && !filter!(data)) return;

    _state = .loaded(data);
    notifyDependents();
  }

  void _handleError(Object error, StackTrace stackTrace, int futureId) {
    _state = .error(error, data: _state.data, stackTrace: stackTrace);
  }

  @override
  void dispose() {
    _executionId++;
    super.dispose();
  }
}

sealed class ResourceState<T> {
  const ResourceState(this.data);

  final T? data;

  bool get hasData => data != null;

  bool get isLoading => this is ResourceLoading;
  bool get isLoaded => this is ResourceLoaded;
  bool get isError => this is ResourceError;

  factory ResourceState.loading([T? data]) = ResourceLoading;
  factory ResourceState.loaded(T data) = ResourceLoaded;
  factory ResourceState.error(Object error, {T? data, StackTrace stackTrace}) =
      ResourceError;
}

final class ResourceLoading<T> extends ResourceState<T> {
  const ResourceLoading([super.data]);

  @override
  int get hashCode => data.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceLoading<T>) && other.data == data;
}

final class ResourceLoaded<T> extends ResourceState<T> {
  const ResourceLoaded(this._value) : super(_value);

  final T _value;

  @override
  T get data => _value;

  @override
  int get hashCode => data.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceLoaded<T>) && other.data == data;
}

final class ResourceError<T> extends ResourceState<T> {
  const ResourceError(this.error, {T? data, this.stackTrace}) : super(data);

  final Object error;
  final StackTrace? stackTrace;

  @override
  int get hashCode => data.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceError<T>) && other.data == data && other.error == error;
}
