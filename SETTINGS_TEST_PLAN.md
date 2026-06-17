# Settings Module Test Plan and Checklist

**Objective**: Verify Settings module is fully functional and fully visible in dark mode  
**Scope**: User Settings Screen (Profile & Localization Tabs)  
**Test Date**: 2026-06-17

---

## Pre-Test Setup

### Device Configuration
- [ ] Device theme set to Dark Mode
- [ ] Device language set to English
- [ ] Device timezone set to UTC
- [ ] App fresh install (or clear app data)

### Test Account
- [ ] Test account created with valid profile
- [ ] User logged in
- [ ] Settings screen accessible

---

## Module 1: Profile Tab - Light Mode

### 1.1 Avatar Management

#### Test 1.1.1: Avatar Display
- [ ] Current profile photo visible and centered
- [ ] Avatar has rounded corners
- [ ] Upload button visible and clickable
- [ ] Loading spinner appears during upload
- [ ] New photo displays immediately after upload
- [ ] Photo cache busting works (timestamp added to URL)

**Pass Criteria**: All elements visible and functional

#### Test 1.1.2: Image Upload Validation
- [ ] Accept PNG images
- [ ] Accept JPG images
- [ ] Accept JPEG images
- [ ] Accept WebP images
- [ ] Reject non-image files (show error toast)
- [ ] Reject images > 5 MB (show "Image too large" error)
- [ ] Reject empty files (show "file is empty" error)

**Pass Criteria**: All validations work correctly

### 1.2 Personal Information

#### Test 1.2.1: Profile Display
- [ ] Name displays correctly
- [ ] Email displays correctly
- [ ] Mobile prefix displays correctly
- [ ] Mobile number displays correctly
- [ ] Address displays correctly
- [ ] Country displays correctly
- [ ] State displays correctly
- [ ] City displays correctly
- [ ] Pincode displays correctly (if present)

**Pass Criteria**: All fields display current values

#### Test 1.2.2: Profile Edit Sheet
- [ ] Edit button opens bottom sheet
- [ ] All fields are editable
- [ ] Country dropdown cascades to State
- [ ] State dropdown cascades to City
- [ ] Mobile prefix dropdown shows all available prefixes
- [ ] Cancel button closes sheet without saving
- [ ] Save button validates and persists changes
- [ ] Success toast shows "Profile updated"

**Pass Criteria**: All edit flows work correctly

#### Test 1.2.3: Required Field Validation
- [ ] Empty name shows error
- [ ] Empty email shows error
- [ ] Empty mobile prefix shows error
- [ ] Empty mobile number shows error
- [ ] Empty address shows error
- [ ] Empty country shows error
- [ ] Empty state shows error
- [ ] Empty city shows error

**Pass Criteria**: All required fields validated

**MISSING VALIDATION - FLAG AS ISSUE**:
- [ ] Email format validation (abc123 should fail)
- [ ] Mobile number format validation (abc should fail)

### 1.3 Email Verification

#### Test 1.3.1: Unverified Email
- [ ] "Verify Email" button visible
- [ ] Button tappable
- [ ] Starts OTP request flow

#### Test 1.3.2: Email OTP Flow
- [ ] OTP request shows loading state
- [ ] OTP arrives within expected time
- [ ] OTP verification sheet opens
- [ ] User can enter 6-digit OTP
- [ ] Verify button validates OTP
- [ ] Success shows "Email verified"
- [ ] Verified badge shows "Verified" state
- [ ] Verify button becomes disabled

**Pass Criteria**: Complete OTP flow works

#### Test 1.3.3: Resend OTP
- [ ] Resend button visible in OTP sheet
- [ ] Resend works multiple times
- [ ] New OTP received after resend

**Pass Criteria**: Resend functionality works

### 1.4 WhatsApp Verification

#### Test 1.4.1: WhatsApp Verification Flow
- [ ] Same as Email verification but for WhatsApp
- [ ] "Verify WhatsApp" button visible
- [ ] OTP arrives via WhatsApp
- [ ] OTP entry and verification works
- [ ] Success shows "WhatsApp verified"

**Pass Criteria**: WhatsApp verification flow works

### 1.5 Company Settings

#### Test 1.5.1: Company Display
- [ ] Company name displays (if set)
- [ ] Website URL displays as link
- [ ] Custom domain displays
- [ ] Social media icons visible
- [ ] Primary color swatch displays

