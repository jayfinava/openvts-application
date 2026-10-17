import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/features/live_map/controllers/live_map_scene_store.dart';

import 'fleet_wire_fixture.dart';

void main() {
  late LiveMapSceneStore store;
  setUp(() {
    store = LiveMapSceneStore()..open(fleetEnvelope());
  });

  void install(List<Map<String, dynamic>> items, {int scene = 1}) {
    final envelope = fleetEnvelope(scene: scene);
    final chunks = (items.length / 256).ceil();
    expect(
        store.begin({
          ...envelope,
          'expectedChunks': chunks,
          'expectedCount': items.length
        }),
        isTrue);
    for (var i = 0; i < chunks; i++) {
      expect(
          store.chunk({
            ...envelope,
            'chunkIndex': i,
            'items': items.skip(i * 256).take(256).toList()
          }),
          isTrue);
    }
    expect(store.finish({...envelope, 'expectedCount': items.length}), isTrue);
  }

  test('incomplete scenes never replace the installed scene', () {
    install([fleetWireVehicle(1)]);
    final envelope = fleetEnvelope(scene: 2);
    expect(store.begin({...envelope, 'expectedChunks': 2, 'expectedCount': 2}),
        isTrue);
    expect(
        store.chunk({
          ...envelope,
          'chunkIndex': 0,
          'items': [fleetWireVehicle(2)]
        }),
        isTrue);
    expect(store.items.keys, ['v:1']);
    expect(store.finish({...envelope, 'expectedCount': 2}), isFalse);
    expect(store.items.keys, ['v:1']);
    expect(store.needsReconcile, isTrue);
  });

  test('out-of-order chunks and repeated acknowledgements remain atomic', () {
    expect(
        store.begin(
            {...fleetEnvelope(), 'expectedChunks': 2, 'expectedCount': 2}),
        isTrue);
    final chunk = {
      ...fleetEnvelope(),
      'chunkIndex': 1,
      'items': [fleetWireVehicle(2)]
    };
    expect(store.chunk(chunk), isTrue);
    expect(store.chunk(chunk), isTrue);
    expect(
        store.chunk({
          ...fleetEnvelope(),
          'chunkIndex': 0,
          'items': [fleetWireVehicle(1)]
        }),
        isTrue);
    expect(store.items, isEmpty);
    expect(store.finish({...fleetEnvelope(), 'expectedCount': 2}), isTrue);
    expect(store.items.keys, ['v:1', 'v:2']);
  });

  test(
      'duplicate identities, oversized chunks and nonfinite positions are rejected',
      () {
    expect(
        store.begin(
            {...fleetEnvelope(), 'expectedChunks': 1, 'expectedCount': 2}),
        isTrue);
    expect(
        store.chunk({
          ...fleetEnvelope(),
          'chunkIndex': 0,
          'items': [fleetWireVehicle(1), fleetWireVehicle(1)]
        }),
        isTrue);
    expect(store.finish({...fleetEnvelope(), 'expectedCount': 2}), isFalse);
    expect(
        store.begin(
            {...fleetEnvelope(), 'expectedChunks': 201, 'expectedCount': 1}),
        isFalse);
    expect(
        store.begin(
            {...fleetEnvelope(), 'expectedChunks': 1, 'expectedCount': 1}),
        isTrue);
    expect(
        store.chunk({
          ...fleetEnvelope(),
          'chunkIndex': 0,
          'items': [fleetWireVehicle(1)..['latitude'] = double.nan]
        }),
        isFalse);
  });

  test(
      'late sessions, scope generations and old interests cannot replace scenes',
      () {
    store.interestRevision = 2;
    expect(
        store.begin(
            {...fleetEnvelope(), 'expectedChunks': 0, 'expectedCount': 0}),
        isFalse);
    for (final key in ['sessionId', 'scopeRevision', 'projectionEpoch']) {
      expect(
          store.begin({
            ...fleetEnvelope(interest: 2),
            key: 'old',
            'expectedChunks': 0,
            'expectedCount': 0
          }),
          isFalse);
    }
  });

  test(
      'old-interest states release session sequence credit without applying positions',
      () {
    install([fleetWireVehicle(1)]);
    store.interestRevision = 2;
    expect(
        store.receiveStates({
          ...fleetEnvelope(),
          'sequence': 1,
          'states': [fleetWireVehicle(1, revision: 2)],
          'removeIds': []
        }),
        isTrue);
    expect(store.sequence, 1);
    expect(store.states['1']!['entityRevision'], 1);
    expect(
        store.receiveStates({
          ...fleetEnvelope(interest: 2),
          'sequence': 2,
          'states': [fleetWireVehicle(1, revision: 3)],
          'removeIds': []
        }),
        isTrue);
    expect(store.states['1']!['entityRevision'], 3);
    expect(store.needsReconcile, isFalse);
  });

  test('sequence gaps request reconciliation and can recover', () {
    install([fleetWireVehicle(1)]);
    for (final sequence in [1, 3, 4]) {
      expect(
          store.receiveStates({
            ...fleetEnvelope(),
            'sequence': sequence,
            'states': [fleetWireVehicle(1, revision: sequence + 1)],
            'removeIds': []
          }),
          isTrue);
    }
    expect(store.needsReconcile, isTrue);
    install([fleetWireVehicle(1, revision: 5)], scene: 2);
    expect(store.needsReconcile, isFalse);
  });

  test('newer states arriving during scene transfer survive installation', () {
    expect(
        store.begin(
            {...fleetEnvelope(), 'expectedChunks': 1, 'expectedCount': 1}),
        isTrue);
    expect(
        store.receiveStates({
          ...fleetEnvelope(),
          'sequence': 1,
          'states': [fleetWireVehicle(1, revision: 4)],
          'removeIds': []
        }),
        isTrue);
    expect(
        store.chunk({
          ...fleetEnvelope(),
          'chunkIndex': 0,
          'items': [fleetWireVehicle(1)]
        }),
        isTrue);
    expect(store.finish({...fleetEnvelope(), 'expectedCount': 1}), isTrue);
    expect(store.states['1']!['entityRevision'], 4);
  });

  test('explicit null positions and removals clear locations', () {
    install([fleetWireVehicle(1)]);
    expect(
        store.receiveStates({
          ...fleetEnvelope(),
          'sequence': 1,
          'states': [
            fleetWireVehicle(1, revision: 2)
              ..['latitude'] = null
              ..['longitude'] = null
          ],
          'removeIds': []
        }),
        isTrue);
    expect(store.states['1']!['latitude'], isNull);
    expect(
        store.receiveStates({
          ...fleetEnvelope(),
          'sequence': 2,
          'states': [],
          'removeIds': [1]
        }),
        isTrue);
    expect(store.states, isEmpty);
    expect(store.removedIds, {'1'});
  });

  test('state revisions and binding versions cannot regress', () {
    install([fleetWireVehicle(1, revision: 10)]);
    expect(
        store.receiveStates({
          ...fleetEnvelope(),
          'sequence': 1,
          'states': [fleetWireVehicle(1, revision: 9)],
          'removeIds': []
        }),
        isTrue);
    expect(store.states['1']!['sourceRevision'], '10');
  });

  test('delta requires an installed matching base', () {
    install([fleetWireVehicle(1)]);
    expect(
        store.delta({
          ...fleetEnvelope(scene: 2),
          'baseSceneRevision': 0,
          'removeIds': [],
          'upserts': []
        }),
        isFalse);
    expect(
        store.delta({
          ...fleetEnvelope(scene: 2),
          'baseSceneRevision': 1,
          'removeIds': ['v:1'],
          'upserts': [fleetWireVehicle(2)]
        }),
        isTrue);
    expect(store.items.keys, ['v:2']);
  });

  test('10000 entities can be replaced repeatedly without retaining old state',
      () {
    for (var scene = 1; scene <= 4; scene++) {
      install(
          List.generate(10000, (i) => fleetWireVehicle(scene * 10000 + i + 1)),
          scene: scene);
      store.prune([], null);
      expect(store.items.length, 10000);
      expect(store.states.length, 10000);
    }
    store.clear();
    expect(store.items, isEmpty);
    expect(store.states, isEmpty);
    expect(store.isOpen, isFalse);
  });
}
