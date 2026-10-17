import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/socket/socket_service.dart';
import '../../../shared/models/vehicle_summary.dart';
import '../models/live_map_fleet.dart';
import '../services/live_map_events_service.dart';
import '../services/live_map_fleet_service.dart';
import '../services/live_map_vehicle_service.dart';
import 'live_map_controller.dart';
import 'live_map_scene_store.dart';

/// Authenticated fleet maps use the web map-v2 protocol. Memory follows one
/// viewport, one 100-row directory page, and one selected vehicle, rather than
/// the fleet's history/metrics or an ever-growing list of downloaded pages.
class LiveMapFleetController extends LiveMapController {
  LiveMapFleetController({
    required super.vehicleService,
    required super.mapEventsService,
    required super.socketService,
    required super.config,
    required LiveMapFleetService fleetService,
    DateTime Function()? now,
  })  : _vehicles = vehicleService,
        _events = mapEventsService,
        _sockets = socketService,
        _fleet = fleetService,
        _now = now ?? DateTime.now {
    state =
        state.copyWith(fleet: const LiveMapFleetView(), isAlertsLoading: false);
  }

  final LiveMapVehicleService _vehicles;
  final LiveMapEventsService _events;
  final SocketService _sockets;
  final LiveMapFleetService _fleet;
  final DateTime Function() _now;
  final LiveMapSceneStore _store = LiveMapSceneStore();
  final Set<CancelToken> _requests = {};
  final Map<String, Map<String, dynamic>> _metrics = {};
  final Map<String, DateTime> _metricFetchedAt = {};
  final Map<String, _FleetVehicleCache> _vehicleCache = {};
  SocketConnection? _connection;
  Timer? _auditTimer,
      _interestTimer,
      _publishTimer,
      _retryTimer,
      _handshakeTimer,
      _metricsTimer,
      _expiryTimer;
  CancelToken? _directoryToken, _metricsToken, _selectionToken;
  LiveMapFleetPage _page = const LiveMapFleetPage();
  Map<String, dynamic>? _selectedRow;
  List<String> _rowIds = [];
  List<double> _bounds = [-180, -85, 180, 85];
  double _zoom = 2;
  bool _cluster = true,
      _started = false,
      _connecting = false,
      _visible = true,
      _active = true;
  bool _directoryVisible = false,
      _alertsVisible = false,
      _loadingDirectory = false,
      _loadingAlerts = false;
  bool _terminal = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  String _search = '', _status = 'all';
  String? _directoryError;
  String? _pageCursor;
  int _generation = 0,
      _directoryGeneration = 0,
      _retryAttempts = 0,
      _interestRevision = 0,
      _selectionGeneration = 0;
  DateTime? _lastMessageAt,
      _lastAlertsAt,
      _lastDirectoryAt,
      _lastMetricsAt,
      _lastReconcileAt;
  String? _metricsDay;
  bool _metricsPending = false;

  @override
  void initialize() {
    if (_started) return;
    _started = true;
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _active = _lifecycle == AppLifecycleState.resumed && _visible;
    WidgetsBinding.instance.addObserver(this);
    _auditTimer = Timer.periodic(const Duration(seconds: 4), (_) => _audit());
    if (_active) unawaited(_start());
  }

  Future<void> _start() async {
    await _connect();
    if (_directoryVisible) unawaited(refreshDirectory());
    if (_alertsVisible) unawaited(_loadAlerts());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _updateActivity();
  }

  @override
  void setScreenVisible(bool visible) {
    _visible = visible;
    _updateActivity();
  }

  void _updateActivity() {
    final next = _visible && _lifecycle == AppLifecycleState.resumed;
    if (!mounted || _active == next) return;
    _active = next;
    if (next) {
      if (!_terminal) unawaited(_start());
    } else {
      _stopConnection();
      _cancelRequests();
      _clearLive();
    }
  }

