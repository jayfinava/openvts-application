# Sub Users Module - Comprehensive Test Plan

**Objective:** Verify complete functionality and dark mode visibility of the Sub Users module

---

## 1. DARK MODE VISIBILITY TEST

### 1.1 Light Mode Visual Check
- [ ] Navigate to Accounts > Sub Users (should already be in light mode)
- [ ] Verify all UI elements are visible and readable:
  - [ ] Header card with title, description, refresh button, create button
  - [ ] Summary strip (total, active, inactive counts)
  - [ ] Filter bar with search box and status chips
  - [ ] Sub-user cards with toggle switches
  - [ ] Load more button (if applicable)
  
### 1.2 Dark Mode Visual Check
- [ ] Toggle app to dark mode (in app settings/preferences)
- [ ] Verify all UI elements remain visible and readable:
  - [ ] Header card background color adapts
  - [ ] Tab chips background color adapts (previously was white)
  - [ ] Tab chips text color adapts properly
  - [ ] Action buttons background color adapts (previously was white)
  - [ ] Filter bar chips background and text colors adapt
  - [ ] Card backgrounds are visible against dark background
  - [ ] All text has sufficient contrast
  - [ ] Icons are visible

### 1.3 Specific Dark Mode Fixes Verification
- [ ] **Tab chips in Details screen:** Background should NOT be pure white
  - Previously: Hard-coded `OpenVtsColors.white` ❌
  - Now: Uses `Theme.of(context).colorScheme.surface` ✅
  
- [ ] **Profile Tab Action Buttons:** Background should NOT be pure white
  - Previously: Hard-coded `OpenVtsColors.white` ❌
  - Now: Uses `Theme.of(context).colorScheme.surface` ✅
  
- [ ] **Vehicles Tab Action Buttons:** Background should NOT be pure white
  - Previously: Hard-coded `OpenVtsColors.white` ❌
  - Now: Uses `Theme.of(context).colorScheme.surface` ✅
  
- [ ] **Filter Status Chips:** Text and border colors should adapt to dark mode
  - Previously: Hard-coded colors ❌
  - Now: Uses `context.isDarkMode` check with appropriate colors ✅

---

## 2. LIST VIEW (USER SUBUSERS SCREEN)

### 2.1 Header & Controls
- [ ] "Sub Users" title displays correctly
- [ ] "Manage sub users and vehicle access" subtitle displays
- [ ] Refresh button appears and is clickable
- [ ] Create Sub User button appears and is clickable
- [ ] Refresh button shows loading state when pressed
- [ ] Create button is disabled during creation

### 2.2 Summary Strip
- [ ] Display shows correct format: "X total • Y active • Z inactive"
- [ ] Numbers update after CRUD operations
- [ ] Summary updates after refresh

### 2.3 Filter Bar
- [ ] Search box appears with placeholder text
- [ ] Status filter chips: All, Active, Inactive
- [ ] Clear Filters button appears when filters are applied
- [ ] Search is case-insensitive
- [ ] Status filter works correctly (filters shown items)
- [ ] Clear Filters button resets all filters

### 2.4 Sub-User Cards
- [ ] Cards display name or username or email (in priority order)
- [ ] Status badge shows "Active" or "Inactive"
- [ ] Toggle switch on card appears and is clickable
- [ ] Toggle switch shows loading state while updating
- [ ] Clicking card navigates to details screen
- [ ] Cards are properly spaced

### 2.5 Pagination & Loading
- [ ] Initial load shows spinner while loading
- [ ] Pull-to-refresh works (swipe down)
- [ ] Load More button appears when more items available
- [ ] Load More loads next page of items
- [ ] Loading state shown during load more
- [ ] No Load More button when all items loaded

### 2.6 Empty States
- [ ] "No sub users" state shows when list is empty
- [ ] Create button in empty state navigates to create
- [ ] "No matching sub users" shows when filters return nothing
- [ ] Clear Filters button in no-match state resets filters
- [ ] Empty state after search with no results

---

## 3. CREATE SUB USER

### 3.1 Create Sheet UI
- [ ] Bottom sheet opens with correct height
- [ ] Title: "Create Sub User"
- [ ] Subtitle: "Create a compact login profile with controlled access."
- [ ] Form fields visible: Name, Username, Email, Mobile Prefix, Mobile Number, Password, Active checkbox
- [ ] Submit button: "Create"
- [ ] Cancel button (or dismiss by swipe down)

