# Drivers Module - Dark Mode Fixes Implementation Guide

**Status**: Ready for implementation  
**Total Files to Fix**: 12  
**Total Issues**: 15+  
**Estimated Time**: 2-3 hours  

---

## Priority 1: CRITICAL FIXES (30-45 minutes)

### Fix #1: Tab Navigation Choice Chips
**File**: `lib/features/user/screens/accounts/drivers/user_driver_details_screen.dart`  
**Lines**: 315-345

**BEFORE**:
```dart
ChoiceChip(
  selected: isSelected,
  label: Text(_tabLabel(tab)),
  onSelected: (_) => onSelect(tab),
  showCheckmark: false,
  labelStyle: OpenVtsTypography.meta.copyWith(
    fontWeight: FontWeight.w800,
    color: isSelected
        ? OpenVtsColors.white
        : OpenVtsColors.textPrimary,
  ),
  selectedColor: OpenVtsColors.brandInk,
  backgroundColor: OpenVtsColors.white,  // ❌ PROBLEM
  side: const BorderSide(color: OpenVtsColors.border),  // ❌ PROBLEM
)
```

**AFTER**:
```dart
ChoiceChip(
  selected: isSelected,
  label: Text(_tabLabel(tab)),
  onSelected: (_) => onSelect(tab),
  showCheckmark: false,
  labelStyle: OpenVtsTypography.meta.copyWith(
    fontWeight: FontWeight.w800,
    color: isSelected
        ? OpenVtsColors.white
        : context.textPrimary(),  // ✅ THEME-AWARE
  ),
  selectedColor: OpenVtsColors.brandInk,
  backgroundColor: context.isDarkMode  // ✅ THEME-AWARE
      ? OpenVtsColors.darkSurface
      : OpenVtsColors.white,
  side: BorderSide(color: context.border()),  // ✅ THEME-AWARE
)
```

**Test**: Navigate to driver details, verify all three tabs are visible and clickable in dark mode.

---

### Fix #2: Filter Bar Buttons
**File**: `lib/features/user/screens/accounts/drivers/widgets/user_drivers_filter_bar.dart`  
**Lines**: 140-165

**BEFORE**:
```dart
final backgroundColor =
    highlighted ? OpenVtsColors.brandInk : OpenVtsColors.white;  // ❌ PROBLEM
final foregroundColor =
    highlighted ? OpenVtsColors.white : OpenVtsColors.textPrimary;

Container(
  height: 34,
  padding: const EdgeInsets.symmetric(horizontal: 10),
  decoration: BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
    border: Border.all(color: OpenVtsColors.border),  // ❌ PROBLEM
  ),
  child: Text(label, style: TextStyle(color: foregroundColor)),
)
```

**AFTER**:
```dart
final backgroundColor = highlighted
    ? OpenVtsColors.brandInk
    : (context.isDarkMode  // ✅ THEME-AWARE
        ? OpenVtsColors.darkSurface
        : OpenVtsColors.white);
final foregroundColor = highlighted
    ? OpenVtsColors.white
    : context.textPrimary();  // ✅ THEME-AWARE

Container(
  height: 34,
  padding: const EdgeInsets.symmetric(horizontal: 10),
  decoration: BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
    border: Border.all(color: context.border()),  // ✅ THEME-AWARE
  ),
  child: Text(label, style: TextStyle(color: foregroundColor)),
)
```

**Test**: Apply multiple filters in dark mode, verify all filter buttons are visible and functional.

---

### Fix #3: Profile Tab Action Buttons
**File**: `lib/features/user/screens/accounts/drivers/widgets/user_driver_profile_tab.dart`  
**Lines**: 295-310

**BEFORE**:
```dart
OutlinedButton.styleFrom(
  backgroundColor: OpenVtsColors.white,  // ❌ PROBLEM
  foregroundColor: foreground,
  side: BorderSide(
    color: isDestructive
        ? OpenVtsColors.error.withValues(alpha: 0.35)
        : OpenVtsColors.border,  // ❌ PROBLEM
  ),
)
```