  Future<void> _connect() async {
    if (!mounted ||
        !_active ||
        _terminal ||
        _connecting ||
        _connection != null) {
      return;
    }
    _connecting = true;
    final generation = _generation;
    try {
      final connection = await _sockets.connect('/map-v2');
      if (!mounted || !_active || generation != _generation) {
        connection.disconnect();
        return;
      }
      _connection = connection;
      bool current() =>
          mounted &&
          _active &&
          generation == _generation &&
          identical(_connection, connection);
      void listen(String event, void Function(Map<String, dynamic>) handler) {
        connection.on(event, (raw) {
          if (!current() || raw is! Map) return;
          try {
            handler(Map<String, dynamic>.from(raw));
          } on FormatException {
            _protocolFailure();
          } on TypeError {
            _protocolFailure();
          }
        });
      }

      connection.onConnect(() {
        if (current()) _open();
      });
      connection.onDisconnect((_) {
        if (!current()) return;
        _cancelRequests();
        _clearLive();
        // Socket.IO reconnects transport failures. Server disconnects require
        // replacing the namespace; the bounded retry also covers that case.
        _scheduleRetry();
      });
      connection.onError((_) {
        if (current()) {
          _setError('Unable to connect live tracking. Retry.');
          _scheduleRetry();
        }
      });
      listen('map:open', (data) {
        _handshakeTimer?.cancel();
        if (!_store.open(data)) {
          _protocolFailure();
          return;
        }
        if (_page.scopeRevision.isNotEmpty &&
            _page.scopeRevision != _store.scopeRevision) {
          _page = const LiveMapFleetPage();
          _selectedRow = null;
          _directoryToken?.cancel('Map access changed');
          if (_directoryVisible) unawaited(refreshDirectory());
        }
        _lastMessageAt = _now();
        _lastReconcileAt = null;
        _interestRevision = 0;
        _sendInterest();
      });
      listen('map:scene-start',
          (data) => _sceneMessage(data, _store.begin(data), publish: false));
      listen(
          'map:scene-chunk',
          (data) => _sceneMessage(data, _store.chunk(data),
              chunk: true, publish: false));
      listen('map:scene-end', (data) {
        final accepted = _store.finish(data);
        if (accepted) {
          _retryAttempts = 0;
          _retryTimer?.cancel();
        }
        _sceneMessage(data, accepted);
      });
      listen(
          'map:scene-delta', (data) => _sceneMessage(data, _store.delta(data)));
      listen('map:scene-cancel', (data) {
        _store.cancelScene(data);
        _ack(data, discarded: true);
      });
      listen('map:state', (data) {
        if (_store.receiveStates(data)) {
          _lastMessageAt = _now();
          _schedulePublish();
          connection.emit('map:processed', {
            'sceneRevision': _store.sceneRevision,
            'sequence': _store.sequence
          });
          if (_store.needsReconcile) _protocolFailure();
        } else if (_store.needsReconcile) {
          _protocolFailure();
        }
      });
      listen('map:summary', (data) {
        if (_store.receiveSummary(data)) {
          _lastMessageAt = _now();
          _schedulePublish();
        } else if (_store.needsReconcile) {
          _protocolFailure();
        }
      });
      listen('map:interest-accepted', (data) {
        if (_store.accepts(data)) _lastMessageAt = _now();
      });
      listen('map:scope-changed', (_) => _invalidateScope());
      listen('map:reset', _reset);
      listen('map:error', (data) {
        if ([
          'unauthorized',
          'forbidden',
          'session-revoked',
          'unsupported-protocol'
        ].contains(data['code'])) {
          _reset({...data, 'reason': data['code'], 'retryable': false});
        } else {
          _setError('Live tracking is temporarily unavailable. Retry.');
          _scheduleRetry();
        }
      });
      if (connection.isConnected) _open();
    } catch (_) {
      if (mounted && _active && generation == _generation) {
        _setError('Unable to connect live tracking. Retry.');
        _scheduleRetry();
      }
    } finally {
      if (generation == _generation) _connecting = false;
    }
  }

