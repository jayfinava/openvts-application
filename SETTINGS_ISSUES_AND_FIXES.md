# Settings Module - Issues and Fixes Guide

**Date**: 2026-06-17  
**Status**: AUDIT COMPLETE - ISSUES DOCUMENTED  
**Action Required**: YES

---

## Critical Issues

### 🔴 ISSUE #1: Theme Selector Invisible in Dark Mode

**Severity**: CRITICAL - Settings unusable in dark mode

**Description**: The theme segmented control (System/Light/Dark) is completely invisible when the app is in dark mode, making it impossible for users to change themes or even see the current theme selection.

**Root Cause**: Hard-coded light-mode colors without theme awareness
```dart
// In user_localization_select_card.dart (around line 228)
UserLocalizationSegmentedControl<UserThemeMode>(
  value: draft.theme,
  segments: const [
    UserLocalizationSegmentOption<UserThemeMode>(
      value: UserThemeMode.system,
      label: 'System',
    ),
    // ... more options
  ],
  // BUG: No theme-aware styling applied
)
```

**What Happens**:
- Light mode: Works correctly (visible)
- Dark mode: Text is dark, background is dark → INVISIBLE
- User cannot see which theme is selected
- Cannot change from dark theme once in dark mode

**Visual Appearance**:
```
Light Mode:                Dark Mode:
┌─────────────────┐      ┌─────────────────┐
│ System Light Dark │      │ [COMPLETELY INVISIBLE] │
└─────────────────┘      └─────────────────┘
```

**Fix**:
See **Fix #1** below

**Files Affected**:
- `lib/features/user/screens/settings/widgets/user_localization_select_card.dart`

---

### 🔴 ISSUE #2: Localization Preview Card Invisible in Dark Mode

**Severity**: CRITICAL - Core feature unusable

**Description**: The preview card showing all localization settings is invisible in dark mode due to hard-coded light surface colors.

**Root Cause**: Container uses `OpenVtsColors.surface` (light gray) without theme check
```dart
// In user_localization_preview_card.dart (around line 160)
decoration: BoxDecoration(
  color: OpenVtsColors.surface,  // BUG: Light gray in both modes
  borderRadius: BorderRadius.circular(OpenVtsRadius.md),
  border: Border.all(color: OpenVtsColors.border),  // BUG: Light border
),
```

**Impact**: User cannot preview their localization choices in dark mode

**Fix**:
See **Fix #2** below

**Files Affected**:
- `lib/features/user/screens/settings/widgets/user_localization_preview_card.dart`

---

### 🔴 ISSUE #3: Map Coordinate Inputs Invisible in Dark Mode

**Severity**: CRITICAL - Core feature unusable

**Description**: All coordinate input fields (latitude, longitude, map zoom) are nearly invisible in dark mode.

**Root Cause**: Input container and label colors hard-coded to light mode
```dart
// In user_map_defaults_card.dart (around line 39)
decoration: BoxDecoration(
  color: OpenVtsColors.surface,  // BUG: Light gray background
  borderRadius: BorderRadius.circular(OpenVtsRadius.md),
  border: Border.all(color: OpenVtsColors.border),
),
```

**Impact**: Users cannot enter map coordinates in dark mode

**Fix**:
See **Fix #3** below

**Files Affected**:
- `lib/features/user/screens/settings/widgets/user_map_defaults_card.dart`

---

## High Priority Issues

### 🟡 ISSUE #4: Email Format Validation Missing

**Severity**: HIGH - Invalid data accepted

**Description**: Email field accepts any non-empty string without format validation.

**Examples of Invalid Emails Currently Accepted**:
- `abc123` (no @ symbol)
- `test@` (no domain)
- `test@example` (no TLD)
- `@example.com` (no local part)

**Root Cause**: Only non-empty check implemented
```dart
// In user_settings_controller.dart (~line 908)
if (email.trim().isEmpty) {
  errors.add('Email is required.');
}
// BUG: No format validation follows
```