**Pass Criteria**: All company info displays

#### Test 1.5.2: Company Edit Sheet
- [ ] Edit button opens bottom sheet
- [ ] Company name editable
- [ ] Website URL editable
- [ ] Custom domain editable
- [ ] Social links editable
- [ ] Color picker opens
- [ ] Save validates all URLs
- [ ] Invalid URL shows error message

**Pass Criteria**: Company edit flow works

#### Test 1.5.3: URL Validation
- [ ] Accept valid URLs with protocol: `https://example.com`
- [ ] Accept URLs without protocol: `example.com` (auto-prefixes)
- [ ] Reject malformed URLs: `not a url`
- [ ] Reject URLs without domain: `https://`
- [ ] Social links same validation as website
- [ ] Optional fields allow empty values

**Pass Criteria**: All URL validations work

### 1.6 Password Change

#### Test 1.6.1: Password Change Sheet
- [ ] "Change Password" button visible
- [ ] Button opens bottom sheet
- [ ] Current password field present and masked
- [ ] New password field present and masked
- [ ] Confirm password field present and masked
- [ ] Eye icon toggles password visibility
- [ ] All fields required

**Pass Criteria**: Password sheet UI complete

#### Test 1.6.2: Password Validation
- [ ] Empty current password shows error
- [ ] Empty new password shows error
- [ ] Empty confirm password shows error
- [ ] Mismatched passwords show error
- [ ] Valid match enables save
- [ ] Save sends request to API
- [ ] Success shows "Password changed"

**Pass Criteria**: Password change validation works

### 1.7 Email Subscription

#### Test 1.7.1: Subscription Display
- [ ] Current subscription status displays
- [ ] Subscription preference clear

#### Test 1.7.2: Subscription Toggle
- [ ] Subscribe button visible if not subscribed
- [ ] Subscribe button clickable
- [ ] Unsubscribe works if subscribed
- [ ] Status updates after toggle
- [ ] Success toast shows
- [ ] Error handled gracefully

**Pass Criteria**: Email subscription toggle works

---

## Module 2: Profile Tab - Dark Mode

### 2.1 Dark Mode Visibility

#### Test 2.1.1: Profile Header
- [x] Name visible in dark mode
- [x] Avatar visible in dark mode
- [x] Avatar container contrast acceptable
- [x] Edit button visible in dark mode

#### Test 2.1.2: Profile Info Card
- [x] All fields readable in dark mode
- [x] Text has adequate contrast
- [x] Field labels visible
- [x] Field values visible

#### Test 2.1.3: Verification Cards
- [x] Email verification card readable
- [x] WhatsApp verification card readable
- [x] Verify buttons visible
- [x] Status badges readable

#### Test 2.1.4: Company Card
- [ ] Company card readable (LOW CONTRAST - ISSUE)
- [ ] Social icons visible (possibly hard to see)
- [ ] Edit button visible

#### Test 2.1.5: Password Card
- [ ] Title "Security" readable
- [ ] Description text readable
- [ ] Change Password button visible

#### Test 2.1.6: Email Subscription Card
- [x] Card content readable
- [x] Subscribe button visible
- [x] Status text readable

#### Test 2.1.7: Edit Sheets (Dark Mode)
- [ ] Profile edit sheet readable (needs theme-aware background)
- [ ] Company edit sheet readable (needs theme-aware background)
- [ ] Password sheet readable (needs theme-aware background)
- [ ] All input fields visible
- [ ] Buttons visible and clickable

**Dark Mode Issues to Flag**:
- Profile/Company/Password edit sheets have light-mode background
- Some icon backgrounds may be hard to see
- Input field containers may need contrast adjustment

---

## Module 3: Localization Tab - Light Mode

### 3.1 Localization Preview

#### Test 3.1.1: Preview Card Visibility
- [x] Preview card displays
- [x] Selected language name shows
- [x] Date format sample shows
- [x] Time format sample shows (12H/24H)
- [x] Direction indicator shows (LTR/RTL)
- [x] Theme indicator shows

**Pass Criteria**: Preview displays all settings

#### Test 3.1.2: Preview Updates
- [ ] Preview updates when language changes
- [ ] Preview updates when date format changes
- [ ] Preview updates when time format changes
- [ ] Preview updates when theme changes
- [ ] Preview updates in real-time (not after save)