**AFTER**:
```dart
OutlinedButton.styleFrom(
  backgroundColor: context.isDarkMode  // ✅ THEME-AWARE
      ? OpenVtsColors.darkSurface
      : OpenVtsColors.white,
  foregroundColor: foreground,
  side: BorderSide(
    color: isDestructive
        ? OpenVtsColors.error.withValues(alpha: 0.35)
        : context.border(),  // ✅ THEME-AWARE
  ),
)
```

**Test**: Open driver profile, verify "Unassign" button is visible and clickable in dark mode.

---

### Fix #4: Assign Vehicle Sheet Buttons
**File**: `lib/features/user/screens/accounts/drivers/widgets/user_driver_assign_vehicle_sheet.dart`  
**Lines**: 240-250

**BEFORE**:
```dart
OutlinedButton.styleFrom(
  backgroundColor: OpenVtsColors.white,  // ❌ PROBLEM
  foregroundColor: foreground,
  side: BorderSide(
    color: isDestructive
        ? OpenVtsColors.error.withValues(alpha: 0.35)
        : OpenVtsColors.border,  // ❌ PROBLEM
  ),
)
```

**AFTER**:
```dart
OutlinedButton.styleFrom(
  backgroundColor: context.isDarkMode  // ✅ THEME-AWARE
      ? OpenVtsColors.darkSurface
      : OpenVtsColors.white,
  foregroundColor: foreground,
  side: BorderSide(
    color: isDestructive
        ? OpenVtsColors.error.withValues(alpha: 0.35)
        : context.border(),  // ✅ THEME-AWARE
  ),
)
```

**Test**: Click "Assign Vehicle" button, verify it's visible and clickable in dark mode.

---

## Priority 2: HIGH PRIORITY FIXES (1.5-2 hours)

### Fix #5: Card and Container Borders - BATCH REPLACEMENT

**Files affected** (10+ locations):
- `admin_driver_card.dart`
- `user_driver_card.dart`
- `user_driver_profile_tab.dart`
- `user_driver_documents_tab.dart`
- `user_driver_document_sheet.dart`
- `user_driver_logs_tab.dart`
- `user_driver_details_screen.dart`
- `admin_driver_details_screen.dart`
- `admin_driver_document_sheet.dart`

**Pattern to Replace**:
Replace all occurrences of:
```dart
decoration: BoxDecoration(
  color: OpenVtsColors.surface,
  borderRadius: BorderRadius.circular(...),
  border: Border.all(color: OpenVtsColors.border),  // ❌ PROBLEM
),
```

**With**:
```dart
decoration: BoxDecoration(
  color: context.isDarkMode  // ✅ THEME-AWARE
      ? OpenVtsColors.darkSurface
      : OpenVtsColors.surface,
  borderRadius: BorderRadius.circular(...),
  border: Border.all(color: context.border()),  // ✅ THEME-AWARE
),
```

**Implementation Steps**:

1. **In `admin_driver_card.dart`**:
   - Line 49: Fix container decoration
   - Line 106: Fix status badge container
   - Line 202: Fix action button styling
   - Line 520-532: Fix multiple containers

2. **In `user_driver_card.dart`**:
   - Line 49: Fix main card container

3. **In `user_driver_documents_tab.dart`**:
   - Line 557: Fix extension badge
   - Line 674: Fix meta pill containers

4. **In `user_driver_logs_tab.dart`**:
   - Line 87: Fix icon container
   - All `_MetaPill` instances

5. **In `user_driver_profile_tab.dart`**:
   - Line 220: Fix container backgrounds

6. **In other files**: Apply same pattern

**Search and Replace Commands** (if your editor supports regex):

Find: `border: Border.all\(color: OpenVtsColors.border\)`  
Replace: `border: Border.all(color: context.border())`

Find: `color: OpenVtsColors.surface,\s*borderRadius`  
Replace: `color: context.isDarkMode ? OpenVtsColors.darkSurface : OpenVtsColors.surface,\n    borderRadius`

**Test**: Review each fixed file visually to ensure containers are visible in dark mode.

---

### Fix #6: Switch Thumb Colors
**File**: `lib/features/admin/screens/drivers/widgets/admin_driver_card.dart`  
**Lines**: 185-195

