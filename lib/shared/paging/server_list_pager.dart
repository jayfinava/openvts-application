import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../core/access/workspace_scope_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_options.dart';
import '../../core/errors/error_mapper.dart';

class ListPageMeta {
  const ListPageMeta(
      {required this.page,
      required this.limit,
      required this.total,
      this.summary = const {}});
  final int page;
  final int limit;
  final int total;
  final Map<String, dynamic> summary;
  int get pages => math.max(1, (total / limit).ceil());
}

/// Keeps one backend page. Page/search changes supersede pending work rather
/// than downloading or retaining the directory. Mutations explicitly refresh.
class ServerListPager<T> {
  ServerListPager(
      {required ApiClient api,
      required String endpoint,
      required List<T> Function(dynamic) parseRows,
      this.rowsKey = 'data',
      String sortBy = 'name',
      String sortDir = 'asc',
      int limit = 20})
      : _api = api,
        _endpoint = endpoint,
        _parseRows = parseRows,
        _query = {
          'page': 1,
          'limit': limit,
          'sortBy': sortBy,
          'sortDir': sortDir
        };
  final ApiClient _api;
  final String _endpoint;
  final List<T> Function(dynamic) _parseRows;
  final String rowsKey;
  Map<String, dynamic> _query;
  Map<String, dynamic>? _committedQuery;
  List<T> items = [];
  ListPageMeta? meta;
  bool loading = false;
  String? error;
  void Function()? onChanged;
  CancelToken? _token;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _pending;
  String get search => _query['search']?.toString() ?? '';

  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    _token?.cancel('List closed');
    onChanged = null;
  }

  Future<void> load() => change(force: true);
  Future<void> goToPage(int page) =>
      change(page: page.clamp(1, meta?.pages ?? 1));

  Future<void> change(
      {int? page,
      int? limit,
      String? search,
      String? sortBy,
      String? sortDir,
      Map<String, dynamic>? filters,
      bool debounce = false,
      bool force = false}) {
    if (_disposed) return Future.value();
    final next = <String, dynamic>{
      ..._query,
      if (page != null) 'page': math.max(1, page),
      if (limit != null) 'limit': limit.clamp(1, 100),
      if (search != null)
        'search':
            search.trim().substring(0, math.min(160, search.trim().length)),
      if (sortBy != null) 'sortBy': sortBy,
      if (sortDir != null) 'sortDir': sortDir,
      if (filters != null) 'filters': jsonEncode(filters),
    };
    if (!force &&
        jsonEncode(next) == jsonEncode(_query) &&
        (loading || _committedQuery != null && error == null)) {
      return _pending ?? Future.value();
    }
    _query = next;
    final generation = ++_generation;
    _debounce?.cancel();
    _token?.cancel('List query changed');
    loading = true;
    error = null;
    onChanged?.call();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!_disposed && generation == _generation) {
          _pending = _fetch(generation, next);
        }
      });
      return Future.value();
    }
    return _pending = _fetch(generation, next);
  }

  Future<void> _fetch(int generation, Map<String, dynamic> query,
      {bool corrected = false}) async {
    final token = _token = CancelToken();
    final scope = workspaceDataScope(_api.activeUser, isDemo: _api.isDemoMode);
    bool current() =>
        !_disposed &&
        generation == _generation &&
        !token.isCancelled &&
        scope == workspaceDataScope(_api.activeUser, isDemo: _api.isDemoMode);
    try {
      final response = await _api.get<Map<String, dynamic>>(_endpoint,
          queryParameters: {
            ...query,
            'rk': DateTime.now().microsecondsSinceEpoch.toString()
          },
          options: normalReadOptions(),
          cancelToken: token, parser: (value) {
        if (value is! Map<String, dynamic> ||
            value['pagination'] is! Map ||
            value[rowsKey] is! List) {
          throw const ApiException(
              message: 'Unable to load this page. Please try again.');
        }
        return value;
      });
      if (!current()) return;
      final data = response.data;
      final p = data['pagination'] as Map;
      final page = p['page'], limit = p['limit'], total = p['total'];
      if (page is! int ||
          limit is! int ||
          total is! int ||
          page != query['page'] ||
          limit != query['limit'] ||
          total < 0 ||
          (data[rowsKey] as List).length > limit) {
        throw const ApiException(
            message: 'Unable to load this page. Please try again.');
      }
      final result = ListPageMeta(
          page: page,
          limit: limit,
          total: total,
          summary: data['summary'] is Map
              ? Map<String, dynamic>.from(data['summary'])
              : const {});
      if (page > result.pages && !corrected) {
        _query = {...query, 'page': result.pages};
        await _fetch(generation, _query, corrected: true);
        return;
      }
      final rows = _parseRows(data[rowsKey]);
      if (!current()) return;
      items = List.unmodifiable(rows);
      meta = result;
      _committedQuery = query;
      loading = false;
      error = null;
      onChanged?.call();
    } catch (failure) {
      if (!current()) return;
      loading = false;
      error = ErrorMapper.from(failure).message;
      onChanged?.call();
    }
  }
}
