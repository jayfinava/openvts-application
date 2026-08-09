import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/features/superadmin/models/superadmin_settings_model.dart';

void main() {
  // -----------------------------------------------------------------------
  // 1. SuperadminUpdateProfileRequest.toJson — city serialization
  // -----------------------------------------------------------------------
  group('SuperadminUpdateProfileRequest.toJson', () {
    test('contains cityName when city is set', () {
      final req = const SuperadminUpdateProfileRequest(
        name: 'Test',
        mobilePrefix: '+91',
        mobileNumber: '9999999999',
        addressLine: '123 Main St',
        countryCode: 'IN',
        stateCode: 'CH',
        cityName: 'Bastar',
      );
      final json = req.toJson();
      expect(json['cityName'], 'Bastar');
    });

    test('does NOT contain city alias', () {
      final req = const SuperadminUpdateProfileRequest(
        name: 'Test',
        mobilePrefix: '+91',
        mobileNumber: '9999999999',
        addressLine: '123 Main St',
        countryCode: 'IN',
        stateCode: 'CH',
        cityName: 'Bastar',
      );
      final json = req.toJson();
      expect(json.containsKey('city'), isFalse);
    });

    test('accepted DTO key set matches backend ProfileDto exactly', () {
      final req = const SuperadminUpdateProfileRequest(
        name: 'Test',
        email: 'test@example.com',
        mobilePrefix: '+91',
        mobileNumber: '9999999999',
        addressLine: '123 Main St',
        countryCode: 'IN',
        stateCode: 'CH',
        cityName: 'Bastar',
        pincode: '494001',
      );
      final json = req.toJson();
      const allowed = {
        'name',
        'email',
        'mobilePrefix',
        'mobileNumber',
        'addressLine',
        'countryCode',
        'stateCode',
        'cityName',
        'pincode',
      };
      for (final key in json.keys) {
        expect(allowed.contains(key), isTrue,
            reason: 'Unexpected key "$key" in toJson output');
      }
    });

    test('omits optional pincode when null', () {
      final req = const SuperadminUpdateProfileRequest(
        name: 'Test',
        mobilePrefix: '+91',
        mobileNumber: '9999999999',
        addressLine: '123 Main St',
        countryCode: 'IN',
        stateCode: 'CH',
        cityName: 'Bastar',
      );
      final json = req.toJson();
      expect(json.containsKey('pincode'), isFalse);
    });

    test('omits optional email when null', () {
      final req = const SuperadminUpdateProfileRequest(
        name: 'Test',
        mobilePrefix: '+91',
        mobileNumber: '9999999999',
        addressLine: '123 Main St',
        countryCode: 'IN',
        stateCode: 'CH',
        cityName: 'Bastar',
      );
      final json = req.toJson();
      expect(json.containsKey('email'), isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // 4. SuperadminAddressSettings.fromJson — string cityId
  // -----------------------------------------------------------------------
  group('SuperadminAddressSettings.fromJson', () {
    test('parses string cityId as city display name', () {
      final addr = SuperadminAddressSettings.fromJson(<String, dynamic>{
        'cityId': 'Bastar',
      });
      expect(addr.cityDisplayName, 'Bastar');
    });

    test('prefers explicit cityName over cityId', () {
      final addr = SuperadminAddressSettings.fromJson(<String, dynamic>{
        'cityName': 'Raipur',
        'cityId': 'Bastar',
      });
      expect(addr.cityDisplayName, 'Raipur');
    });

    test('parses city_name field', () {
      final addr = SuperadminAddressSettings.fromJson(<String, dynamic>{
        'city_name': 'Bilaspur',
      });
      expect(addr.cityDisplayName, 'Bilaspur');
    });

    test('parses city field', () {
      final addr = SuperadminAddressSettings.fromJson(<String, dynamic>{
        'city': 'Durg',
      });
      expect(addr.cityDisplayName, 'Durg');
    });

    test('numeric-looking cityId string is preserved', () {
      final addr = SuperadminAddressSettings.fromJson(<String, dynamic>{
        'cityId': '12345',
      });
      // String "12345" is a valid city identifier — must not be lost.
      expect(addr.cityId, '12345');
      expect(addr.cityDisplayName, '12345');
    });

    test('cityDisplayName is null when all city fields are absent', () {
      final addr = SuperadminAddressSettings.fromJson(<String, dynamic>{
        'addressLine': '123 Main St',
      });
      expect(addr.cityDisplayName, isNull);
    });

    test('city_id string field is parsed', () {
      final addr = SuperadminAddressSettings.fromJson(<String, dynamic>{
        'city_id': 'Jagdalpur',
      });
      expect(addr.cityId, 'Jagdalpur');
      expect(addr.cityDisplayName, 'Jagdalpur');
    });
  });

  // -----------------------------------------------------------------------
  // SuperadminProfileSettings.fromJson — city propagation from address
  // -----------------------------------------------------------------------
  group('SuperadminProfileSettings.fromJson', () {
    test('cityName propagated from address.cityId string', () {
      final profile = SuperadminProfileSettings.fromJson(<String, dynamic>{
        'name': 'Superadmin',
        'address': <String, dynamic>{
          'addressLine': '123 Main St',
          'countryCode': 'IN',
          'stateCode': 'CG',
          'cityId': 'Bastar',
        },
      });
      expect(profile.cityName, 'Bastar');
      expect(profile.address?.cityDisplayName, 'Bastar');
    });

    test('cityName propagated from address.cityName', () {
      final profile = SuperadminProfileSettings.fromJson(<String, dynamic>{
        'name': 'Superadmin',
        'address': <String, dynamic>{
          'cityName': 'Raipur',
        },
      });
      expect(profile.cityName, 'Raipur');
    });

    test('city remains visible after re-parse (refresh simulation)', () {
      final json = <String, dynamic>{
        'name': 'Superadmin',
        'address': <String, dynamic>{
          'addressLine': '123 Main St',
          'countryCode': 'IN',
          'stateCode': 'CG',
          'cityId': 'Bastar',
          'pincode': '494001',
        },
      };
      final profile1 = SuperadminProfileSettings.fromJson(json);
      final profile2 = SuperadminProfileSettings.fromJson(json);
      expect(profile1.address?.cityDisplayName, 'Bastar');
      expect(profile2.address?.cityDisplayName, 'Bastar');
    });
  });

  // -----------------------------------------------------------------------
  // SuperadminAddressSettings.copyWith — cityId stays String
  // -----------------------------------------------------------------------
  group('SuperadminAddressSettings.copyWith', () {
    test('cityId can be updated with a string value', () {
      const addr = SuperadminAddressSettings(cityId: 'Old City');
      final updated = addr.copyWith(cityId: 'New City');
      expect(updated.cityId, 'New City');
      expect(updated.cityDisplayName, 'New City');
    });
  });
}
