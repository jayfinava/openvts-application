import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/features/live_map/services/live_map_fleet_service.dart';

import 'fleet_wire_fixture.dart';

void main() {
  for (final invalid in [
    'identity',
    'access',
    'state',
    'count',
    'cursor',
    'oversize'
  ]) {
    test('rejects malformed $invalid without publishing a partial directory',
        () async {
      final row = fleetDirectoryRow(1);
      final data = <String, dynamic>{
        'rows': [row],
        'total': 1,
        'pageStart': 0,
        'scopeRevision': 'scope',
        'queryRevision': 'query',
        'hasMore': false
      };
      switch (invalid) {
        case 'identity':
          row['vehicleId'] = 'invalid';
        case 'access':
          row['canViewLive'] = null;
        case 'state':
          (row['state'] as Map)['vehicleId'] = 2;
        case 'count':
          data['total'] = -1;
        case 'cursor':
          data['hasMore'] = true;
          data['nextCursor'] = 'same';
        case 'oversize':
          data['rows'] = List.generate(101, (i) => fleetDirectoryRow(i + 1));
      }
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      addTearDown(() => dio.close(force: true));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
        handler.resolve(Response(
            requestOptions: request,
            statusCode: 200,
            data: {'action': true, 'data': data}));
      }));
      final service = LiveMapFleetService(ApiClient(dio));
      await expectLater(
          service.directory(
              cancelToken: CancelToken(),
              cursor: invalid == 'cursor' ? 'same' : null),
          throwsA(anything));
    });
  }
}