### 3.2 Form Validation
- [ ] Name field is required (error if empty)
- [ ] Username field is optional
- [ ] Email field is optional (but validates format if provided)
- [ ] Mobile Prefix is optional
- [ ] Mobile Number is optional
- [ ] Password field is required (error if empty)
- [ ] Active checkbox defaults to true
- [ ] Form validates on submit, not on every keystroke

### 3.3 Create Operation
- [ ] Fill all required fields (name, password)
- [ ] Click Create button
- [ ] Loading spinner shows on button
- [ ] Request sent to API
- [ ] Success toast shows "Sub user created."
- [ ] New sub-user appears in list
- [ ] Navigator goes to details screen (if ID returned)
- [ ] Sheet closes automatically

### 3.4 Error Handling
- [ ] If API fails, show error message in toast
- [ ] Sheet remains open after error
- [ ] User can retry after error
- [ ] Network timeout error handled gracefully

---

## 4. EDIT SUB USER

### 4.1 Edit Sheet UI
- [ ] Bottom sheet opens from profile tab
- [ ] Title: "Edit Sub User"
- [ ] Form fields pre-populated with current values
- [ ] Name, Username, Email, Mobile Prefix, Mobile Number fields editable
- [ ] Password field present (optional on edit)
- [ ] Active toggle checkbox shows current status
- [ ] Submit button: "Save"
- [ ] Cancel button available

### 4.2 Edit Operation
- [ ] Modify one or more fields
- [ ] Click Save button
- [ ] Loading spinner shows on button
- [ ] Request sent to API with changed fields
- [ ] Success - details screen updates to show new values
- [ ] Error - show error toast, sheet remains open

### 4.3 Edit Validation
- [ ] Same validation as create (except password is optional)
- [ ] Required fields enforced

---

## 5. DELETE SUB USER

### 5.1 Delete Sheet UI
- [ ] Opens from profile tab when Delete button clicked
- [ ] Shows confirmation message
- [ ] Cancel button available
- [ ] Delete button (red/destructive style)

### 5.2 Delete Operation
- [ ] Click Delete button
- [ ] Loading spinner shows
- [ ] Request sent to API
- [ ] Success - Show "Sub user deleted." toast
- [ ] Sheet closes
- [ ] Navigate back to list view
- [ ] Deleted sub-user no longer in list
- [ ] Error - show error toast, sheet remains open

---

## 6. TOGGLE STATUS (ACTIVE/INACTIVE)

### 6.1 Toggle from List
- [ ] Click toggle switch on card
- [ ] Loading state shows immediately (optimistic)
- [ ] Request sent to API
- [ ] Success - Status badge updates
- [ ] Error - Rollback to previous state, show error toast
- [ ] Multiple toggles queued properly

### 6.2 Toggle from Profile Tab
- [ ] Activate/Deactivate button shown (label changes based on status)
- [ ] Click button
- [ ] Loading spinner shows
- [ ] Success - Button label changes, status badge updates
- [ ] Toast shows "Sub user activated." or "Sub user deactivated."
- [ ] Error - show error toast

### 6.3 Toggle Validation
- [ ] Only one toggle operation at a time per user
- [ ] Prevent rapid clicks (should be disabled during operation)

---

## 7. DETAILS SCREEN - PROFILE TAB

### 7.1 Summary Card
- [ ] User icon displays
- [ ] Name/username/email displayed (in priority order)
- [ ] Status pill: "Active" or "Inactive"
- [ ] Vehicle count pill: "X assigned vehicles"

### 7.2 Action Buttons
- [ ] Edit Profile button (navigates to edit sheet)
- [ ] Activate/Deactivate button (toggles status)
- [ ] Delete button (opens delete confirmation)
- [ ] All buttons show loading state during operations

### 7.3 Profile Information Card
- [ ] Section title: "Profile"
- [ ] Fields: Name, Username, Status
- [ ] Username shows "@username" format or "Not set"
- [ ] Status shows "Active" or "Inactive"
- [ ] Missing values show "-" or appropriate fallback

