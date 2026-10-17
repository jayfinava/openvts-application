import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Mirrors Frontend/src/schemas/fields.ts for User account creation. Display
/// text uses NFC; credentials are never trimmed or Unicode-normalized.
class UserAccountFormRules {
  const UserAccountFormRules._();
  static const nameMax = 35, usernameMax = 35, emailMax = 65;
  static const passwordMax = 35,
      mobileMax = 15,
      addressMax = 120,
      postalMax = 20;
  static final _ascii = RegExp(r'^[\x20-\x7E]*$');
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _name = RegExp(
    r"^[\p{L}\p{M}\p{Zs}.'’\p{Pd}\u00B7\u30FB\u05F3\u05F4\u0F0B\u0F0C\u200C\u200D]+$",
    unicode: true,
  );
  static String display(String? value) => unorm.nfc(value ?? '').trim();
  static String emailValue(String? value) => (value ?? '').trim().toLowerCase();
  static String digits(String? value) {
    final result = (value ?? '').replaceAll(RegExp(r'\D'), '');
    return result.length > mobileMax ? result.substring(0, mobileMax) : result;
  }

  static String? name(String? value) {
    final s = display(value);
    if (s.isEmpty) return 'Name is required';
    if (s.length > nameMax) return 'Name must be 35 characters or fewer';
    if (!_letter.hasMatch(s)) return 'Name must contain at least one letter';
    if (!_name.hasMatch(s)) return 'Name contains invalid characters';
    if (RegExp(r'\s{2,}').hasMatch(s)) {
      return 'Name cannot contain consecutive spaces';
    }
    return null;
  }

  static String? username(String? value, {bool required = true}) {
    final s = (value ?? '').trim();
    if (s.isEmpty && !required) return null;
    if (s.isEmpty) return 'Username is required';
    if (s.length < 3) return 'Username must be at least 3 characters';
    if (s.length > usernameMax) {
      return 'Username must be 35 characters or fewer';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(s)) {
      return 'Username must contain at least one letter';
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(s)) {
      return 'Username contains invalid characters';
    }
    return null;
  }

  static String? email(String? value) {
    final raw = value ?? '';
    if (!_ascii.hasMatch(raw)) {
      return 'Email must contain ASCII characters only';
    }
    final s = emailValue(raw);
    if (s.isEmpty) return null;
    if (s.length > emailMax) return 'Email must be 65 characters or fewer';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    final s = value ?? '';
    if (s.length < 6) return 'Password must be at least 6 characters';
    if (s.length > passwordMax) {
      return 'Password must be 35 characters or fewer';
    }
    if (!_ascii.hasMatch(s)) {
      return 'Password must contain ASCII characters only';
    }
    return null;
  }

  static String? mobile(String? value, {bool required = true}) {
    final s = digits(value);
    if (s.isEmpty && !required) return null;
    return s.length < 7 ? 'Mobile number must be at least 7 digits' : null;
  }

  static String? prefix(String? value,
          {String? number, bool required = true}) =>
      (required || digits(number).isNotEmpty) && (value ?? '').trim().isEmpty
          ? 'Mobile prefix is required'
          : null;

  static String? address(String? value) {
    final s = display(value);
    if (s.length > addressMax) return 'Address must be 120 characters or fewer';
    if (RegExp(
            r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\p{Cs}\u202A-\u202E\u2066-\u2069]',
            unicode: true)
        .hasMatch(s)) {
      return 'Address contains invalid text';
    }
    return null;
  }

  static String? postal(String? value) {
    final s = display(value);
    if (s.length > postalMax) return 'Pincode must be 20 characters or fewer';
    if (s.isNotEmpty &&
        !RegExp(r'^[\p{L}\p{M}\p{N}\p{Zs}\p{Pd}]+$', unicode: true)
            .hasMatch(s)) {
      return 'Enter a valid postal code';
    }
    return null;
  }
}
