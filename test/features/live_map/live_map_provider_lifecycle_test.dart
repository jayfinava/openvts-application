import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/features/live_map/controllers/live_map_providers.dart';
import 'package:open_vts/features/live_map/controllers/live_map_vehicle_history_controller.dart';
import 'package:open_vts/features/live_map/models/live_map_role_config.dart';
import 'package:open_vts/features/live_map/services/live_map_vehicle_service.dart';
import 'package:open_vts/shared/models/vehicle_summary.dart';

void main() {
  test(
    'visiting vehicles releases details when the drawer stops watching',
    () async {
      final service = _Service();
      final container = ProviderContainer(
        overrides: [
          currentLiveMapConfigProvider.overrideWithValue(
            LiveMapRoleConfig.user(),
          ),
          liveMapVehicleServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      for (var index = 0; index < 100; index++) {
        final provider = liveMapVehicleDetailsProvider('imei-$index');
        final listener = container.listen(provider, (_, __) {});
        await container.read(provider.future);
        expect(container.exists(provider), isTrue);
        listener.close();
        await container.pump();
        expect(container.exists(provider), isFalse);
      }
      expect(service.detailsCalls, 100);
      final firstAgain = liveMapVehicleDetailsProvider('imei-0');
      final listener = container.listen(firstAgain, (_, __) {});
      await container.read(firstAgain.future);
      expect(service.detailsCalls, 101);
      listener.close();
    },
  );

  test(
    'one-shot command details lookup completes after provider disposal',
    () async {
      final service = _Service();
      service.pendingDetails = Completer<LiveMapVehicleDetails>();
      final container = ProviderContainer(
        overrides: [
          currentLiveMapConfigProvider.overrideWithValue(
            LiveMapRoleConfig.user(),
          ),
          liveMapVehicleServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final provider = liveMapVehicleDetailsProvider('imei-command');
      final lookup = container.read(provider.future);
      await container.pump();
      expect(container.exists(provider), isFalse);
      const details = LiveMapVehicleDetails.empty(imei: 'imei-command');
      service.pendingDetails!.complete(details);
      expect(await lookup, same(details));
    },
  );

  test(
    'older history response cannot replace the current vehicle request',
    () async {
      final service = _Service();
      final controller = LiveMapVehicleHistoryController(service);
      addTearDown(controller.dispose);
      final first = _request('first');
      final second = _request('second');
      final firstLoad = controller.loadHistory(first);
      final secondLoad = controller.loadHistory(second);
      expect(service.tokens['first']!.isCancelled, isTrue);
      final currentHistory = _history(second);
      service.histories['second']!.complete(currentHistory);
      await secondLoad;
      service.histories['first']!.complete(_history(first));
      await firstLoad;
      expect(controller.state.request, same(second));
      expect(controller.state.history, same(currentHistory));
      expect(controller.state.isLoading, isFalse);
    },
  );

  test(
    'older history failure cannot replace the current successful request',
    () async {
      final service = _Service();
      final controller = LiveMapVehicleHistoryController(service);
      addTearDown(controller.dispose);
      final firstLoad = controller.loadHistory(_request('first'));
      final second = _request('second');
      final secondLoad = controller.loadHistory(second);
      final history = _history(second);
      service.histories['second']!.complete(history);
      await secondLoad;
      service.histories['first']!.completeError(StateError('late failure'));
      await firstLoad;
      expect(controller.state.history, same(history));
      expect(controller.state.errorMessage, isNull);
    },
  );

  test('clearing pending history cancels the request and ignores its response',
      () async {
    final service = _Service();
    final controller = LiveMapVehicleHistoryController(service);
    addTearDown(controller.dispose);
    final request = _request('cleared');
    final load = controller.loadHistory(request);
    controller.clearHistory();
    expect(service.tokens['cleared']!.isCancelled, isTrue);
    expect(controller.state.isLoading, isFalse);
    service.histories['cleared']!.complete(_history(request));
    await load;
    expect(controller.state.history, isNull);
  });

  for (final fail in [false, true]) {
    test(
      'leaving map during history ${fail ? 'failure' : 'success'} is safe',
      () async {
        final service = _Service();
        final controller = LiveMapVehicleHistoryController(service);
        final request = _request('closing');
        final load = controller.loadHistory(request);
        controller.dispose();
        if (fail) {
          service.histories['closing']!.completeError(StateError('offline'));
        } else {
          service.histories['closing']!.complete(_history(request));
        }
        await expectLater(load, completes);
      },
    );
  }
}

LiveMapVehicleHistoryRequest _request(String imei) =>
    LiveMapVehicleHistoryRequest(
      vehicle: VehicleSummary(
        id: imei,
        imei: imei,
        name: imei,
        plateNumber: imei,
        status: 'running',
        speed: 20,
        latitude: 20,
        longitude: 70,
      ),
      from: DateTime(2026, 10, 8),
      to: DateTime(2026, 10, 9),
      stopMinutes: 5,
    );

LiveMapVehicleHistory _history(LiveMapVehicleHistoryRequest request) =>
    LiveMapVehicleHistory(
      request: request,
      points: const [],
      segments: const [],
      stopMarkers: const [],
      overspeedSegments: const [],
    );

class _Service extends LiveMapVehicleService {
  _Service()
      : super(apiClient: ApiClient(Dio()), config: LiveMapRoleConfig.user());

  int detailsCalls = 0;
  Completer<LiveMapVehicleDetails>? pendingDetails;
  final histories = <String, Completer<LiveMapVehicleHistory>>{};
  final tokens = <String, CancelToken>{};

  @override
  Future<LiveMapVehicleDetails> getVehicleDetailsByImei(String imei) async {
    detailsCalls++;
    return pendingDetails == null
        ? LiveMapVehicleDetails.empty(imei: imei)
        : pendingDetails!.future;
  }

  @override
  Future<LiveMapVehicleHistory> getVehicleHistory(
    LiveMapVehicleHistoryRequest request, {
    int maxPoints = 5000,
    CancelToken? cancelToken,
  }) {
    final completer = Completer<LiveMapVehicleHistory>();
    tokens[request.imei] = cancelToken!;
    histories[request.imei] = completer;
    return completer.future;
  }
}