### 7.4 Contact Information Card
- [ ] Section title: "Contact"
- [ ] Fields: Email, Mobile
- [ ] Missing email shows "-"
- [ ] Mobile shows "prefix number" or "-" if empty
- [ ] Email is clickable (mailto link)

### 7.5 Timeline Card
- [ ] Section title: "Timeline"
- [ ] Fields: Created, Updated
- [ ] Date/time properly formatted
- [ ] Timezone converted to local
- [ ] Missing dates show "-"

### 7.6 Refresh & Error Handling
- [ ] Refresh button in header works
- [ ] Pull-to-refresh works
- [ ] Error message displays if load fails
- [ ] Retry button appears on error

---

## 8. DETAILS SCREEN - VEHICLES TAB

### 8.1 Vehicles Tab Controls
- [ ] Tab chip shows "Vehicles"
- [ ] Vehicles list displays assigned vehicles
- [ ] "X available to assign" counter shows
- [ ] Refresh button (refreshes vehicles list)
- [ ] Assign Vehicles button

### 8.2 Assigned Vehicles List
- [ ] Each vehicle card shows:
  - [ ] Vehicle icon
  - [ ] Vehicle name or plate number
  - [ ] VIN, IMEI, SIM numbers (if available)
  - [ ] License status (if available)
  - [ ] Blocked status (if applicable)
  - [ ] View Vehicle link (if has ID)
  - [ ] Unassign button

### 8.3 Vehicle Assignment
- [ ] Click "Assign Vehicles" button
- [ ] Bottom sheet opens with available vehicles
- [ ] Multi-select checkboxes for each vehicle
- [ ] Search/filter available vehicles
- [ ] Assign button (disabled if nothing selected)
- [ ] Click Assign
- [ ] Loading state shown
- [ ] Success - New vehicles appear in assigned list
- [ ] Error - Show error toast, sheet remains open

### 8.4 Vehicle Unassignment
- [ ] Click Unassign button on vehicle
- [ ] Confirmation dialog appears
- [ ] Cancel or Unassign options
- [ ] Click Unassign
- [ ] Loading state shown
- [ ] Success - Vehicle removed from list, "Vehicle unassigned." toast
- [ ] Error - Show error toast

### 8.5 Empty Vehicle State
- [ ] "No assigned vehicles" message when empty
- [ ] "Assign Vehicles" button to start assignment
- [ ] Empty state description: "Assign one or more vehicles to this sub user."

### 8.6 Vehicle View Link
- [ ] Click "View Vehicle" on assigned vehicle
- [ ] Navigate to vehicle details screen
- [ ] Correct vehicle displayed

---

## 9. CRUD OPERATIONS - COMPLETE FLOW

### 9.1 Create-Read-Update-Delete Cycle
- [ ] **Create:** Add new sub-user "Test User 1"
- [ ] **Read:** Verify appears in list and can view details
- [ ] **Update:** Edit the sub-user's email
- [ ] **Delete:** Delete the sub-user
- [ ] **Verify:** Sub-user no longer in list

### 9.2 Multiple CRUD Operations
- [ ] Create multiple sub-users
- [ ] Edit several (status, details)
- [ ] Delete some
- [ ] Verify list updates correctly

---

## 10. PERMISSIONS & VALIDATION

### 10.1 Form Validation
- [ ] Name field: Can't submit with empty name
- [ ] Username field: Optional, but validates if provided
- [ ] Email field: Optional, but validates email format if provided
- [ ] Password field: Required on create, optional on edit
- [ ] Mobile number: Validates format if provided

### 10.2 API Permissions
- [ ] Create operation requires POST permission
- [ ] Update operation requires PATCH permission
- [ ] Delete operation requires DELETE permission
- [ ] Read operation requires GET permission
- [ ] Vehicle assignment requires appropriate permission

### 10.3 Error Scenarios
- [ ] Permission denied errors handled gracefully
- [ ] 404 errors when user not found
- [ ] Validation errors from API shown to user
- [ ] Network errors (timeout, no connection) handled

---

## 11. DATE/TIME RENDERING

### 11.1 Created Date
- [ ] Shows in Profile tab Timeline section
- [ ] Format: Properly formatted date/time
- [ ] Timezone: Converted to local timezone
- [ ] Example: "Jun 17, 2026, 3:45 PM"

