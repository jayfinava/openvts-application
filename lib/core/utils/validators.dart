class Validators {
  const Validators._();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _numericRegex = RegExp(r'^\d+$');
  static final _vinRegex = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

  // Character limits matching backend constraints
  static const int minNameLength = 2;
  static const int maxNameLength = 120;
  static const int maxEmailLength = 254;
  static const int maxUsernameLength = 50;
  static const int maxPasswordLength = 100;
  static const int minPasswordLength = 8;
  static const int maxMobilePrefixLength = 10;
  static const int maxMobileNumberLength = 20;
  static const int minMobileNumberLength = 7;
  static const int maxCompanyNameLength = 200;
  static const int minAddressLength = 3;
  static const int maxAddressLength = 200;
  static const int minPincodeLength = 4;
  static const int maxPincodeLength = 20;
  static const int minVehicleNameLength = 2;
  static const int maxVehicleNameLength = 120;
  static const int minPlateNumberLength = 2;
  static const int maxPlateNumberLength = 32;
  static const int minVinLength = 2;
  static const int maxVinLength = 64;
  static const int standardVinLength = 17;

  // ---------------------------------------------------------------------------
  // Generic
  // ---------------------------------------------------------------------------

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (s.length > maxEmailLength) {
      return 'Email must be $maxEmailLength characters or fewer';
    }
    if (!_emailRegex.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Admin form validators
  // ---------------------------------------------------------------------------

  static String? adminName(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Full name is required';
    if (s.length < minNameLength) {
      return 'Full name must be at least $minNameLength characters';
    }
    if (s.length > maxNameLength) {
      return 'Full name must be $maxNameLength characters or fewer';
    }
    return null;
  }

  static String? adminEmailRequired(String? value) {
    return email(value);
  }

  static String? adminEmailOptional(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return null;
    if (!_emailRegex.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? adminUsername(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Username is required';
    if (s.length < minNameLength) {
      return 'Username must be at least $minNameLength characters';
    }
    if (s.length > maxUsernameLength) {
      return 'Username must be $maxUsernameLength characters or fewer';
    }
    return null;
  }

  static String? adminPassword(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < minPasswordLength) {
      return 'Minimum $minPasswordLength characters';
    }
    if (s.length > maxPasswordLength) {
      return 'Password must be $maxPasswordLength characters or fewer';
    }
    return null;
  }

  static String? adminConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm the password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? companyName(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Company name is required';
    if (s.length < minNameLength) {
      return 'Company name must be at least $minNameLength characters';
    }
    if (s.length > maxCompanyNameLength) {
      return 'Company name must be $maxCompanyNameLength characters or fewer';
    }
    return null;
  }

  static String? address(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Address is required';
    if (s.length < minAddressLength) {
      return 'Address must be at least $minAddressLength characters';
    }
    if (s.length > maxAddressLength) {
      return 'Address must be $maxAddressLength characters or fewer';
    }
    return null;
  }

  static String? mobilePrefix(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Mobile prefix is required';
    if (s.length > maxMobilePrefixLength) {
      return 'Mobile prefix must be $maxMobilePrefixLength characters or fewer';
    }
    return null;
  }

  static String? mobileNumber(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Mobile number is required';
    if (s.length < minMobileNumberLength) {
      return 'Mobile number must be at least $minMobileNumberLength digits';
    }
    if (s.length > maxMobileNumberLength) {
      return 'Mobile number must be $maxMobileNumberLength digits or fewer';
    }
    if (!_numericRegex.hasMatch(s)) {
      return 'Mobile number must be numeric';
    }
    return null;
  }

  static String? pincodeOptional(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return null;
    if (s.length < minPincodeLength) {
      return 'Pincode must be at least $minPincodeLength digits';
    }
    if (s.length > maxPincodeLength) {
      return 'Pincode must be $maxPincodeLength characters or fewer';
    }
    if (!_numericRegex.hasMatch(s)) return 'Pincode must be numeric';
    return null;
  }

  static String? credits(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return null;
    final parsed = int.tryParse(s);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Credits cannot be negative';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Vehicle validators
  // ---------------------------------------------------------------------------

  static String? vehicleName(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Vehicle name is required';
    if (s.length < minVehicleNameLength) {
      return 'Vehicle name must be at least $minVehicleNameLength characters';
    }
    if (s.length > maxVehicleNameLength) {
      return 'Vehicle name must be $maxVehicleNameLength characters or fewer';
    }
    return null;
  }

  static String? plateNumber(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Plate number is required';
    if (s.length < minPlateNumberLength) {
      return 'Plate number must be at least $minPlateNumberLength characters';
    }
    if (s.length > maxPlateNumberLength) {
      return 'Plate number must be $maxPlateNumberLength characters or fewer';
    }
    return null;
  }

  static String? plateNumberOptional(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return null;

    if (s.length < minPlateNumberLength) {
      return 'Plate number must be at least $minPlateNumberLength characters';
    }
    if (s.length > maxPlateNumberLength) {
      return 'Plate number must be $maxPlateNumberLength characters or fewer';
    }

    return null;
  }

  static String? vin(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'VIN is required';

    if (s.length == standardVinLength) {
      if (!_vinRegex.hasMatch(s.toUpperCase())) {
        return 'VIN must be 17 alphanumeric characters (excluding I, O, Q)';
      }
      return null;
    }

    if (s.length < minVinLength) {
      return 'VIN must be at least $minVinLength characters';
    }
    if (s.length > maxVinLength) {
      return 'VIN must be $maxVinLength characters or fewer';
    }

    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(s.toUpperCase())) {
      return 'VIN must contain only letters and numbers';
    }

    return null;
  }

  static String? vinOptional(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return null;

    if (s.length == standardVinLength) {
      if (!_vinRegex.hasMatch(s.toUpperCase())) {
        return 'VIN must be 17 alphanumeric characters (excluding I, O, Q)';
      }
      return null;
    }

    if (s.length < minVinLength) {
      return 'VIN must be at least $minVinLength characters';
    }
    if (s.length > maxVinLength) {
      return 'VIN must be $maxVinLength characters or fewer';
    }

    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(s.toUpperCase())) {
      return 'VIN must contain only letters and numbers';
    }

    return null;
  }
}