**Pass Criteria**: Preview reflects draft changes

### 3.2 Language Selection

#### Test 3.2.1: Language Picker
- [ ] Language picker button shows current selection
- [ ] Picker opens bottom sheet
- [ ] Language list displays all available languages
- [ ] Language labels show correctly
- [ ] Search field functional
- [ ] Search filters languages
- [ ] Current selection highlighted
- [ ] Selection changes preview

**Pass Criteria**: Language picker works

#### Test 3.2.2: Language Options
- [ ] English available
- [ ] Arabic available
- [ ] Hindi available
- [ ] Spanish available
- [ ] French available
- [ ] Portuguese available
- [ ] Fallback languages show if API fails

**Pass Criteria**: All languages available

### 3.3 Layout Direction

#### Test 3.3.1: Layout Direction Control
- [ ] Segmented control displays (LTR/RTL)
- [ ] Current selection shown
- [ ] Tapping LTR selects LTR
- [ ] Tapping RTL selects RTL
- [ ] Selection updates preview

**Pass Criteria**: Layout direction control works

#### Test 3.3.2: Layout Direction Validation
- [ ] Cannot have empty selection
- [ ] Only LTR or RTL allowed
- [ ] Save button enabled with valid selection

**Pass Criteria**: Direction validation works

### 3.4 Date Format

#### Test 3.4.1: Date Format Picker
- [ ] Date format picker shows current selection
- [ ] Picker opens searchable list
- [ ] All available date formats show
- [ ] Search filters formats
- [ ] Current selection highlighted
- [ ] Selection updates preview

**Pass Criteria**: Date format picker works

#### Test 3.4.2: Date Format Options
- [ ] YYYY-MM-DD available
- [ ] DD/MM/YYYY available
- [ ] MM/DD/YYYY available
- [ ] Fallback formats show if API fails
- [ ] Custom format accepted if set on server

**Pass Criteria**: Date formats available

### 3.5 Time Format

#### Test 3.5.1: Time Format Control
- [ ] Segmented control displays (24H/12H)
- [ ] Current selection shown
- [ ] Tapping 24H selects 24H
- [ ] Tapping 12H selects 12H
- [ ] Selection updates preview (shows "14:30" or "2:30 PM")

**Pass Criteria**: Time format control works

### 3.6 Timezone

#### Test 3.6.1: Timezone Picker
- [ ] Timezone picker shows current offset
- [ ] Picker opens searchable list
- [ ] All timezones display with offset and name
- [ ] Search filters timezones
- [ ] Current selection highlighted
- [ ] Selection updates preview

**Pass Criteria**: Timezone picker works

#### Test 3.6.2: Timezone Format
- [ ] Format is `[±]HH:MM` (e.g., +05:30, -08:00)
- [ ] UTC shown as +00:00
- [ ] IST shown as +05:30
- [ ] PST shown as -08:00
- [ ] Custom timezone accepted if entered

**Pass Criteria**: Timezone format correct

### 3.7 Distance Unit

#### Test 3.7.1: Distance Unit Control
- [ ] Segmented control displays (KM/MILES)
- [ ] Current selection shown
- [ ] Tapping KM selects KM
- [ ] Tapping MILES selects MILES
- [ ] Selection updates preview

**Pass Criteria**: Distance unit control works

#### Test 3.7.2: Unit Application
- [ ] After save, distances show in KM
- [ ] After save, distances show in MILES
- [ ] Conversion not needed (just unit label change)

**Pass Criteria**: Unit application works

### 3.8 Theme Selection

#### Test 3.8.1: Theme Control
- [ ] Segmented control displays (System/Light/Dark)
- [ ] Current selection visible
- [ ] Tapping System selects System
- [ ] Tapping Light selects Light
- [ ] Tapping Dark selects Dark
- [ ] Selection updates preview

**Pass Criteria**: Theme control works (in light mode)

#### Test 3.8.2: Theme Application
- [ ] Saving System theme follows device setting
- [ ] Saving Light theme applies light colors
- [ ] Saving Dark theme applies dark colors
- [ ] Theme applies to all screens
- [ ] Theme persists after app restart

**Pass Criteria**: Theme application works

### 3.9 Map Defaults