**Impact**: Invalid emails saved to database, causing email delivery failures

**Fix**:
```dart
bool _isValidEmail(String email) {
  final pattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );
  return pattern.hasMatch(email.trim());
}

// In _validateProfileDraft():
if (email.trim().isEmpty) {
  errors.add('Email is required.');
} else if (!_isValidEmail(email)) {
  errors.add('Please enter a valid email address.');
}
```

**Files to Update**:
- `lib/features/user/controllers/user_settings_controller.dart` (Line ~908)

---

### 🟡 ISSUE #5: Mobile Number Format Validation Missing

**Severity**: HIGH - Invalid data accepted

**Description**: Mobile number field accepts any non-empty string without format validation.

**Examples of Invalid Mobile Numbers Currently Accepted**:
- `abc` (non-numeric)
- `123` (too short)
- `12345678901234567890` (too long)

**Root Cause**: Only non-empty check implemented
```dart
// In user_settings_controller.dart (~line 913)
if (mobileNumber.trim().isEmpty) {
  errors.add('Mobile number is required.');
}
// BUG: No format validation
```

**Impact**: Invalid numbers saved, SMS/WhatsApp delivery fails

**Fix**:
```dart
bool _isValidMobileNumber(String number) {
  // Allow 7-15 digits (E.164 international standard)
  final pattern = RegExp(r'^\d{7,15}$');
  return pattern.hasMatch(number.trim().replaceAll(RegExp(r'[^\d]'), ''));
}

// In _validateProfileDraft():
if (mobileNumber.trim().isEmpty) {
  errors.add('Mobile number is required.');
} else if (!_isValidMobileNumber(mobileNumber)) {
  errors.add('Please enter a valid mobile number (7-15 digits).');
}
```

**Files to Update**:
- `lib/features/user/controllers/user_settings_controller.dart` (Line ~913)

---

### 🟡 ISSUE #6: All Segmented Controls Low Contrast in Dark Mode

**Severity**: HIGH - Multiple controls affected

**Description**: All segmented controls (Theme, Time Format, Units, Layout Direction) have poor contrast in dark mode:
- Unselected: Light text on dark background → acceptable but dim
- Selected: Very dark text on dark background → nearly invisible

**Affected Components**:
- Theme selector (System/Light/Dark)
- Time format selector (24H/12H)
- Distance unit selector (KM/Miles)
- Layout direction selector (LTR/RTL)

**Root Cause**: Hard-coded selection colors without theme awareness
```dart
// In flutter's SegmentedButton (internal MaterialUI)
// Selected segment uses OpenVtsColors.brandInk (very dark)
// On dark background, this is invisible
```

**Impact**: Users cannot clearly see which option is selected

**Workaround**: Visual feedback via other means (preview card, etc.)

**Fix**:
Create theme-aware segmented control styling or wrap in theme-aware container

**Files Affected**:
- `lib/features/user/screens/settings/widgets/user_localization_select_card.dart` (Lines 209, 165, 226, 120)

---

## Medium Priority Issues

### 🟠 ISSUE #7: Edit Sheet Modals Have Light Background in Dark Mode

**Severity**: MEDIUM - Readability issue

**Description**: Profile edit sheet, company edit sheet, and password sheet have hard-coded light backgrounds that don't adapt to dark mode.

**Affected Sheets**:
- Profile edit sheet (`user_profile_edit_sheet.dart`)
- Company edit sheet (`user_company_edit_sheet.dart`)
- Password change sheet (`user_password_change_sheet.dart`)

**Symptom**: Modal appears very light against dark background, with poor text contrast

**Root Cause**: Modal background uses `OpenVtsColors.surface` without theme check

**Fix**: Apply `ThemeAwareColors` extension to modal background
```dart
decoration: BoxDecoration(
  color: context.isDarkMode 
    ? OpenVtsColors.darkSurface 
    : OpenVtsColors.lightSurface,
  borderRadius: BorderRadius.vertical(
    top: Radius.circular(OpenVtsRadius.lg),
  ),
),
```

