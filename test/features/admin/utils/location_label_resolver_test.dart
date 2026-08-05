import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/features/admin/models/admin_users_model.dart';
import 'package:open_vts/features/admin/utils/location_label_resolver.dart';

void main() {
  // -------------------------------------------------------------------------
  // resolveCountry
  // -------------------------------------------------------------------------

  group('LocationLabelResolver.resolveCountry', () {
    test('resolves IN to India from hardcoded data (no API options)', () {
      expect(LocationLabelResolver.resolveCountry('IN'), 'India');
    });

    test('resolves NG to Nigeria from hardcoded data (no API options)', () {
      expect(LocationLabelResolver.resolveCountry('NG'), 'Nigeria');
    });

    test('API options take priority over hardcoded data', () {
      final apiOptions = [
        const AdminUserCountryOption(value: 'IN', label: 'Bharat'),
      ];
      expect(
        LocationLabelResolver.resolveCountry('IN', apiOptions: apiOptions),
        'Bharat',
      );
    });

    test('falls back to hardcoded data when code not in API options', () {
      final apiOptions = [
        const AdminUserCountryOption(value: 'NG', label: 'Nigeria (API)'),
      ];
      // IN is not in apiOptions → should hit the hardcoded fallback.
      expect(
        LocationLabelResolver.resolveCountry('IN', apiOptions: apiOptions),
        'India',
      );
    });

    test('unknown code returns the code itself without crashing', () {
      expect(LocationLabelResolver.resolveCountry('ZZ'), 'ZZ');
    });

    test('empty code returns empty string', () {
      expect(LocationLabelResolver.resolveCountry(''), '');
    });

    test('matching is case-insensitive for code', () {
      expect(LocationLabelResolver.resolveCountry('in'), 'India');
      expect(LocationLabelResolver.resolveCountry('ng'), 'Nigeria');
    });
  });

  // -------------------------------------------------------------------------
  // resolveState
  // -------------------------------------------------------------------------

  group('LocationLabelResolver.resolveState', () {
    test('resolves NG/LA to Lagos from hardcoded data', () {
      expect(LocationLabelResolver.resolveState('NG', 'LA'), 'Lagos');
    });

    test('resolves IN/MH to Maharashtra from hardcoded data', () {
      expect(LocationLabelResolver.resolveState('IN', 'MH'), 'Maharashtra');
    });

    test('API state options take priority over hardcoded data', () {
      final apiOptions = [
        const AdminUserStateOption(value: 'LA', label: 'Lagos (API)'),
      ];
      expect(
        LocationLabelResolver.resolveState('NG', 'LA', apiOptions: apiOptions),
        'Lagos (API)',
      );
    });

    test('unknown state code returns the code itself without crashing', () {
      expect(LocationLabelResolver.resolveState('NG', 'ZZ'), 'ZZ');
    });

    test('empty state code returns empty string', () {
      expect(LocationLabelResolver.resolveState('NG', ''), '');
    });
  });

  // -------------------------------------------------------------------------
  // resolvedCountryOptions — filter menu builds with readable labels
  // -------------------------------------------------------------------------

  group('LocationLabelResolver.resolvedCountryOptions', () {
    test('builds options with readable labels from hardcoded data', () {
      final options =
          LocationLabelResolver.resolvedCountryOptions(['IN', 'NG']);
      final inOption = options.firstWhere((o) => o.value == 'IN');
      final ngOption = options.firstWhere((o) => o.value == 'NG');

      expect(inOption.label, 'India');
      expect(ngOption.label, 'Nigeria');
    });

    test('canonical code is preserved as the value', () {
      final options =
          LocationLabelResolver.resolvedCountryOptions(['IN', 'NG']);
      final values = options.map((o) => o.value).toList();
      expect(values, containsAll(['IN', 'NG']));
    });

    test('API options are used when provided', () {
      final apiOptions = [
        const AdminUserCountryOption(value: 'IN', label: 'India (API)'),
      ];
      final options = LocationLabelResolver.resolvedCountryOptions(
        ['IN'],
        apiOptions: apiOptions,
      );
      expect(options.first.label, 'India (API)');
      expect(options.first.value, 'IN');
    });

    test('deduplicates repeated codes', () {
      final options = LocationLabelResolver.resolvedCountryOptions(
        ['IN', 'IN', 'NG', 'NG'],
      );
      expect(options.where((o) => o.value == 'IN').length, 1);
      expect(options.where((o) => o.value == 'NG').length, 1);
    });

    test('unknown code appears with code as both value and label', () {
      final options = LocationLabelResolver.resolvedCountryOptions(['ZZ']);
      expect(options.first.value, 'ZZ');
      expect(options.first.label, 'ZZ');
    });

    test('result is sorted alphabetically by label', () {
      final options =
          LocationLabelResolver.resolvedCountryOptions(['NG', 'IN']);
      // India comes before Nigeria alphabetically.
      expect(options.first.label, 'India');
      expect(options.last.label, 'Nigeria');
    });
  });

  // -------------------------------------------------------------------------
  // Profile-level resolution helpers (inline logic mirrored from widget)
  // -------------------------------------------------------------------------

  group('profile countryName/stateName priority', () {
    test('non-empty countryName is preferred over code resolution', () {
      const countryName = 'India';
      const countryCode = 'IN';
      // Simulate the widget logic: prefer name, fall back to resolution.
      final label = countryName.trim().isNotEmpty
          ? countryName
          : LocationLabelResolver.resolveCountry(countryCode);
      expect(label, 'India');
    });

    test('empty countryName falls back to resolved code', () {
      const countryName = '';
      const countryCode = 'NG';
      final label = countryName.trim().isNotEmpty
          ? countryName
          : LocationLabelResolver.resolveCountry(countryCode);
      expect(label, 'Nigeria');
    });

    test('non-empty stateName is preferred over code resolution', () {
      const stateName = 'Lagos State';
      const countryCode = 'NG';
      const stateCode = 'LA';
      final label = stateName.trim().isNotEmpty
          ? stateName
          : LocationLabelResolver.resolveState(countryCode, stateCode);
      expect(label, 'Lagos State');
    });

    test('empty stateName falls back to resolved code', () {
      const stateName = '';
      const countryCode = 'NG';
      const stateCode = 'LA';
      final label = stateName.trim().isNotEmpty
          ? stateName
          : LocationLabelResolver.resolveState(countryCode, stateCode);
      expect(label, 'Lagos');
    });
  });

  // -------------------------------------------------------------------------
  // No per-card network request: resolver is pure / stateless
  // -------------------------------------------------------------------------

  group('resolver is pure (no network calls)', () {
    test('resolveCountry is a synchronous pure function', () {
      // If this were async / made network calls it would not complete
      // synchronously. Confirming it returns a plain String.
      final result = LocationLabelResolver.resolveCountry('IN');
      expect(result, isA<String>());
      expect(result, 'India');
    });

    test('resolveState is a synchronous pure function', () {
      final result = LocationLabelResolver.resolveState('NG', 'LA');
      expect(result, isA<String>());
      expect(result, 'Lagos');
    });
  });
}