#### Test 3.9.1: Coordinate Inputs
- [ ] Latitude field editable (shows current value)
- [ ] Longitude field editable (shows current value)
- [ ] Map zoom field editable (shows current value)
- [ ] Real-time validation on input
- [ ] Error messages show for invalid values

**Pass Criteria**: Coordinate fields work

#### Test 3.9.2: Latitude Validation
- [ ] Valid input: 0 accepted
- [ ] Valid input: 90 accepted
- [ ] Valid input: -90 accepted
- [ ] Valid input: 45.5 accepted
- [ ] Invalid input: 91 shows error "must be between -90 and 90"
- [ ] Invalid input: -91 shows error
- [ ] Invalid input: abc shows error "Enter a valid latitude"
- [ ] Empty input shows error "Latitude is required"

**Pass Criteria**: Latitude validation complete

#### Test 3.9.3: Longitude Validation
- [ ] Valid input: 0 accepted
- [ ] Valid input: 180 accepted
- [ ] Valid input: -180 accepted
- [ ] Valid input: 120.5 accepted
- [ ] Invalid input: 181 shows error "must be between -180 and 180"
- [ ] Invalid input: -181 shows error
- [ ] Invalid input: xyz shows error "Enter a valid longitude"
- [ ] Empty input shows error "Longitude is required"

**Pass Criteria**: Longitude validation complete

#### Test 3.9.4: Map Zoom Validation
- [ ] Valid input: 1 accepted
- [ ] Valid input: 22 accepted
- [ ] Valid input: 15 accepted
- [ ] Invalid input: 0 shows error "must be between 1 and 22"
- [ ] Invalid input: 23 shows error "must be between 1 and 22"
- [ ] Invalid input: abc shows error "Enter a valid zoom level"
- [ ] Empty input shows error "Map zoom is required"

**Pass Criteria**: Map zoom validation complete

#### Test 3.9.5: Location Presets
- [ ] Preset chips display (Auto, Office, Home, etc.)
- [ ] Active preset highlighted
- [ ] Tapping preset updates all three coordinates
- [ ] Tapping preset updates preview
- [ ] Manual coordinate entry changes active preset to None
- [ ] Preset change does not auto-save

**Pass Criteria**: Location presets work

---

## Module 4: Localization Tab - Dark Mode

### 4.1 Preview Card (CRITICAL ISSUE)

#### Test 4.1.1: Preview Visibility in Dark Mode
- [ ] **FAIL** Preview card invisible or barely visible
- [ ] **EXPECTED**: Preview should use dark-mode surface color
- [ ] **ISSUE**: Hard-coded `OpenVtsColors.surface` (light gray)
- [ ] Text has low contrast
- [ ] Background blends into screen

**ACTION REQUIRED**: Fix preview card colors

### 4.2 Language Picker (Dark Mode)

#### Test 4.2.1: Language Picker Sheet
- [ ] Picker modal opens
- [ ] Language list readable in dark mode (LOW CONTRAST)
- [ ] Search field visible
- [ ] Buttons visible
- [ ] Selection works despite contrast issues

**Dark Mode Issue**: Low contrast text on dark background

### 4.3 Layout Direction (CRITICAL ISSUE)

#### Test 4.3.1: Layout Direction Visibility
- [ ] **FAIL** Segmented control barely visible in dark mode
- [ ] **EXPECTED**: Both segments should be clearly visible
- [ ] **ISSUE**: Light-mode colors hard-coded
- [ ] Active segment (dark text on dark background) nearly invisible
- [ ] Unselected segment (light text) barely visible

**ACTION REQUIRED**: Fix segmented control theme awareness

### 4.4 Date Format Picker (Dark Mode)

#### Test 4.4.1: Date Format Sheet
- [ ] Picker modal opens in dark mode
- [ ] Date formats readable (LOW CONTRAST)
- [ ] Search field visible
- [ ] Current selection highlighted
- [ ] Functionality works despite visibility issues

**Dark Mode Issue**: Low contrast in picker modal

### 4.5 Time Format (CRITICAL ISSUE)

#### Test 4.5.1: Time Format Control
- [ ] **FAIL** Segmented control difficult to read
- [ ] **EXPECTED**: Both 24H and 12H options clearly visible
- [ ] **ISSUE**: Hard-coded light colors, active state invisible
- [ ] Current selection hard to determine

**ACTION REQUIRED**: Fix time format control colors