**Files to Update**:
- `lib/features/user/screens/settings/widgets/user_profile_edit_sheet.dart`
- `lib/features/user/screens/settings/widgets/user_company_edit_sheet.dart`
- `lib/features/user/screens/settings/widgets/user_password_change_sheet.dart`

---

### 🟠 ISSUE #8: Location Preset Chips Low Contrast in Dark Mode

**Severity**: MEDIUM - Readability issue

**Description**: Location preset chips (Auto, Office, Home, etc.) have low contrast in dark mode.

**Symptoms**:
- Inactive chips: Light gray text on dark background → dim
- Active chips: Very dark background → hard to distinguish from inactive

**Root Cause**: Hard-coded light colors in chip styling
```dart
// In user_location_preset_chips.dart
color: OpenVtsColors.surface,  // Light gray in dark mode
```

**Fix**: Apply theme-aware colors to chip backgrounds and text

**Files to Update**:
- `lib/features/user/screens/settings/widgets/user_location_preset_chips.dart`

---

### 🟠 ISSUE #9: Input Field Labels and Error Messages Low Contrast

**Severity**: MEDIUM - Usability issue

**Description**: Input field labels and error messages in coordinate inputs have low contrast in dark mode.

**Affected Fields**:
- Latitude input (label, error)
- Longitude input (label, error)
- Map zoom input (label, error)

**Root Cause**: Labels use `OpenVtsColors.textTertiary` hardcoded without theme awareness

**Files to Update**:
- `lib/features/user/screens/settings/widgets/user_map_defaults_card.dart`

---

## Low Priority Issues

### 🟢 ISSUE #10: Settings Save Bar Low Contrast

**Severity**: LOW - Visual issue

**Description**: Save bar at bottom has light background that doesn't adapt to dark mode.

**Root Cause**: Hard-coded `OpenVtsColors.surface` in background

**Files to Update**:
- `lib/features/user/screens/settings/widgets/user_settings_save_bar.dart`

---

### 🟢 ISSUE #11: Reference Data Loading Fallback UX

**Severity**: LOW - Cosmetic

**Description**: When reference data (languages, dates, timezones) fails to load from API, warning shows but form still functions with fallbacks. Could be clearer to user.

**Potential Fix**: Show more helpful message or loading state refresh mechanism

---

## Remediation Priority and Effort Estimates

### Phase 1: CRITICAL (Required for MVP)
**Timeline**: 3-4 hours

1. **Issue #1** - Fix theme selector visibility (1 hour)
   - Apply theme-aware colors to segmented control
   - Test in both light and dark modes
   
2. **Issue #2** - Fix preview card visibility (30 min)
   - Apply theme-aware colors to preview container
   
3. **Issue #3** - Fix coordinate inputs visibility (45 min)
   - Apply theme-aware colors to all input containers
   
4. **Issue #4** - Add email format validation (30 min)
   - Implement regex validation
   - Add error messages
   
5. **Issue #5** - Add mobile format validation (30 min)
   - Implement numeric validation
   - Add error messages

**Subtotal**: 3 hours 15 minutes

### Phase 2: HIGH (Should fix for polish)
**Timeline**: 2-2.5 hours

6. **Issue #6** - Fix all segmented controls (1 hour)
   - Create reusable theme-aware styling
   - Apply to all 4 controls

7. **Issue #7** - Fix edit sheet modals (45 min)
   - Update 3 sheets with theme-aware backgrounds

**Subtotal**: 1 hour 45 minutes

### Phase 3: MEDIUM (Nice to have)
**Timeline**: 1-2 hours

8. **Issue #8** - Fix preset chips (45 min)
9. **Issue #9** - Fix input labels (30 min)
10. **Issue #10** - Fix save bar (15 min)
11. **Issue #11** - Improve UX messaging (30 min)

