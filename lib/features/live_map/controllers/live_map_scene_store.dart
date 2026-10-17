import 'dart:convert';

/// Bounded map-v2 replica. A new scene becomes visible only after every chunk
/// has been validated. Session, scope, interest and entity revisions fence late
/// messages; protocol errors ask the caller for a fresh scene.
class LiveMapSceneStore {
  static const maxItems = 25000;
  static const maxStates = maxItems + 121;
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _stageEnvelope;
  final Map<int, List<Map<String, dynamic>>> _chunks = {};
  int _expectedChunks = 0,
      _expectedCount = 0,
      _stagedCount = 0,
      _stagedBytes = 0;
  Map<String, Map<String, dynamic>> items = {};
  final Map<String, Map<String, dynamic>> states = {};
  final Set<String> removedIds = {};
  final Map<String, Map<String, dynamic>> _pendingStates = {};
  final Set<String> _pendingRemovals = {};
  Map<String, dynamic> summary = {};
  int sceneRevision = 0, sequence = 0, interestRevision = 0;
  bool needsReconcile = false;

  bool get isOpen => _session != null;
  String get scopeRevision => '${_session?['scopeRevision'] ?? ''}';

  void clear() {
    _session = null;
    _clearStage();
    items.clear();
    states.clear();
    removedIds.clear();
    summary = {};
    sceneRevision = 0;
    sequence = 0;
    interestRevision = 0;
    needsReconcile = false;
  }

  bool open(Map<String, dynamic> envelope) {
    clear();
    if (envelope['protocolVersion'] != 2 ||
        envelope['sessionId'] is! String ||
        (envelope['sessionId'] as String).isEmpty ||
        envelope['projectionEpoch'] is! String ||
        envelope['scopeRevision'] == null) {
      return false;
    }
    _session = envelope;
    return true;
  }

  bool accepts(Map<String, dynamic> value) =>
      _session != null &&
      value['protocolVersion'] == 2 &&
      value['sessionId'] == _session!['sessionId'] &&
      value['projectionEpoch'] == _session!['projectionEpoch'] &&
      '${value['scopeRevision']}' == scopeRevision;

  bool _current(Map<String, dynamic> value) =>
      accepts(value) &&
      value['interestRevision'] is int &&
      value['interestRevision'] >= interestRevision;

  bool begin(Map<String, dynamic> value) {
    if (!_current(value) ||
        !_positive(value['sceneRevision']) ||
        value['sceneRevision'] <= sceneRevision) {
      return false;
    }
    final chunks = value['expectedChunks'], count = value['expectedCount'];
    if (!_bounded(chunks, 200) ||
        !_bounded(count, maxItems) ||
        (chunks == 0) != (count == 0)) {
      return _fail();
    }
    _clearStage();
    _stageEnvelope = value;
    _expectedChunks = chunks;
    _expectedCount = count;
    return true;
  }