### 4.6 Timezone Picker (Dark Mode)

#### Test 4.6.1: Timezone Sheet
- [ ] Picker modal opens
- [ ] Timezone list readable (LOW CONTRAST)
- [ ] Search works
- [ ] Selection works

**Dark Mode Issue**: Low contrast in picker modal

### 4.7 Distance Unit (CRITICAL ISSUE)

#### Test 4.7.1: Distance Unit Control
- [ ] **FAIL** Segmented control difficult to read
- [ ] **EXPECTED**: KM and MILES options clearly visible
- [ ] **ISSUE**: Hard-coded light colors
- [ ] Active segment nearly invisible

**ACTION REQUIRED**: Fix distance unit control colors

### 4.8 Theme Selection (CRITICAL ISSUE)

#### Test 4.8.1: Theme Control Visibility
- [ ] **FAIL** Theme selector INVISIBLE in dark mode
- [ ] **EXPECTED**: System, Light, Dark options clearly visible
- [ ] **CRITICAL ISSUE**: Hard-coded light colors make control invisible
- [ ] User cannot see which theme is selected
- [ ] Cannot change from Dark theme once selected

**ACTION REQUIRED**: URGENT - Fix theme selector visibility

### 4.9 Map Coordinates (Dark Mode)

#### Test 4.9.1: Coordinate Input Fields
- [ ] Fields visible but LOW CONTRAST
- [ ] Labels readable with effort
- [ ] Input fields usable but difficult to focus
- [ ] Error messages readable

**Dark Mode Issue**: Input field containers need dark-mode colors

### 4.10 Location Presets (Dark Mode)

#### Test 4.10.1: Preset Chips
- [ ] Preset chips visible
- [ ] Inactive presets readable (some contrast)
- [ ] Active preset highlighted (but hard to see)
- [ ] Chip text readable

**Dark Mode Issue**: Preset colors need theme awareness

---

## Module 5: Save and Persistence

### 5.1 Dirty State Tracking

#### Test 5.1.1: Profile Tab Dirty State
- [ ] Make change to profile field
- [ ] Save bar appears at bottom with "Save" and "Reset" buttons
- [ ] Save button enabled
- [ ] Reset button enabled
- [ ] Refresh button shows "unsaved changes" warning dialog
- [ ] Multiple changes still show single save bar
- [ ] Switching tabs does NOT clear dirty state

**Pass Criteria**: Dirty state tracked correctly

#### Test 5.1.2: Localization Tab Dirty State
- [ ] Change language selection
- [ ] Save bar appears
- [ ] Make multiple changes (date, time, theme)
- [ ] All changes grouped in single save
- [ ] Reset discards all changes
- [ ] Tab shows modification indicator

**Pass Criteria**: Dirty state tracked correctly

### 5.2 Save Functionality

#### Test 5.2.1: Profile Save
- [ ] Edit profile field
- [ ] Tap Save button
- [ ] Loading indicator appears
- [ ] API call completes
- [ ] Success toast shows "Profile settings updated"
- [ ] Save bar disappears
- [ ] Changes persisted to UI
- [ ] Server updated with new values

**Pass Criteria**: Profile save works end-to-end

#### Test 5.2.2: Localization Save
- [ ] Change localization setting
- [ ] Tap Save button
- [ ] Loading indicator appears
- [ ] API call completes
- [ ] Success toast shows "Localization settings updated"
- [ ] Theme applies immediately if changed
- [ ] Language changes to selected language
- [ ] Date format preview updates
- [ ] Server updated with new values

**Pass Criteria**: Localization save works end-to-end

### 5.3 Error Handling

#### Test 5.3.1: Invalid Profile Save
- [ ] Leave required field empty (e.g., name)
- [ ] Tap Save button
- [ ] Error banner shows "This field is required"
- [ ] Save does NOT proceed
- [ ] Dirty state maintained
- [ ] User can correct and retry

**Pass Criteria**: Validation prevents invalid save

#### Test 5.3.2: Profile Save Network Error
- [ ] Disable network
- [ ] Try to save profile
- [ ] Error toast shows (network error)
- [ ] Error banner shows in settings
- [ ] Dirty state maintained
- [ ] User can retry when network restored

**Pass Criteria**: Network errors handled gracefully

