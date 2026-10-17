import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_options.dart';
import '../controllers/live_map_scene_store.dart';
import '../models/live_map_fleet.dart';

/// The same bounded HTTP contracts used by the web fleet map. There is no
/// fallback to a full-fleet download on errors, expiry, or denied access.
class LiveMapFleetService {
  LiveMapFleetService(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    required CancelToken cancelToken,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
      options: normalReadOptions(),
      cancelToken: cancelToken,
      parser: (raw) {
        if (raw is! Map) throw const FormatException('Invalid map response');
        final data = raw['data'] is Map ? raw['data'] as Map : raw;
        return Map<String, dynamic>.from(data);
      },
    );
    return response.data;
  }

  Future<LiveMapFleetPage> directory({
    required CancelToken cancelToken,
    String search = '',
    String status = 'all',
    String? cursor,
  }) async {
    final data =
        await get('/map/v2/vehicles', cancelToken: cancelToken, query: {
      'limit': 100,
      'sort': 'name',
      if (search.isNotEmpty) 'search': search,
      if (status != 'all') 'status': status,
      if (cursor != null) 'cursor': cursor,
    });
    final rows = data['rows'];
    if (rows is! List || rows.length > 100 || rows.any((row) => row is! Map)) {
      throw const FormatException('Invalid vehicle directory page');
    }
    if (data['scopeRevision'] is! String ||
        (data['scopeRevision'] as String).isEmpty ||
        data['queryRevision'] is! String ||
        (data['queryRevision'] as String).isEmpty ||
        rows.map((row) => '${row['vehicleId'] ?? row['id']}').toSet().length !=
            rows.length) {
      throw const FormatException('Invalid directory generation or identities');
    }
    String? cursorValue(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! String || value.isEmpty || value.length > 180) {
        throw const FormatException('Invalid directory cursor');
      }
      return value;
    }

    final next = cursorValue('nextCursor');
    if (data['hasMore'] == true && (next == null || next == cursor)) {
      throw const FormatException('Directory pagination did not advance');
    }
    return LiveMapFleetPage(
      rows: rows.map(normalizeRow).toList(growable: false),
      total: _nonnegative(data['total']),
      start: _nonnegative(data['pageStart']),
      nextCursor: next,
      previousCursor: cursorValue('previousCursor'),
      queryRevision: '${data['queryRevision'] ?? ''}',
      scopeRevision: '${data['scopeRevision'] ?? ''}',
    );
  }

  static int _nonnegative(dynamic value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid directory count');
    }
    return value;
  }

  static Map<String, dynamic> normalizeRow(dynamic raw) {
    if (raw is! Map) throw const FormatException('Invalid vehicle row');
    final row = Map<String, dynamic>.from(raw);
    final id = row['vehicleId'] ?? row['id'];
    if (id is! int ||
        id <= 0 ||
        id > 9007199254740991 ||
        row['canViewLive'] is! bool ||
        row['bindingVersion'] is! int ||
        row['serviceRevision'] is! int ||
        row['service'] is! Map) {
      throw const FormatException('Invalid vehicle identity or access');
    }
    final state = row['state'];
    if (state != null &&
        (!LiveMapSceneStore.validState(state) || state['vehicleId'] != id)) {
      throw const FormatException('Invalid vehicle state');
    }
    return row;
  }
}
