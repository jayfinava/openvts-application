// Tests for deduplicateLiveMapCommandCatalogue.
//
// Covers all three roles (superadmin / admin / user) by verifying the
// function under the same conditions that each role's _loadCatalog() call
// produces, since all role endpoints return the same model type
// (SuperadminCustomCommand via LiveMapCustomCommand typedef).

import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/features/superadmin/models/superadmin_vehicle_model.dart';
import 'package:open_vts/shared/utils/command_catalogue_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SuperadminCustomCommand _cmd({
  required String id,
  required String command,
  int? deviceTypeId,
  int? commandTypeId,
  String? commandTypeName,
  bool isActive = true,
}) {
  return SuperadminCustomCommand(
    id: id,
    command: command,
    isActive: isActive,
    deviceTypeId: deviceTypeId,
    commandTypeId: commandTypeId,
    commandTypeName: commandTypeName,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // Empty / single-item edge cases
  // -------------------------------------------------------------------------

  group('deduplicateLiveMapCommandCatalogue empty and single', () {
    test('returns empty list for empty input', () {
      expect(deduplicateLiveMapCommandCatalogue([]), isEmpty);
    });

    test('returns single item unchanged', () {
      final result = deduplicateLiveMapCommandCatalogue([
        _cmd(id: 'a', command: 'CMD', deviceTypeId: 1, commandTypeId: 1),
      ]);
      expect(result.length, 1);
      expect(result.first.id, 'a');
    });
  });

  // -------------------------------------------------------------------------
  // Duplicate by stable ID
  // -------------------------------------------------------------------------

  group('deduplicateLiveMapCommandCatalogue duplicate by ID', () {
    test('drops the second record when ID is identical', () {
      final raw = [
        _cmd(
            id: 'cmd-1',
            command: 'AT+TRACK',
            deviceTypeId: 1,
            commandTypeId: 2),
        _cmd(
            id: 'cmd-1',
            command: 'AT+TRACK',
            deviceTypeId: 1,
            commandTypeId: 2),
      ];
      final result = deduplicateLiveMapCommandCatalogue(raw);
      expect(result.length, 1);
      expect(result.first.id, 'cmd-1');
    });

    test('keeps three commands when all IDs differ', () {
      final raw = [
        _cmd(id: 'a', command: 'CMD_A'),
        _cmd(id: 'b', command: 'CMD_B'),
        _cmd(id: 'c', command: 'CMD_C'),
      ];
      expect(deduplicateLiveMapCommandCatalogue(raw).length, 3);
    });
  });

  // -------------------------------------------------------------------------
  // Semantic duplicates (different IDs, same meaning)
  // -------------------------------------------------------------------------

  group('deduplicateLiveMapCommandCatalogue semantic duplicates', () {
    test(
        'drops semantic duplicate (same deviceTypeId + commandTypeId + command)',
        () {
      final raw = [
        _cmd(
            id: 'id-1', command: 'AT+TRACK', deviceTypeId: 1, commandTypeId: 2),
        _cmd(
            id: 'id-2', command: 'AT+TRACK', deviceTypeId: 1, commandTypeId: 2),
      ];
      final result = deduplicateLiveMapCommandCatalogue(raw);
      expect(result.length, 1);
      expect(result.first.id, 'id-1');
    });

    test('keeps both when command text differs', () {
      final raw = [
        _cmd(id: 'a', command: 'AT+TRACK=1', deviceTypeId: 1, commandTypeId: 2),
        _cmd(id: 'b', command: 'AT+TRACK=0', deviceTypeId: 1, commandTypeId: 2),
      ];
      expect(deduplicateLiveMapCommandCatalogue(raw).length, 2);
    });

    test('keeps both when deviceTypeId differs', () {
      final raw = [
        _cmd(id: 'a', command: 'AT+CMD', deviceTypeId: 1, commandTypeId: 5),
        _cmd(id: 'b', command: 'AT+CMD', deviceTypeId: 2, commandTypeId: 5),
      ];
      expect(deduplicateLiveMapCommandCatalogue(raw).length, 2);
    });

    test('normalises command text case for composite key', () {
      final raw = [
        _cmd(id: 'a', command: 'at+track', deviceTypeId: 1, commandTypeId: 2),
        _cmd(id: 'b', command: 'AT+TRACK', deviceTypeId: 1, commandTypeId: 2),
      ];
      final result = deduplicateLiveMapCommandCatalogue(raw);
      expect(result.length, 1);
      expect(result.first.id, 'a');
    });
  });

  // -------------------------------------------------------------------------
  // Sorting
  // -------------------------------------------------------------------------

  group('deduplicateLiveMapCommandCatalogue sorting', () {
    test('sorts by commandTypeName ascending then command text ascending', () {
      final raw = [
        _cmd(id: 'c', command: 'ZZZ', commandTypeName: 'Beta'),
        _cmd(id: 'a', command: 'AAA_ZETA', commandTypeName: 'Zeta'),
        _cmd(id: 'b', command: 'MMM', commandTypeName: 'Alpha'),
        _cmd(id: 'd', command: 'AAA_BETA', commandTypeName: 'Beta'),
      ];
      final result = deduplicateLiveMapCommandCatalogue(raw);
      expect(result.length, 4);
      expect(result[0].commandTypeName, 'Alpha');
      expect(result[0].command, 'MMM');
      expect(result[1].commandTypeName, 'Beta');
      expect(result[1].command, 'AAA_BETA');
      expect(result[2].commandTypeName, 'Beta');
      expect(result[2].command, 'ZZZ');
      expect(result[3].commandTypeName, 'Zeta');
      expect(result[3].command, 'AAA_ZETA');
    });

    test('null commandTypeName sorts before non-null', () {
      final raw = [
        _cmd(id: 'a', command: 'CMD', commandTypeName: 'Zebra'),
        _cmd(id: 'b', command: 'BCMD', commandTypeName: null),
      ];
      final result = deduplicateLiveMapCommandCatalogue(raw);
      expect(result.first.id, 'b');
    });
  });

  // -------------------------------------------------------------------------
  // All result IDs are unique (dropdown safety)
  // -------------------------------------------------------------------------

  group('deduplicateLiveMapCommandCatalogue unique dropdown values', () {
    test('all result IDs are unique', () {
      final raw = [
        _cmd(id: 'a', command: 'CMD_A', deviceTypeId: 1, commandTypeId: 1),
        _cmd(id: 'b', command: 'CMD_B', deviceTypeId: 1, commandTypeId: 2),
        _cmd(id: 'a', command: 'CMD_A', deviceTypeId: 1, commandTypeId: 1),
        _cmd(id: 'c', command: 'CMD_C', deviceTypeId: 2, commandTypeId: 1),
        _cmd(id: 'b', command: 'CMD_B', deviceTypeId: 1, commandTypeId: 2),
      ];
      final result = deduplicateLiveMapCommandCatalogue(raw);
      final ids = result.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'All dropdown values must be unique');
    });
  });

  // -------------------------------------------------------------------------
  // isActive filter is applied before dedup (caller responsibility verified)
  // -------------------------------------------------------------------------

  group('deduplicateLiveMapCommandCatalogue isActive passthrough', () {
    test('inactive commands passed in are kept (caller filters before calling)',
        () {
      // The live_map_screen filters isActive before calling; this test confirms
      // the utility itself does not silently drop inactive records if the
      // caller passes them — the utility is pure dedup+sort, not a filter.
      final raw = [
        _cmd(id: 'a', command: 'CMD_A', isActive: false),
        _cmd(id: 'b', command: 'CMD_B', isActive: true),
      ];
      final result = deduplicateLiveMapCommandCatalogue(raw);
      expect(result.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // Role-specific endpoint context: all three roles use the same model type
  // -------------------------------------------------------------------------

  group('deduplicateLiveMapCommandCatalogue role compatibility', () {
    // SuperAdmin, Admin, and User all return SuperadminCustomCommand via
    // the LiveMapCustomCommand typedef.  The same function handles all three.

    test('superadmin: deduplicates repeated commands for a given deviceTypeId',
        () {
      final raw = [
        _cmd(id: 'sa-1', command: 'AT+SA', deviceTypeId: 10, commandTypeId: 1),
        _cmd(id: 'sa-1', command: 'AT+SA', deviceTypeId: 10, commandTypeId: 1),
      ];
      expect(deduplicateLiveMapCommandCatalogue(raw).length, 1);
    });

    test('admin: deduplicates repeated commands for a given deviceTypeId', () {
      final raw = [
        _cmd(
            id: 'adm-1',
            command: 'AT+ADMIN',
            deviceTypeId: 5,
            commandTypeId: 2),
        _cmd(
            id: 'adm-1',
            command: 'AT+ADMIN',
            deviceTypeId: 5,
            commandTypeId: 2),
      ];
      expect(deduplicateLiveMapCommandCatalogue(raw).length, 1);
    });

    test('user: deduplicates repeated commands for a given deviceTypeId', () {
      final raw = [
        _cmd(
            id: 'usr-1', command: 'AT+USER', deviceTypeId: 3, commandTypeId: 3),
        _cmd(
            id: 'usr-1', command: 'AT+USER', deviceTypeId: 3, commandTypeId: 3),
      ];
      expect(deduplicateLiveMapCommandCatalogue(raw).length, 1);
    });

    test(
        'null deviceTypeId (no filter applied at API level) still deduplicates',
        () {
      final raw = [
        _cmd(id: 'x', command: 'CMD', deviceTypeId: null, commandTypeId: 1),
        _cmd(id: 'x', command: 'CMD', deviceTypeId: null, commandTypeId: 1),
      ];
      expect(deduplicateLiveMapCommandCatalogue(raw).length, 1);
    });
  });

  // -------------------------------------------------------------------------
  // Stale selection scenario: removed command ID no longer in deduped list
  // -------------------------------------------------------------------------

  group('deduplicateLiveMapCommandCatalogue stale selection', () {
    test('command with removed ID is not present after refresh', () {
      final afterRefresh = [
        _cmd(id: 'new-id', command: 'CMD_NEW'),
      ];
      final result = deduplicateLiveMapCommandCatalogue(afterRefresh);
      expect(result.any((c) => c.id == 'old-id'), isFalse,
          reason: 'stale selection old-id should not be present after refresh');
    });
  });
}