  bool chunk(Map<String, dynamic> value) {
    if (!_matchesStage(value)) return false;
    final index = value['chunkIndex'], raw = value['items'];
    if (!_bounded(index, _expectedChunks - 1) ||
        raw is! List ||
        raw.length > 256) {
      return _fail();
    }
    if (_chunks.containsKey(index)) return true;
    final parsed = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map || !_validItem(Map<String, dynamic>.from(item))) {
        return _fail();
      }
      parsed.add(Map<String, dynamic>.from(item));
    }
    final bytes = utf8.encode(jsonEncode(parsed)).length;
    _stagedBytes += bytes;
    if (bytes > 128 * 1024 ||
        _stagedBytes > 32 * 1024 * 1024 ||
        _stagedCount + parsed.length > _expectedCount) {
      return _fail();
    }
    _chunks[index] = parsed;
    _stagedCount += parsed.length;
    return true;
  }

  bool finish(Map<String, dynamic> value) {
    if (!_matchesStage(value)) return false;
    if (_chunks.length != _expectedChunks ||
        _stagedCount != _expectedCount ||
        value['expectedCount'] != _expectedCount) {
      return _fail();
    }
    final next = <String, Map<String, dynamic>>{};
    for (var i = 0; i < _expectedChunks; i++) {
      for (final item in _chunks[i]!) {
        final id = item['id'] as String;
        if (next.containsKey(id)) return _fail();
        next[id] = item;
      }
    }
    items = next;
    for (final item in next.values) {
      if (item['kind'] == 'vehicle') _applyState(item);
    }
    for (final state in _pendingStates.values) {
      _applyState(state);
    }
    for (final id in _pendingRemovals) {
      states.remove(id);
      removedIds.add(id);
    }
    sceneRevision = value['sceneRevision'];
    _clearStage();
    needsReconcile = false;
    return true;
  }

  bool delta(Map<String, dynamic> value) {
    if (!_current(value)) return false;
    if (_stageEnvelope != null ||
        sceneRevision == 0 ||
        value['baseSceneRevision'] != sceneRevision ||
        !_positive(value['sceneRevision']) ||
        value['sceneRevision'] <= sceneRevision) {
      return _fail();
    }
    final remove = value['removeIds'], upserts = value['upserts'];
    if (remove is! List ||
        upserts is! List ||
        remove.length > maxItems ||
        upserts.length > maxItems) {
      return _fail();
    }
    final next = Map<String, Map<String, dynamic>>.of(items);
    for (final id in remove) {
      if (id is! String) return _fail();
      next.remove(id);
    }
    for (final raw in upserts) {
      if (raw is! Map) return _fail();
      final item = Map<String, dynamic>.from(raw);
      if (!_validItem(item)) return _fail();
      next[item['id']] = item;
    }
    if (next.length > maxItems) return _fail();
    items = next;
    for (final raw in upserts) {
      if (raw['kind'] == 'vehicle') _applyState(Map<String, dynamic>.from(raw));
    }
    sceneRevision = value['sceneRevision'];
    return true;
  }

  bool receiveStates(Map<String, dynamic> value) {
    if (!accepts(value) || value['interestRevision'] is! int) return false;
    final seq = value['sequence'],
        raw = value['states'],
        remove = value['removeIds'];
    if (!_positive(seq) ||
        raw is! List ||
        remove is! List ||
        raw.length + remove.length > 256) {
      return _fail();
    }
    if (seq <= sequence) return true;
    final gap = sequence > 0 && seq != sequence + 1;
    for (final state in raw) {
      if (state is! Map || !_validState(Map<String, dynamic>.from(state))) {
        return _fail();
      }
    }
    if (remove.any((id) => !_positive(id))) return _fail();
    // Sequence is per session, not per viewport. An old-interest batch must
    // still release server credit without reintroducing offscreen state.
    if (value['interestRevision'] < interestRevision) {
      sequence = seq;
      return true;
    }
    for (final rawState in raw) {
      final state = Map<String, dynamic>.from(rawState as Map);
      _applyState(state);
      if (_stageEnvelope != null) {
        _pendingStates['${state['vehicleId']}'] = state;
        _pendingRemovals.remove('${state['vehicleId']}');
      }
    }
    for (final id in remove) {
      states.remove('$id');
      removedIds.add('$id');
      if (_stageEnvelope != null) {
        _pendingRemovals.add('$id');
        _pendingStates.remove('$id');
      }
    }
    if (states.length > maxStates ||
        _pendingStates.length + _pendingRemovals.length > maxStates) {
      return _fail();
    }
    sequence = seq;
    needsReconcile = needsReconcile || gap;
    return true;
  }

  bool receiveSummary(Map<String, dynamic> value) {
    if (!_current(value)) return false;
    final counts = value['counts'];
    if (counts is! Map ||
        ['all', 'running', 'stop', 'inactive']
            .any((key) => !_bounded(counts[key], 1000000))) {
      return _fail();
    }
    summary = value;
    return true;
  }

  void prune(Iterable<String> directoryIds, String? selectedId) {
    final retained = <String>{
      ...directoryIds,
      if (selectedId != null) selectedId,
      for (final item in items.values)
        if (item['kind'] == 'vehicle') '${item['vehicleId']}',
    };
    states.removeWhere((key, _) => !retained.contains(key));
    removedIds.removeWhere((key) => !retained.contains(key));
  }

  void cancelScene(Map<String, dynamic> value) {
    if (_matchesStage(value)) _clearStage();
  }

  bool _matchesStage(Map<String, dynamic> value) =>
      _stageEnvelope != null &&
      _current(value) &&
      value['sceneRevision'] == _stageEnvelope!['sceneRevision'] &&
      value['interestRevision'] == _stageEnvelope!['interestRevision'];
  bool _fail() {
    _clearStage();
    needsReconcile = true;
    return false;
  }

  void _clearStage() {
    _stageEnvelope = null;
    _chunks.clear();
    _pendingStates.clear();
    _pendingRemovals.clear();
    _stagedCount = 0;
    _stagedBytes = 0;
  }

  void _applyState(Map<String, dynamic> state) {
    final id = '${state['vehicleId']}';
    final previous = states[id];
    if (previous != null) {
      final a = '${state['sourceRevision']}',
          b = '${previous['sourceRevision']}';
      final numericA = BigInt.tryParse(a), numericB = BigInt.tryParse(b);
      final sourceOrder = numericA != null && numericB != null
          ? numericA.compareTo(numericB)
          : 0;
      if (sourceOrder < 0) return;
      if (sourceOrder == 0 &&
          state['bindingVersion'] == previous['bindingVersion'] &&
          state['entityRevision'] <= previous['entityRevision']) {
        return;
      }
      if (state['bindingVersion'] != previous['bindingVersion'] &&
          sourceOrder <= 0 &&
          (state['serverTimeMs'] ?? -1) < (previous['serverTimeMs'] ?? -1)) {
        return;
      }
    }
    states[id] = state;
    removedIds.remove(id);
  }

  static bool _validItem(Map<String, dynamic> item) {
    if (item['id'] is! String) return false;
    if (item['kind'] == 'vehicle') {
      return item['id'] == 'v:${item['vehicleId']}' && _validState(item);
    }
    return item['kind'] == 'cluster' &&
        _bounded(item['clusterId'], 9007199254740991) &&
        item['id'] == 'c:${item['clusterId']}' &&
        _positive(item['count']) &&
        validPosition(item['latitude'], item['longitude']) &&
        validBounds(item['bounds']);
  }

  static bool _validState(Map<String, dynamic> state) =>
      _positive(state['vehicleId']) &&
      _bounded(state['bindingVersion'], 9007199254740991) &&
      _bounded(state['entityRevision'], 9007199254740991) &&
      (state['sourceRevision'] is String || state['sourceRevision'] is num) &&
      ['running', 'stop', 'inactive'].contains(state['status']) &&
      ((state['latitude'] == null && state['longitude'] == null) ||
          validPosition(state['latitude'], state['longitude'])) &&
      (state['serverTimeMs'] == null ||
          state['serverTimeMs'] is num &&
              (state['serverTimeMs'] as num).isFinite);
  static bool validState(dynamic value) =>
      value is Map && _validState(Map<String, dynamic>.from(value));
  static bool _positive(dynamic value) =>
      value is int && value > 0 && value <= 9007199254740991;
  static bool _bounded(dynamic value, int max) =>
      value is int && value >= 0 && value <= max;
  static bool validPosition(dynamic lat, dynamic lng) =>
      lat is num &&
      lng is num &&
      lat.isFinite &&
      lng.isFinite &&
      lat.abs() <= 90 &&
      lng.abs() <= 180;
  static bool validBounds(dynamic value) =>
      value is List &&
      value.length == 4 &&
      value.every((v) => v is num && v.isFinite) &&
      value[1] <= value[3] &&
      value[0].abs() <= 180 &&
      value[2].abs() <= 180 &&
      value[1].abs() <= 90 &&
      value[3].abs() <= 90;
}