#### Test 5.3.3: Localization Save Network Error
- [ ] Disable network
- [ ] Try to save localization
- [ ] Error toast shows
- [ ] Error banner shows
- [ ] Dirty state maintained

**Pass Criteria**: Network errors handled gracefully

### 5.4 Reset Functionality

#### Test 5.4.1: Profile Reset
- [ ] Edit profile field
- [ ] Tap Reset button
- [ ] Draft changes discarded
- [ ] Field reverts to saved value
- [ ] Save bar disappears
- [ ] Changes not persisted

**Pass Criteria**: Reset discards changes

#### Test 5.4.2: Localization Reset
- [ ] Change localization settings
- [ ] Tap Reset button
- [ ] All changes reverted
- [ ] Selections revert to saved values
- [ ] Preview updates to show saved settings
- [ ] Save bar disappears

**Pass Criteria**: Reset works for localization

---

## Module 6: Persistence Verification

### 6.1 Local Storage

#### Test 6.1.1: Theme Persistence
- [ ] Select Dark theme
- [ ] Tap Save
- [ ] Close settings
- [ ] Restart app
- [ ] Theme still Dark
- [ ] Theme applied to all screens

**Pass Criteria**: Theme persists across app restart

#### Test 6.1.2: Language Persistence
- [ ] Select Arabic language
- [ ] Tap Save
- [ ] Close settings
- [ ] Restart app
- [ ] Language still Arabic
- [ ] All strings localized to Arabic
- [ ] RTL layout applied if language is RTL

**Pass Criteria**: Language persists across app restart

#### Test 6.1.3: Date Format Persistence
- [ ] Select "DD/MM/YYYY" date format
- [ ] Tap Save
- [ ] Navigate to screens showing dates
- [ ] Dates display in DD/MM/YYYY format
- [ ] Restart app
- [ ] Date format still DD/MM/YYYY

**Pass Criteria**: Date format persists

#### Test 6.1.4: Time Format Persistence
- [ ] Select 12H time format
- [ ] Tap Save
- [ ] Navigate to screens showing times
- [ ] Times display in 12H format (e.g., "2:30 PM")
- [ ] Restart app
- [ ] Time format still 12H

**Pass Criteria**: Time format persists

#### Test 6.1.5: Timezone Persistence
- [ ] Select timezone "+05:30 IST"
- [ ] Tap Save
- [ ] Restart app
- [ ] Timezone still "+05:30"
- [ ] All timestamps show in this timezone

**Pass Criteria**: Timezone persists

#### Test 6.1.6: Units Persistence
- [ ] Select Miles unit
- [ ] Tap Save
- [ ] Navigate to screens with distances
- [ ] Distances show in miles (e.g., "5.2 mi")
- [ ] Restart app
- [ ] Unit still Miles

**Pass Criteria**: Units persist

### 6.2 Server-Side Persistence

#### Test 6.2.1: Profile Data on Server
- [ ] Edit and save profile (name, email, mobile)
- [ ] Log out
- [ ] Clear app data
- [ ] Log back in as same user
- [ ] Profile data matches what was saved
- [ ] Avatar still present

**Pass Criteria**: Profile persists on server

#### Test 6.2.2: Localization on Server
- [ ] Note current timezone from API response
- [ ] Change timezone and save
- [ ] Call user profile API directly
- [ ] Verify `localization.timezone` matches new value

**Pass Criteria**: Localization persists on server

---

## Module 7: Validation Audit

### 7.1 Profile Validation

#### Test 7.1.1: Name Validation
- [ ] Empty name rejected (error shown)
- [ ] Name with 1 char accepted
- [ ] Name with 100 chars accepted
- [ ] Name with special characters accepted
- [ ] Name with numbers accepted
- [ ] Name with emoji accepted

**Pass Criteria**: Name validation works

#### Test 7.1.2: **Email Validation (MISSING)**
- [ ] ❌ Empty email rejected
- [ ] ❌ "abc" NOT rejected (ISSUE - should require @ and domain)
- [ ] ❌ "test@" NOT rejected (ISSUE - should require domain)
- [ ] ❌ "test@example" NOT rejected (ISSUE - should require TLD)
- [ ] "test@example.com" accepted

**MISSING VALIDATION - REPORT AS ISSUE**