**Total Estimated Fix Time**: 6.5-7 hours

---

## Implementation Guide

### Fix #1: Theme Selector Visibility

**File**: `lib/features/user/screens/settings/widgets/user_localization_select_card.dart`

**Current Code** (Line ~228):
```dart
UserLocalizationSegmentedControl<UserThemeMode>(
  value: draft.theme,
  semanticsLabel: 'Theme selector',
  segments: const [
    UserLocalizationSegmentOption<UserThemeMode>(
      value: UserThemeMode.system,
      label: 'System',
    ),
    UserLocalizationSegmentOption<UserThemeMode>(
      value: UserThemeMode.light,
      label: 'Light',
    ),
    UserLocalizationSegmentOption<UserThemeMode>(
      value: UserThemeMode.dark,
      label: 'Dark',
    ),
  ],
  onChanged: (value) {
    widget.controller.patchDraftLocalization(theme: value);
  },
)
```

**Issue**: No theme-aware styling

**Solution**: Wrap in Container with theme-aware background
```dart
Container(
  decoration: BoxDecoration(
    color: context.isDarkMode 
      ? OpenVtsColors.darkSurface.withValues(alpha: 0.5)
      : OpenVtsColors.lightSurface.withValues(alpha: 0.5),
    borderRadius: BorderRadius.circular(OpenVtsRadius.md),
  ),
  child: UserLocalizationSegmentedControl<UserThemeMode>(
    value: draft.theme,
    semanticsLabel: 'Theme selector',
    segments: const [
      UserLocalizationSegmentOption<UserThemeMode>(
        value: UserThemeMode.system,
        label: 'System',
      ),
      UserLocalizationSegmentOption<UserThemeMode>(
        value: UserThemeMode.light,
        label: 'Light',
      ),
      UserLocalizationSegmentOption<UserThemeMode>(
        value: UserThemeMode.dark,
        label: 'Dark',
      ),
    ],
    onChanged: (value) {
      widget.controller.patchDraftLocalization(theme: value);
    },
  ),
)
```

**OR**: Modify `UserLocalizationSegmentedControl` to accept background color parameter

---

### Fix #2: Preview Card Visibility

**File**: `lib/features/user/screens/settings/widgets/user_localization_preview_card.dart`

**Current Code** (Line ~160):
```dart
decoration: BoxDecoration(
  color: OpenVtsColors.surface,
  borderRadius: BorderRadius.circular(OpenVtsRadius.md),
  border: Border.all(color: OpenVtsColors.border),
),
```

**Fix**:
```dart
decoration: BoxDecoration(
  color: context.isDarkMode 
    ? OpenVtsColors.darkSurface 
    : OpenVtsColors.lightSurface,
  borderRadius: BorderRadius.circular(OpenVtsRadius.md),
  border: Border.all(
    color: context.isDarkMode 
      ? OpenVtsColors.darkBorder 
      : OpenVtsColors.lightBorder,
  ),
),
```

---

### Fix #3: Coordinate Inputs Visibility

**File**: `lib/features/user/screens/settings/widgets/user_map_defaults_card.dart`

**Current Code** (Line ~39):
```dart
decoration: BoxDecoration(
  color: OpenVtsColors.surface,
  borderRadius: BorderRadius.circular(OpenVtsRadius.md),
  border: Border.all(color: OpenVtsColors.border),
),
```

**Fix**:
```dart
decoration: BoxDecoration(
  color: context.isDarkMode 
    ? OpenVtsColors.darkSurface 
    : OpenVtsColors.lightSurface,
  borderRadius: BorderRadius.circular(OpenVtsRadius.md),
  border: Border.all(
    color: context.isDarkMode 
      ? OpenVtsColors.darkBorder 
      : OpenVtsColors.lightBorder,
  ),
),
```