**BEFORE**:
```dart
Switch(
  value: isActive,
  onChanged: isBusy ? null : onChanged,
  activeThumbColor: OpenVtsColors.white,      // ❌ PROBLEM
  activeTrackColor: _primaryInkColor(context),
  inactiveThumbColor: OpenVtsColors.white,     // ❌ PROBLEM
  inactiveTrackColor: _softBorderColor(context),
)
```

**AFTER**:
```dart
Switch(
  value: isActive,
  onChanged: isBusy ? null : onChanged,
  activeThumbColor: context.isDarkMode  // ✅ THEME-AWARE
      ? OpenVtsColors.darkTextPrimary
      : OpenVtsColors.white,
  activeTrackColor: _primaryInkColor(context),
  inactiveThumbColor: context.isDarkMode  // ✅ THEME-AWARE
      ? OpenVtsColors.darkTextSecondary
      : OpenVtsColors.white,
  inactiveTrackColor: _softBorderColor(context),
)
```

**Test**: Toggle driver active/inactive in admin view, verify switch thumb is visible in both positions in dark mode.

---

## Priority 3: CODE QUALITY FIXES (30-45 minutes)

### Fix #7: AlertDialog Explicit Theming
**Files affected** (4 locations):
- `user_driver_profile_tab.dart` (Lines 145-165)
- `user_driver_documents_tab.dart` (Lines 135-155)
- `user_driver_delete_sheet.dart` (Lines 40-70)
- `admin_driver_details_screen.dart` (Lines 90-110)

**Pattern to Add**:

**BEFORE**:
```dart
return AlertDialog(
  title: const Text('Unassign vehicle'),
  content: const Text('Remove vehicle assignment from this driver?'),
  // ❌ No backgroundColor
  actions: [
    // ...
  ],
);
```

**AFTER**:
```dart
return AlertDialog(
  backgroundColor: Theme.of(dialogContext).colorScheme.surface,  // ✅ ADDED
  title: const Text('Unassign vehicle'),
  content: const Text('Remove vehicle assignment from this driver?'),
  actions: [
    // ...
  ],
);
```

**Test**: Open and close several confirmation dialogs in dark mode, verify they look consistent with the rest of the UI.

---

### Fix #8: Standardize Theme Checking
**Recommendation**: Use extension methods consistently

**Current inconsistency**:
```dart
// Some files use this:
color: Theme.of(context).brightness == Brightness.dark
    ? OpenVtsColors.darkSurface
    : OpenVtsColors.background,

// Others use hardcoded:
color: OpenVtsColors.surface,

// Best approach (use extension):
color: context.isDarkMode 
    ? OpenVtsColors.darkSurface 
    : OpenVtsColors.surface,
```

**Action**: When making fixes above, always use the extension method approach for consistency.

---

## Testing Checklist

After applying all fixes, verify:

### Light Mode (should still work)
- [ ] All tabs visible and clickable
- [ ] All filters work
- [ ] All buttons visible
- [ ] All cards readable
- [ ] Dialogs clear

### Dark Mode (primary focus)
- [ ] Tab chips fully visible and clickable
- [ ] Filter buttons fully visible
- [ ] All action buttons visible
- [ ] Cards have clear borders
- [ ] Text has sufficient contrast
- [ ] Dialog backgrounds match theme
- [ ] Switches clearly show state
- [ ] All icons visible

### Specific Features
- [ ] Create driver: Form fully visible
- [ ] Edit driver: Form fully visible
- [ ] Delete driver: Dialog clear
- [ ] Upload document: Upload button visible
- [ ] Document list: Cards readable
- [ ] Activity logs: All entries readable
- [ ] Filter bar: All filter options work
- [ ] Search: Search field visible and usable

---

## Fix Implementation Order

**Recommended sequence** (to minimize conflicts):

1. Start with Priority 1 fixes (4 files, ~30 min)
   - Fix #1: user_driver_details_screen.dart
   - Fix #2: user_drivers_filter_bar.dart
   - Fix #3: user_driver_profile_tab.dart
   - Fix #4: user_driver_assign_vehicle_sheet.dart

2. Test Priority 1 fixes
   - Verify critical UI is now usable in dark mode