  void _open() {
    _retryTimer?.cancel();
    _handshakeTimer?.cancel();
    _clearLive();
    _connection?.emit('map:open', {
      'protocolVersion': 2,
      'capabilities': {'snapshotChunks': true}
    });
    _handshakeTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _active && !_store.isOpen) {
        _setError('Live tracking timed out. Retry.');
        _scheduleRetry();
      }
    });
  }

  void _sceneMessage(Map<String, dynamic> data, bool accepted,
      {bool chunk = false, bool publish = true}) {
    if (accepted) {
      _lastMessageAt = _now();
      if (chunk || publish) _ack(data, chunk: chunk);
      if (publish) _schedulePublish();
    } else {
      _ack(data, chunk: chunk, discarded: true);
      if (_store.needsReconcile) _protocolFailure();
    }
  }

  void _ack(Map<String, dynamic> data,
      {bool chunk = false, bool discarded = false}) {
    _connection?.emit('map:processed', {
      'sceneRevision': data['sceneRevision'],
      if (chunk) 'chunkIndex': data['chunkIndex'],
      if (discarded)
        'discarded': true
      else if (!chunk)
        'sequence': _store.sequence,
    });
  }

  void _protocolFailure() {
    _setError('Refreshing live tracking…');
    _reconcile(scene: true);
  }

  void _reconcile({bool scene = false}) {
    if (!_store.isOpen || !_active) return;
    final now = _now();
    if (_lastReconcileAt != null &&
        now.difference(_lastReconcileAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastReconcileAt = now;
    _connection?.emit('map:reconcile', {
      'sceneRevision': _store.sceneRevision,
      'sequence': _store.sequence,
      'scene': scene
    });
  }

  void _reset(Map<String, dynamic> data) {
    _terminal = !(data['retryable'] == true &&
        const {
          'capacity',
          'server-restart',
          'scope-unavailable',
          'authorization-unavailable',
          'scene-ack-timeout',
          'state-ack-timeout',
          'authorization-expired',
        }.contains(data['reason']));
    _cancelRequests();
    _clearLive(clearDirectory: true);
    _stopConnection();
    _setError(_terminal
        ? 'Live tracking access changed. Reopen the map after signing in.'
        : 'Live tracking reconnecting…');
    if (!_terminal) _scheduleRetry();
  }

  void _invalidateScope() {
    _cancelRequests();
    _clearLive(clearDirectory: true);
    _stopConnection();
    if (_active && !_terminal) _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!mounted || !_active || _terminal || _retryTimer?.isActive == true) {
      return;
    }
    if (_retryAttempts >= 6) {
      _cancelRequests();
      _stopConnection();
      _clearLive();
      _setError('Automatic map reconnect paused. Retry to reconnect.');
      return;
    }
    final seconds = math.min(30, 1 << _retryAttempts++);
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _stopConnection();
      if (_active && !_terminal) unawaited(_start());
    });
  }

  @override
  Future<void> refreshTelemetry() async {
    if (!mounted || !_active || _terminal) return;
    _retryAttempts = 0;
    _cancelRequests();
    _stopConnection();
    _clearLive();
    await _start();
  }

  @override
  void setViewport(List<double> bounds, double zoom, {bool cluster = true}) {
    if (!LiveMapSceneStore.validBounds(bounds) || !zoom.isFinite) return;
    _bounds = List.of(bounds);
    _zoom = zoom.clamp(0, 24);
    _cluster = cluster;
    _queueInterest();
  }

  void _queueInterest() {
    if (!_active || _interestTimer?.isActive == true) return;
    _interestTimer = Timer(const Duration(milliseconds: 120), _sendInterest);
  }

  void _sendInterest() {
    _interestTimer?.cancel();
    if (!_active || !_store.isOpen || _connection?.isConnected != true) return;
    _store.interestRevision = ++_interestRevision;
    _connection!.emit('map:set-interest', {
      'interestRevision': _interestRevision, 'bounds': _bounds, 'zoom': _zoom,
      // Auto clustering retains a server safety policy when the switch is off.
      'clustering': _cluster ? 'on' : 'auto',
      'selectedId': _selectedRow?['vehicleId'] ?? _selectedRow?['id'],
      'pinnedIds': <int>[],
      'rowIds': _directoryVisible
          ? _rowIds.map(int.parse).toList(growable: false)
          : <int>[],
      'hidden': false,
      'filters': {if (_search.isNotEmpty) 'search': _search, 'status': _status},
    });
  }

  @override
  void setFleetQuery({String? search, String? status}) {
    final nextSearch = search == null
        ? _search
        : search.trim().substring(0, math.min(120, search.trim().length));
    final nextStatus = status ?? _status;
    if (nextSearch == _search && nextStatus == _status) return;
    _search = nextSearch;
    _status = nextStatus;
    _directoryToken?.cancel('Directory filter changed');
    _directoryGeneration++;
    _page = const LiveMapFleetPage();
    _pageCursor = null;
    _rowIds = [];
    _resetMetrics();
    _directoryError = null;
    _queueInterest();
    _publish();
    if (_directoryVisible && _active) unawaited(refreshDirectory());
  }

  @override
  void setDirectoryVisible(bool visible) {
    if (!mounted) return;
    if (_directoryVisible == visible) return;
    _directoryVisible = visible;
    if (!visible) {
      _directoryToken?.cancel('Directory closed');
      _rowIds = [];
    } else if (_active && !_terminal) {
      unawaited(refreshDirectory());
    }
    _queueInterest();
  }

  @override
  void setVisibleRowIds(List<String> ids) {
    final pageIds =
        _page.rows.map((r) => '${r['vehicleId'] ?? r['id']}').toSet();
    final next = ids
        .where((id) => pageIds.contains(id) && (int.tryParse(id) ?? 0) > 0)
        .toSet()
        .take(100)
        .toList(growable: false);
    if (next.length == _rowIds.length &&
        List.generate(next.length, (i) => next[i] == _rowIds[i])
            .every((v) => v)) {
      return;
    }
    _rowIds = next;
    _queueInterest();
    _scheduleMetrics();
  }

  @override
  Future<void> refreshDirectory() => _loadDirectory(cursor: _pageCursor);

  @override
  Future<LiveMapFleetView?> lookupFleetPage(
      {String search = '', String? cursor, CancelToken? cancelToken}) async {
    if (!mounted || !_active || _terminal) return null;
    final generation = _generation, token = cancelToken ?? CancelToken();
    _requests.add(token);
    try {
      final page = await _fleet.directory(
          cancelToken: token,
          search:
              search.trim().substring(0, math.min(120, search.trim().length)),
          cursor: cursor);
      if (!mounted || token.isCancelled || generation != _generation) {
        return null;
      }
      if (_store.isOpen && page.scopeRevision != _store.scopeRevision) {
        _invalidateScope();
        return null;
      }
      return LiveMapFleetView(
          page: page,
          directory: page.rows
              .map(_rowVehicle)
              .whereType<VehicleSummary>()
              .toList(growable: false));
    } catch (error) {
      if (mounted &&
          generation == _generation &&
          !token.isCancelled &&
          _isAccessError(error)) {
        _reset({'retryable': false});
      }
      rethrow;
    } finally {
      _requests.remove(token);
    }
  }

  @override
  Future<void> loadDirectoryPage({bool previous = false}) async {
    if (_loadingDirectory) return;
    final cursor = previous ? _page.previousCursor : _page.nextCursor;
    if (cursor != null) await _loadDirectory(cursor: cursor);
  }

  Future<void> _loadDirectory(
      {String? cursor, bool retryExpired = true}) async {
    if (!mounted || !_active || !_directoryVisible || _terminal) return;
    _directoryToken?.cancel('Directory superseded');
    final token = _directoryToken = CancelToken();
    final generation = ++_directoryGeneration, scopeGeneration = _generation;
    _loadingDirectory = true;
    _directoryError = null;
    _publish();
    try {
      final page = await _fleet.directory(
          cancelToken: token, search: _search, status: _status, cursor: cursor);
      if (!mounted ||
          token.isCancelled ||
          generation != _directoryGeneration ||
          scopeGeneration != _generation) {
        return;
      }
      if (_store.isOpen && page.scopeRevision != _store.scopeRevision) {
        _invalidateScope();
        return;
      }
      _page = page;
      _pageCursor = cursor;
      _lastDirectoryAt = _now();
      _rowIds = [];
      _resetMetrics();
      _queueInterest();
    } catch (error) {
      if (!mounted || token.isCancelled || generation != _directoryGeneration) {
        return;
      }
      if (_isAccessError(error)) {
        _reset({'retryable': false});
        return;
      }
      if (cursor != null && retryExpired && _statusCode(error) == 409) {
        try {
          final first = _page.rows.firstOrNull;
          if (first == null) {
            await _loadDirectory(retryExpired: false);
            return;
          }
          final anchor = await _fleet.get(
              '/map/v2/vehicles/${first['vehicleId'] ?? first['id']}',
              cancelToken: token,
              query: {
                if (_search.isNotEmpty) 'search': _search,
                'status': _status,
                'sort': 'name'
              });
          if (!mounted ||
              token.isCancelled ||
              generation != _directoryGeneration) {
            return;
          }
          final anchorCursor = anchor['anchorCursor'];
          await _loadDirectory(
              cursor: anchorCursor is String ? anchorCursor : null,
              retryExpired: false);
          // Locate anchors use the server's 200-row window. Mobile uses 100
          // rows, so at most one extra page restores the original first row.
          final position = anchor['position'];
          if (mounted &&
              position is int &&
              position >= _page.start + _page.rows.length &&
              _page.nextCursor != null) {
            await _loadDirectory(cursor: _page.nextCursor, retryExpired: false);
          }
          return;
        } catch (recoveryError) {
          if (!mounted || token.isCancelled) return;
          if (_isAccessError(recoveryError)) {
            _reset({'retryable': false});
            return;
          }
          if (_statusCode(recoveryError) == 404) {
            await _loadDirectory(retryExpired: false);
            return;
          }
        }
      }
      _directoryError = 'Unable to load vehicles. Retry.';
    } finally {
      if (mounted && generation == _directoryGeneration) {
        _loadingDirectory = false;
        _publish();
      }
    }
  }

  @override
  Future<VehicleSummary?> selectFleetVehicle(VehicleSummary? vehicle) async {
    _selectionToken?.cancel('Selected vehicle changed');
    final selection = ++_selectionGeneration;
    if (vehicle == null) {
      _selectedRow = null;
      _queueInterest();
      _publish();
      return null;
    }
    final id = int.tryParse(vehicle.id);
    if (id == null || id <= 0 || !_active || _terminal) return null;
    final generation = _generation;
    final token = _selectionToken = CancelToken();
    _requests.add(token);
    try {
      final data = await _fleet.get('/map/v2/vehicles/$id', cancelToken: token);
      if (!mounted ||
          token.isCancelled ||
          generation != _generation ||
          selection != _selectionGeneration) {
        return null;
      }
      final row = data['row'];
      if (row is! Map || '${row['vehicleId'] ?? row['id']}' != vehicle.id) {
        throw const FormatException('Invalid selected vehicle');
      }
      _selectedRow = LiveMapFleetService.normalizeRow(row);
      _queueInterest();
      _scheduleMetrics();
      _publish();
      return _rowVehicle(_selectedRow!);
    } catch (error) {
      if (mounted && generation == _generation && !token.isCancelled) {
        if (_isAccessError(error)) {
          _reset({'retryable': false});
        } else {
          _setError('Unable to load this vehicle. Retry.');
        }
      }
      return null;
    } finally {
      _requests.remove(token);
    }
  }

  @override
  void setAlertsVisible(bool visible) {
    _alertsVisible = visible;
    if (visible && _active && !_terminal) unawaited(_loadAlerts());
  }

  Future<void> _loadAlerts() async {
    if (_loadingAlerts || !_active || !_alertsVisible || _terminal) return;
    _loadingAlerts = true;
    final generation = _generation, token = CancelToken();
    _requests.add(token);
    state = state.copyWith(isAlertsLoading: state.alerts.isEmpty);
    try {
      final page = await _events.getMapEvents(limit: 50, cancelToken: token);
      if (mounted && !token.isCancelled && generation == _generation) {
        _lastAlertsAt = _now();
        state = state.copyWith(alerts: page.items, isAlertsLoading: false);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        state = state.copyWith(isAlertsLoading: false);
      }
    } finally {
      _requests.remove(token);
      _loadingAlerts = false;
    }
  }

  void _scheduleMetrics() {
    if (!_active || _terminal || _metricsTimer?.isActive == true) return;
    _metricsTimer = Timer(
        const Duration(milliseconds: 200), () => unawaited(_loadMetrics()));
  }

  Future<void> _loadMetrics() async {
    if (_metricsToken != null && !_metricsToken!.isCancelled) {
      _metricsPending = true;
      return;
    }
    final now = _now(), start = DateTime(_now().year, _now().month, _now().day);
    final day = _day(now);
    if (_metricsDay != day) {
      _metrics.clear();
      _metricFetchedAt.clear();
      _metricsDay = day;
    }
    final ids = <String>{
      if (_directoryVisible) ..._rowIds,
      if (_selectedRow != null)
        '${_selectedRow!['vehicleId'] ?? _selectedRow!['id']}',
    }
        .where((id) => [..._page.rows, if (_selectedRow != null) _selectedRow!]
            .any((row) =>
                '${row['vehicleId'] ?? row['id']}' == id &&
                row['canViewLive'] == true &&
                row['isLicenseBlocked'] != true &&
                row['service'] is Map &&
                (row['service'] as Map)['liveAllowed'] == true))
        .where((id) =>
            _metricFetchedAt[id] == null ||
            now.difference(_metricFetchedAt[id]!) >=
                const Duration(seconds: 30))
        .take(100)
        .toList(growable: false);
    if (!_active || _terminal || ids.isEmpty) return;
    final token = _metricsToken = CancelToken(), generation = _generation;
    // Cache failed/unknown reads briefly as well, preventing a failing metric
    // endpoint from being retried for each scroll or telemetry publication.
    for (final id in ids) {
      _metricFetchedAt[id] = now;
    }
    _lastMetricsAt = now;
    try {
      final data =
          await _fleet.get('/map/v2/metrics', cancelToken: token, query: {
        'ids': ids.join(','),
        'dayKey': day,
        'dayStart': start.toUtc().toIso8601String(),
      });
      if (!mounted ||
          token.isCancelled ||
          generation != _generation ||
          _day(_now()) != day) {
        return;
      }
      final rows = data['rows'];
      if (rows is! List || rows.length > 100) return;
      for (final row in rows) {
        if (row is Map && ids.contains('${row['vehicleId']}')) {
          _metrics['${row['vehicleId']}'] = Map<String, dynamic>.from(row);
        }
      }
      _metricsDay = day;
      _lastMetricsAt = now;
      _publish();
    } catch (error) {
      if (mounted &&
          !token.isCancelled &&
          generation == _generation &&
          _isAccessError(error)) {
        _reset({'retryable': false});
      }
    } finally {
      if (identical(_metricsToken, token)) {
        _metricsToken = null;
        if (_metricsPending) {
          _metricsPending = false;
          _scheduleMetrics();
        }
      }
    }
  }

  void _resetMetrics() {
    _metricsToken?.cancel('Map metric interests changed');
    _metricsToken = null;
    _metrics.clear();
    _metricFetchedAt.clear();
    _metricsPending = false;
  }

  VehicleSummary? _rowVehicle(Map<String, dynamic> row, {bool scene = false}) {
    final id = '${row['vehicleId'] ?? row['id']}';
    final baseline = row['state'] is Map<String, dynamic>
        ? row['state'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final current = _store.states[id];
    final binding = row['bindingVersion'];
    final bindingChanged = current != null &&
        binding != null &&
        current['bindingVersion'] != binding;
    final live = _store.removedIds.contains(id) || bindingChanged
        ? const <String, dynamic>{}
        : current != null &&
                (binding == null || current['bindingVersion'] == binding)
            ? (baseline['entityRevision'] is int &&
                    baseline['entityRevision'] > current['entityRevision']
                ? baseline
                : current)
            : baseline;
    final now = _now(), day = _day(_now());
    final metric = _metricsDay == day ? _metrics[id] : null;
    final key = '$scene:$id', cached = _vehicleCache['$scene:$id'];
    if (cached != null &&
        identical(row, cached.row) &&
        identical(live, cached.live) &&
        identical(metric, cached.metric) &&
        cached.day == day &&
        (cached.until == null ||
            cached.expired == !cached.until!.isAfter(now))) {
      return cached.vehicle;
    }
    final service = row['service'];
    final until = DateTime.tryParse('${live['serviceLiveUntil'] ?? ''}');
    final blocked = (!scene && row['canViewLive'] != true) ||
        row['isLicenseBlocked'] == true ||
        service is Map && service['liveAllowed'] == false ||
        until != null && !until.isAfter(_now());
    final metricValid = !blocked &&
        metric != null &&
        metric['metricsAvailable'] == true &&
        metric['imei'] == row['imei'] &&
        metric['bindingVersion'] == binding &&
        metric['serviceRevision'] == row['serviceRevision'];
    final telemetry = <String, dynamic>{
      ...live,
      if (metricValid && metric['telemetry'] is Map)
        ...Map<String, dynamic>.from(metric['telemetry']),
    };
    // Current position and explicit nulls always win over HTTP metric samples.
    for (final key in [
      'latitude',
      'longitude',
      'speedKph',
      'course',
      'ignition',
      'serverTime',
      'serverTimeMs',
      'deviceTime',
      'odometer'
    ]) {
      if (live.containsKey(key)) telemetry[key] = live[key];
    }
    final parsed = _vehicles.parseTelemetryVehiclePayload({
      ...row,
      'id': id,
      'vehicleId': id,
      'name': row['vehicleName'] ?? row['name'] ?? '',
      'plateNumber': row['vehicleNumber'] ?? row['plateNumber'] ?? '',
      'state': blocked ? 'inactive' : live['status'] ?? row['status'],
      'telemetry': blocked ? null : telemetry,
      'latitude': blocked ? null : live['latitude'],
      'longitude': blocked ? null : live['longitude'],
      'serviceBlocked': blocked,
    });
    if (parsed == null) return null;
    final vehicle = parsed.copyWith(
      hasValidLocation: !blocked &&
          LiveMapSceneStore.validPosition(
              live['latitude'], live['longitude']) &&
          !(live['latitude'] == 0 && live['longitude'] == 0),
      // Today distances require an explicit current-day baseline.
      distanceKm: metricValid
          ? parsed
              .withTodayDistanceFrom(parsed,
                  now: _now(), authoritativeBaseline: true)
              .distanceKm
          : null,
    );
    _vehicleCache[key] = _FleetVehicleCache(row, live, metric, day, until,
        until != null && !until.isAfter(now), vehicle);
    return vehicle;
  }

  void _schedulePublish() {
    if (!mounted || !_active || _publishTimer?.isActive == true) return;
    _publishTimer = Timer(const Duration(milliseconds: 120), _publish);
  }

  void _publish() {
    if (!mounted) return;
    _publishTimer?.cancel();
    _store.prune(
        _page.rows.map((r) => '${r['vehicleId'] ?? r['id']}'),
        _selectedRow == null
            ? null
            : '${_selectedRow!['vehicleId'] ?? _selectedRow!['id']}');
    final vehicles = <String, VehicleSummary>{};
    final clusters = <Map<String, dynamic>>[];
    for (final item in _store.items.values) {
      if (item['kind'] == 'cluster') {
        clusters.add(item);
        continue;
      }
      final vehicle = _rowVehicle(item, scene: true);
      if (vehicle != null) vehicles[vehicle.id] = vehicle;
    }
    if (_selectedRow != null) {
      final selected = _rowVehicle(_selectedRow!);
      if (selected != null) vehicles[selected.id] = selected;
    }
    final directory = <VehicleSummary>[];
    for (final row in _page.rows) {
      final vehicle = _rowVehicle(row);
      if (vehicle != null) directory.add(vehicle);
    }
    final sceneIds = _store.items.values
        .where((r) => r['kind'] == 'vehicle')
        .map((r) => 'true:${r['vehicleId']}')
        .toSet();
    final directoryIds =
        _page.rows.map((r) => '${r['vehicleId'] ?? r['id']}').toSet();
    if (_selectedRow != null) {
      directoryIds.add('${_selectedRow!['vehicleId'] ?? _selectedRow!['id']}');
    }
    final retainedKeys = {
      ...sceneIds,
      ...directoryIds.map((id) => 'false:$id')
    };
    _vehicleCache.removeWhere((key, _) => !retainedKeys.contains(key));
    _metrics.removeWhere((id, _) => !directoryIds.contains(id));
    _metricFetchedAt.removeWhere((id, _) => !directoryIds.contains(id));
    final summary = _store.summary,
        counts = summary['counts'] is Map ? summary['counts'] as Map : const {};
    int count(String key) => counts[key] is int ? counts[key] as int : 0;
    state = state.copyWith(
      telemetry: LiveMapTelemetry(
          allCount: count('all'),
          runningCount: count('running'),
          stopCount: count('stop'),
          inactiveCount: count('inactive'),
          vehicles: vehicles.values.toList(growable: false)),
      isInitialLoading: !_store.isOpen && state.isInitialLoading,
      isTelemetryConnected: _active &&
          !_store.needsReconcile &&
          _store.sceneRevision > 0 &&
          summary['stale'] != true,
      errorMessage: _store.sceneRevision > 0 && summary['stale'] != true
          ? null
          : state.errorMessage,
      fleet: LiveMapFleetView(
          directory: directory,
          page: _page,
          clusters: clusters,
          bounds: LiveMapSceneStore.validBounds(summary['bounds'])
              ? (summary['bounds'] as List)
                  .map((v) => (v as num).toDouble())
                  .toList(growable: false)
              : null,
          directoryLoading: _loadingDirectory,
          directoryError: _directoryError),
    );
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (!_active) return;
    final now = _now();
    DateTime? next;
    for (final cached in _vehicleCache.values) {
      final until = cached.until;
      if (until != null &&
          until.isAfter(now) &&
          (next == null || until.isBefore(next))) {
        next = until;
      }
    }
    if (next != null) _expiryTimer = Timer(next.difference(now), _publish);
  }

  void _audit() {
    if (!mounted || !_active || _terminal) return;
    final now = _now();
    if (_lastMessageAt != null &&
        now.difference(_lastMessageAt!) > const Duration(seconds: 12)) {
      _clearLive();
      _setError('Waiting for current map state. Retry.');
      _scheduleRetry();
    } else {
      _publish();
      _reconcile(scene: _store.needsReconcile);
    }
    if (_directoryVisible &&
        !_loadingDirectory &&
        (_lastDirectoryAt == null ||
            now.difference(_lastDirectoryAt!) >= const Duration(seconds: 30))) {
      unawaited(refreshDirectory());
    }
    if (_alertsVisible &&
        (_lastAlertsAt == null ||
            now.difference(_lastAlertsAt!) >= const Duration(seconds: 15))) {
      unawaited(_loadAlerts());
    }
    if (_metricsDay != _day(now)) {
      _resetMetrics();
      _scheduleMetrics();
    } else if (_lastMetricsAt == null ||
        now.difference(_lastMetricsAt!) >= const Duration(seconds: 30)) {
      _scheduleMetrics();
    }
  }

  void _setError(String message) {
    if (mounted) {
      state = state.copyWith(
          errorMessage: message,
          isInitialLoading: false,
          isTelemetryConnected: false);
    }
  }

  void _clearLive({bool clearDirectory = false}) {
    _store.clear();
    _resetMetrics();
    _vehicleCache.clear();
    _lastMessageAt = null;
    _selectedRow = null;
    _selectionGeneration++;
    if (clearDirectory) _pageCursor = null;
    // HTTP state is also live data; never retain coordinates after a reset.
    _page = clearDirectory
        ? const LiveMapFleetPage()
        : LiveMapFleetPage(
            rows: _page.rows
                .map((row) => {
                      ...row,
                      'state': null,
                      'latitude': null,
                      'longitude': null
                    })
                .toList(growable: false),
            total: _page.total,
            start: _page.start,
            nextCursor: _page.nextCursor,
            previousCursor: _page.previousCursor,
            queryRevision: _page.queryRevision,
            scopeRevision: _page.scopeRevision);
    _publish();
  }

  void _stopConnection() {
    _generation++;
    _connecting = false;
    for (final timer in [
      _interestTimer,
      _publishTimer,
      _retryTimer,
      _handshakeTimer,
      _metricsTimer,
      _expiryTimer
    ]) {
      timer?.cancel();
    }
    final connection = _connection;
    _connection = null;
    connection?.disconnect();
  }

  void _cancelRequests() {
    for (final token in _requests.toList(growable: false)) {
      token.cancel('Map is inactive');
    }
    _requests.clear();
    _directoryToken?.cancel('Map is inactive');
    _metricsToken?.cancel('Map is inactive');
    _metricsToken = null;
    _directoryGeneration++;
    _loadingDirectory = false;
  }

  static int? _statusCode(Object error) => error is DioException
      ? error.response?.statusCode
      : error is ApiException
          ? error.statusCode
          : null;
  static bool _isAccessError(Object error) =>
      [401, 403].contains(_statusCode(error));
  static String _day(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _auditTimer?.cancel();
    _stopConnection();
    _cancelRequests();
    _store.clear();
    _metrics.clear();
    _metricFetchedAt.clear();
    _vehicleCache.clear();
    _page = const LiveMapFleetPage();
    _selectedRow = null;
    super.dispose();
  }
}

class _FleetVehicleCache {
  const _FleetVehicleCache(this.row, this.live, this.metric, this.day,
      this.until, this.expired, this.vehicle);
  final Map<String, dynamic> row, live;
  final Map<String, dynamic>? metric;
  final String day;
  final DateTime? until;
  final bool expired;
  final VehicleSummary vehicle;
}
