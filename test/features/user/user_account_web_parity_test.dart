import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/features/user/utils/user_account_form_rules.dart';

void main() {
  final fixture = jsonDecode(
      File('test/fixtures/user_account_web_contract.json')
          .readAsStringSync()) as Map<String, dynamic>;
  var index = 0;
  for (final row in fixture['cases'] as List) {
    final field = row['field'] as String, input = row['input'] as String;
    test('web schema case ${index++}: $field ${jsonEncode(input)}', () {
      final error = switch (field) {
        'name' => UserAccountFormRules.name(input),
        'username' => UserAccountFormRules.username(input),
        'optionalUsername' =>
          UserAccountFormRules.username(input, required: false),
        'email' => UserAccountFormRules.email(input),
        'password' => UserAccountFormRules.password(input),
        'mobile' => UserAccountFormRules.mobile(input),
        'optionalMobile' => UserAccountFormRules.mobile(input, required: false),
        'address' => UserAccountFormRules.address(input),
        'postal' => UserAccountFormRules.postal(input),
        _ => throw StateError('Unknown web rule: $field'),
      };
      expect(error == null, row['accepted'], reason: error);
      if (row['accepted'] == true) {
        final normalized = switch (field) {
          'name' ||
          'address' ||
          'postal' =>
            UserAccountFormRules.display(input),
          'email' => UserAccountFormRules.emailValue(input),
          'username' || 'optionalUsername' => input.trim(),
          'mobile' || 'optionalMobile' => UserAccountFormRules.digits(input),
          _ => input,
        };
        expect(normalized, row['normalized']);
      }
    });
  }
  for (final row in fixture['pairCases'] as List) {
    test('web optional mobile pairing ${jsonEncode(row)}', () {
      final prefix = row['mobilePrefix'] as String,
          mobile = row['mobileNumber'] as String;
      final valid =
          UserAccountFormRules.mobile(mobile, required: false) == null &&
              UserAccountFormRules.prefix(prefix,
                      number: mobile, required: false) ==
                  null;
      expect(valid, row['accepted']);
    });
  }
}