### 11.2 Updated Date
- [ ] Shows in Profile tab Timeline section
- [ ] Format: Same as Created date
- [ ] Timezone: Converted to local timezone
- [ ] Updates after edit operation

### 11.3 Date Formatting Edge Cases
- [ ] Null dates show "-" instead of error
- [ ] Very old dates format correctly
- [ ] Recent dates format correctly

---

## 12. MENUS & DIALOGS

### 12.1 Dialogs
- [ ] **Delete Confirmation:** Shows user name and asks for confirmation
- [ ] **Unassign Vehicle Confirmation:** Shows vehicle name
- [ ] Both dialogs have Cancel and action buttons
- [ ] Dialogs properly dismiss after action

### 12.2 Bottom Sheets
- [ ] **Create Sheet:** Opens with correct height, drag handle visible
- [ ] **Edit Sheet:** Opens, form populated, drag handle visible
- [ ] **Delete Sheet:** Opens, centered, drag handle visible
- [ ] **Assign Vehicles Sheet:** Opens, scrollable, drag handle visible
- [ ] All sheets dismiss with drag down or cancel button

### 12.3 Context Menus
- [ ] Profile tab action buttons: Edit, Activate/Deactivate, Delete
- [ ] Vehicles tab action buttons: View Vehicle, Unassign
- [ ] Filter options: All, Active, Inactive statuses

---

## 13. ACCESSIBILITY & RESPONSIVE DESIGN

### 13.1 Responsive Layout
- [ ] Test on different screen widths
- [ ] Mobile (narrow): Buttons stack vertically
- [ ] Tablet: Layout adapts to wider screen
- [ ] Desktop: Full width usage up to max constraint

### 13.2 Touch Targets
- [ ] All buttons have minimum 48x48 tap target
- [ ] Toggle switches have sufficient size
- [ ] Links are easily tappable

### 13.3 Color Contrast
- [ ] Light mode: Text contrast meets WCAG AA standards
- [ ] Dark mode: Text contrast meets WCAG AA standards
- [ ] All interactive elements properly highlighted

---

## 14. PERFORMANCE

### 14.1 List Performance
- [ ] Scrolling is smooth (60 FPS)
- [ ] Load more doesn't lag
- [ ] Search debouncing prevents excessive API calls

### 14.2 Detail Page Performance
- [ ] Profile tab loads quickly
- [ ] Vehicles tab loads quickly
- [ ] Tab switching is instant
- [ ] Refresh doesn't cause jank

### 14.3 Memory
- [ ] App doesn't leak memory on repeated operations
- [ ] Large lists don't cause slowdown

---

## 15. TEST EXECUTION CHECKLIST

### Phase 1: Dark Mode (CRITICAL)
- [ ] 1.1 Light mode visual check
- [ ] 1.2 Dark mode visual check  
- [ ] 1.3 Specific dark mode fixes verification

### Phase 2: UI & Navigation
- [ ] 2 - List view complete
- [ ] 7 - Details screen profile tab complete
- [ ] 8 - Details screen vehicles tab complete

### Phase 3: CRUD Operations
- [ ] 3 - Create sub user
- [ ] 4 - Edit sub user
- [ ] 5 - Delete sub user
- [ ] 9 - Complete CRUD cycle

### Phase 4: Features
- [ ] 6 - Toggle status
- [ ] 10 - Permissions & validation
- [ ] 11 - Date/time rendering
- [ ] 12 - Menus & dialogs

### Phase 5: Quality
- [ ] 13 - Accessibility & responsive design
- [ ] 14 - Performance

---

## SIGN-OFF

| Item | Status | Notes |
|------|--------|-------|
| Dark Mode ✅ | [ ] Pass | All colors adapted for dark mode |
| All UI Visible ✅ | [ ] Pass | All elements visible in light & dark mode |
| CRUD Operations ✅ | [ ] Pass | All create/read/update/delete working |
| Permissions ✅ | [ ] Pass | Permission checks working |
| Validation ✅ | [ ] Pass | Form validation complete |
| Date/Time ✅ | [ ] Pass | Dates rendering correctly |
| Menus/Dialogs ✅ | [ ] Pass | All dialogs and menus working |
| Overall Status | [ ] READY | **Sub Users module fully audited** |

---

**Test Date:** ___________  
**Tester Name:** ___________  
**Sign Off:** ___________