**Also Update Labels** (ensure they use theme-aware text colors):
```dart
Text(
  'Latitude',
  style: OpenVtsTypography.meta.copyWith(
    color: context.isDarkMode 
      ? OpenVtsColors.darkTextSecondary 
      : OpenVtsColors.lightTextSecondary,
    fontWeight: FontWeight.w600,
  ),
)
```

---

### Fix #4: Email Validation

**File**: `lib/features/user/controllers/user_settings_controller.dart`

**Current Code** (~Line 908):
```dart
if (email.trim().isEmpty) {
  errors.add('Email is required.');
}
```

**Fix**:
```dart
final email = profile.email.trim();
if (email.isEmpty) {
  errors.add('Email is required.');
} else if (!_isValidEmail(email)) {
  errors.add('Please enter a valid email address.');
}

// Add helper method:
bool _isValidEmail(String email) {
  final pattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  return pattern.hasMatch(email);
}
```

---

### Fix #5: Mobile Number Validation

**File**: `lib/features/user/controllers/user_settings_controller.dart`

**Current Code** (~Line 913):
```dart
if (mobileNumber.trim().isEmpty) {
  errors.add('Mobile number is required.');
}
```

**Fix**:
```dart
final mobileNumber = profile.mobileNumber.trim();
if (mobileNumber.isEmpty) {
  errors.add('Mobile number is required.');
} else if (!_isValidMobileNumber(mobileNumber)) {
  errors.add('Please enter a valid mobile number (7-15 digits).');
}

// Add helper method:
bool _isValidMobileNumber(String number) {
  // Remove common separators and spaces
  final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
  // Allow 7-15 digits (E.164 standard, with optional + prefix)
  final pattern = RegExp(r'^\+?[1-9]\d{6,14}$');
  return pattern.hasMatch(cleaned);
}
```

---

## Testing After Fixes

### Quick Test Checklist

After implementing each fix:

1. **Theme Selector** (Issue #1)
   - [ ] Switch to dark mode
   - [ ] Theme selector visible
   - [ ] All three options (System/Light/Dark) readable
   - [ ] Selection works
   - [ ] Apply theme

2. **Preview Card** (Issue #2)
   - [ ] Switch to dark mode
   - [ ] Preview card visible
   - [ ] All text readable
   - [ ] Updates when settings change

3. **Coordinate Inputs** (Issue #3)
   - [ ] Switch to dark mode
   - [ ] Input fields visible
   - [ ] Labels readable
   - [ ] Can enter values
   - [ ] Error messages readable

4. **Email Validation** (Issue #4)
   - [ ] "abc" rejected
   - [ ] "test@" rejected
   - [ ] "test@example" rejected
   - [ ] "test@example.com" accepted
   - [ ] Error message clear

5. **Mobile Validation** (Issue #5)
   - [ ] "abc" rejected
   - [ ] "12345" rejected
   - [ ] "9876543210" accepted
   - [ ] Error message clear

---

## Deployment Checklist

Before deploying fixes:

- [ ] All Phase 1 fixes implemented and tested
- [ ] All Phase 2 fixes implemented and tested (recommended)
- [ ] Dark mode verification complete
- [ ] Light mode regression testing complete
- [ ] Validation errors tested
- [ ] Persistence tested after fixes
- [ ] All settings tabs working
- [ ] Code review approved
- [ ] Unit tests updated
- [ ] Integration tests passing

---

## Questions and Clarifications

**Q: Can we batch these fixes into one PR or multiple?**
A: Recommend one PR for Phase 1 (critical), one for Phase 2 (high), optional Phase 3

**Q: Should we add automated dark mode testing?**
A: Yes - consider adding golden tests for each component in dark mode

**Q: Can users work around these issues?**
A: Partially - theme selector is the main blocker. Users can use other tabs. Profile works fine.

**Q: Timeline for fixes?**
A: Phase 1 should be done before next release (blocking)

---

**End of Issues and Fixes Guide**