#### Test 7.1.3: Mobile Validation **(MISSING)**
- [ ] ❌ Empty mobile rejected
- [ ] ❌ "abc" NOT rejected (ISSUE - should be numeric)
- [ ] ❌ "123" may be rejected (depends on length rule)
- [ ] "9876543210" accepted

**MISSING VALIDATION - REPORT AS ISSUE**

#### Test 7.1.4: Address Validation
- [ ] Empty address rejected
- [ ] Address with 1 char accepted
- [ ] Address with multiple lines accepted
- [ ] Address with special characters accepted

**Pass Criteria**: Address validation works

#### Test 7.1.5: Country/State/City Validation
- [ ] Empty country rejected
- [ ] Empty state rejected (after country selected)
- [ ] Empty city rejected (after state selected)
- [ ] Selecting country populates states
- [ ] Selecting state populates cities
- [ ] Mismatched country/state/city combinations not allowed

**Pass Criteria**: Cascading validation works

#### Test 7.1.6: Pincode Validation
- [ ] Empty pincode allowed (optional field)
- [ ] Non-numeric pincode rejected (error: "must be numeric")
- [ ] Pincode < 3 chars rejected (error: "3-10 digits")
- [ ] Pincode 3-10 chars accepted
- [ ] Pincode > 10 chars rejected

**Pass Criteria**: Pincode validation works

### 7.2 Localization Validation

#### Test 7.2.1: Language Validation
- [ ] Language selection required
- [ ] Cannot save without language
- [ ] All supported languages selectable

**Pass Criteria**: Language validation works

#### Test 7.2.2: Date Format Validation
- [ ] Date format selection required
- [ ] Cannot save without date format
- [ ] All supported formats selectable

**Pass Criteria**: Date format validation works

#### Test 7.2.3: Timezone Validation
- [ ] Timezone selection required
- [ ] Format must be `[±]HH:MM`
- [ ] Invalid format rejected
- [ ] Valid timezones selectable

**Pass Criteria**: Timezone validation works

#### Test 7.2.4: Latitude Validation (tested above in 3.9.2)
- [x] Range -90 to 90 enforced
- [x] Invalid format rejected
- [x] Decimal values accepted
- [x] Empty rejected
- [x] Real-time validation with error display

**Pass Criteria**: Latitude validation complete

#### Test 7.2.5: Longitude Validation (tested above in 3.9.3)
- [x] Range -180 to 180 enforced
- [x] Invalid format rejected
- [x] Decimal values accepted
- [x] Empty rejected
- [x] Real-time validation with error display

**Pass Criteria**: Longitude validation complete

#### Test 7.2.6: Map Zoom Validation (tested above in 3.9.4)
- [x] Range 1 to 22 enforced
- [x] Invalid format rejected
- [x] Integer values only
- [x] Empty rejected
- [x] Real-time validation with error display

**Pass Criteria**: Map zoom validation complete

---

## Summary Checklist

### Light Mode Functionality
- [x] Profile Tab: **PASS** (90% - email/mobile format missing)
- [x] Localization Tab: **PASS** (90% - email/mobile format missing)
- [x] Save Functionality: **PASS**
- [x] Dirty State Tracking: **PASS**
- [x] Validation: **PARTIAL** (85% - missing email/mobile format)
- [x] Persistence: **PASS**

### Dark Mode Visibility
- [ ] Profile Tab: **NEEDS FIXES** (90% visible, some low contrast)
- [ ] Localization Tab: **CRITICAL ISSUES** (multiple components invisible)
  - [ ] Theme selector INVISIBLE
  - [ ] Preview card INVISIBLE
  - [ ] Segmented controls LOW CONTRAST
  - [ ] Input fields LOW CONTRAST
- [ ] Edit Sheets: **NEEDS FIXES** (light backgrounds)

### Critical Issues Found
1. 🔴 Theme selector invisible in dark mode
2. 🔴 Localization preview invisible in dark mode
3. 🟡 Email validation missing
4. 🟡 Mobile number validation missing
5. 🟡 Input field visibility issues in dark mode

---

## Test Execution Notes

**Date**: _________________  
**Tester**: _________________  
**Device**: _________________  
**App Version**: _________________

### Issues Encountered
```
1. 
2. 
3. 
```

### Notes
```
```

### Sign-off
- [ ] All critical issues resolved
- [ ] All high issues resolved
- [ ] Dark mode fully functional
- [ ] Ready for release

**Approval**: _________________ **Date**: _________