3. Continue with Priority 2 fixes (batch work, ~90 min)
   - Fix #5: Card borders (all affected files)
   - Fix #6: Switch colors

4. Test Priority 2 fixes
   - Verify complete dark mode support

5. Apply Priority 3 fixes (consistency, ~30 min)
   - Fix #7: Dialog theming
   - Fix #8: Standardize patterns

6. Final comprehensive testing
   - Test all features in both light and dark mode
   - Verify no regressions

---

## Quick Reference - Color Mappings

**For replacing hardcoded colors**:

| Component | Light Mode | Dark Mode | Replacement |
|-----------|-----------|-----------|------------|
| Surface/Background | `OpenVtsColors.surface` (0xFFF4F3F6) | `OpenVtsColors.darkSurface` (0xFF18141D) | `context.isDarkMode ? OpenVtsColors.darkSurface : OpenVtsColors.surface` |
| Border | `OpenVtsColors.border` (0xFFE7E3EA) | `OpenVtsColors.darkBorder` (0xFF2A2430) | `context.border()` |
| Button Background | `OpenVtsColors.white` (0xFFFFFFFF) | `OpenVtsColors.darkSurface` (0xFF18141D) | `context.isDarkMode ? OpenVtsColors.darkSurface : OpenVtsColors.white` |
| Text Primary | `OpenVtsColors.textPrimary` (0xFF141118) | `OpenVtsColors.darkTextPrimary` (0xFFFFFFFF) | `context.textPrimary()` |
| Text Secondary | `OpenVtsColors.textSecondary` (0xFF6B6570) | `OpenVtsColors.darkTextSecondary` (0xFFC8C2CD) | `context.textSecondary()` |
| Switch Thumb | `OpenVtsColors.white` | `OpenVtsColors.darkTextPrimary` | `context.isDarkMode ? OpenVtsColors.darkTextPrimary : OpenVtsColors.white` |

---

## Verification Commands

After implementing fixes, you can verify changes:

```bash
# Search for remaining hardcoded colors that should be theme-aware
grep -r "OpenVtsColors\.white" lib/features/user/screens/accounts/drivers/
grep -r "OpenVtsColors\.surface," lib/features/user/screens/accounts/drivers/
grep -r 'Border.all.*OpenVtsColors.border' lib/features/user/screens/accounts/drivers/

# These should mostly be gone after fixes (some may remain if intentional)
```

---

## Commit Message

After all fixes are complete:

```
fix: Drivers module dark mode visibility

- Fix tab navigation choice chips (issue #1)
- Fix filter control buttons (issue #2)
- Fix action buttons in profile/assign sheets (issue #3)
- Replace hardcoded border colors with theme-aware alternatives (issue #4)
- Fix switch thumb colors (issue #5)
- Add explicit AlertDialog backgrounds (issue #6)
- Standardize theme checking patterns (issue #7)

Dark mode support: 40% → 100%
All UI elements now fully visible in both light and dark modes
```

---

## Questions / Issues During Implementation?

1. **"Why use `context.isDarkMode` instead of `Theme.of(context).brightness`?"**  
   - The extension method is more readable and concise
   - It's already available in `open_vts_colors.dart`
   - Consistent with the Settings module fixes

2. **"Should I update admin module too?"**  
   - Yes, apply the same fixes to admin driver files
   - Use same patterns for consistency

3. **"How do I know if a color needs theme awareness?"**  
   - If it works in light mode, apply the opposite in dark mode
   - Colors like errors/warnings can stay consistent
   - Surface/border/background colors must change

4. **"What about performance?"**  
   - No performance impact (extension methods are simple getters)
   - Rebuild behavior unchanged

---

## Success Criteria

✅ Drivers module is "fully functional and fully visible in dark mode" when:

- All tabs are clickable and clearly visible
- All filter buttons are functional and visible
- All action buttons are visible and functional
- All cards have clear, visible borders
- All text has sufficient contrast (WCAG AA minimum)
- All dialogs are properly themed
- All form inputs are usable
- Date/time formatting is correct
- Validation messages are visible
- No UI elements appear invisible or blended into background

**Current Progress**: 50% (Functionality 100%, Dark Mode 40%)  
**After Fixes**: 100% ✅

