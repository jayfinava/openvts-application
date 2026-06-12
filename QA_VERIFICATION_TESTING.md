# QA Testing Guide: Email and Mobile Verification Buttons

## Overview
This document provides step-by-step QA testing procedures for the email and mobile verification button functionality fix in the Superadmin Settings profile page.

## Prerequisites
- Superadmin account credentials
- Access to email inbox or WhatsApp account used for verification
- Test environment setup (backend API running and configured)

---

## Test Case 1: Email Verification Flow - Happy Path

### Setup
1. Log in with a superadmin account
2. Navigate to **Settings > Profile**
3. Locate the **Email** row in the Verification section

### Expected Initial State
- Email address is displayed
- "Verify" button is visible (or "Verified" badge if already verified)
- No verification state badge present for unverified email

### Step-by-Step Test
1. **Click the "Verify" button next to Email**
   - ✓ A bottom sheet should open with title "Verify Email"
   - ✓ Subtitle says "Enter the 6-digit code we sent you"
   - ✓ A toast notification should appear: "OTP sent to your email"

2. **Observe OTP input field**
   - ✓ Large, centered input field for 6-digit code
   - ✓ Input accepts only numeric characters
   - ✓ Shows character counter "0/6" initially
   - ✓ Auto-formats input (can enter 123456 or 1-2-3-4-5-6 style)

3. **Check email for OTP**
   - ✓ Email is received with 6-digit OTP code
   - ✓ Email arrives within 30 seconds of clicking Verify
   - ✓ OTP code is valid for verification

4. **Enter the OTP**
   - Enter the 6-digit code received in email
   - ✓ Input field highlights as you type
   - ✓ Character counter updates to "6/6" when complete

5. **Click the "Verify" button**
   - ✓ Button shows loading spinner
   - ✓ Button becomes disabled while submitting
   - ✓ Input field becomes disabled

6. **Verification Success**
   - ✓ Bottom sheet closes automatically
   - ✓ Toast appears: "Email verified"
   - ✓ Back on profile page, Email row now shows "Verified" badge
   - ✓ Badge is green with success styling

### Expected Result
- Email verification successful
- Profile now displays verified email status
- Verify button is replaced with Verified badge

---

## Test Case 2: Mobile (WhatsApp) Verification Flow - Happy Path

### Setup
1. Log in with a superadmin account
2. Navigate to **Settings > Profile**
3. Locate the **WhatsApp** row in the Verification section

### Expected Initial State
- Mobile number is displayed (prefix + number)
- "Verify" button is visible (or "Verified" badge if already verified)
- No verification state badge present for unverified mobile

### Step-by-Step Test
1. **Click the "Verify" button next to WhatsApp**
   - ✓ A bottom sheet should open with title "Verify WhatsApp"
   - ✓ Subtitle says "Enter the 6-digit code we sent you"
   - ✓ A toast notification should appear: "OTP sent via WhatsApp"

2. **Observe OTP input field**
   - ✓ Large, centered input field for 6-digit code
   - ✓ Input accepts only numeric characters
   - ✓ Shows character counter "0/6" initially

3. **Check WhatsApp for OTP**
   - ✓ WhatsApp message is received with 6-digit OTP code
   - ✓ Message arrives within 30 seconds of clicking Verify
   - ✓ OTP code is valid for verification

4. **Enter the OTP**
   - Enter the 6-digit code received via WhatsApp
   - ✓ Input field highlights as you type
   - ✓ Character counter updates to "6/6" when complete

5. **Click the "Verify" button**
   - ✓ Button shows loading spinner
   - ✓ Button becomes disabled while submitting
   - ✓ Input field becomes disabled

6. **Verification Success**
   - ✓ Bottom sheet closes automatically
   - ✓ Toast appears: "WhatsApp verified"
   - ✓ Back on profile page, WhatsApp row now shows "Verified" badge
   - ✓ Badge is green with success styling

### Expected Result
- Mobile verification successful
- Profile now displays verified mobile status
- Verify button is replaced with Verified badge

---

## Test Case 3: OTP Resend Functionality

### Setup
1. Open Email or WhatsApp verification sheet
2. Wait for initial OTP

### Test Steps
1. **Click "Resend code" link**
   - ✓ Link shows loading spinner
   - ✓ Link text temporarily changes to loading indicator
   - ✓ Toast appears: "OTP sent to your email" or "OTP sent via WhatsApp"

2. **Receive new OTP**
   - ✓ New OTP code arrives in email/WhatsApp
   - ✓ New OTP is different from previous OTP
   - ✓ Previous OTP is invalidated

3. **Enter and verify with new OTP**
   - Enter the new OTP code
   - Click Verify
   - ✓ Verification succeeds with new OTP
   - ✓ Success message appears

### Expected Result
- Resend functionality works properly
- Previous OTP is invalidated
- New OTP can be used for verification

---

## Test Case 4: Invalid OTP Error Handling

### Setup
1. Open Email or WhatsApp verification sheet
2. Receive OTP

### Test Steps
1. **Enter incorrect 6-digit code**
   - Intentionally enter wrong numbers (e.g., 000000)
   - Click Verify
   - ✓ Button shows loading state during submission
   - ✓ After submission completes, error message appears: "Invalid or expired code."
   - ✓ Button returns to normal state (not loading)
   - ✓ Input field is still enabled for retry

2. **Try again with correct OTP**
   - Enter the correct OTP code
   - Click Verify
   - ✓ Verification succeeds
   - ✓ Error message clears

### Expected Result
- Invalid OTP error is properly handled
- User can retry without closing the sheet
- No crashes or exceptions shown

---

## Test Case 5: Expired OTP Handling

### Setup
1. Open Email or WhatsApp verification sheet
2. Receive OTP
3. Note the time

### Test Steps
1. **Wait for OTP to expire** (typically 10-15 minutes)
   - Do NOT close the verification sheet
   - Wait until OTP expiration time passes

2. **Enter expired OTP**
   - Enter the original OTP code received earlier
   - Click Verify
   - ✓ Error appears: "Invalid or expired code."

3. **Use Resend to get new OTP**
   - Click "Resend code"
   - ✓ New OTP arrives
   - ✓ New OTP can be successfully verified

### Expected Result
- Expired OTP is rejected
- User can resend for a new OTP
- Resend OTP works as expected

---

## Test Case 6: Already Verified Email/Mobile

### Setup
1. Have an account with already-verified email and mobile
2. Navigate to **Settings > Profile**

### Expected Behavior
- Email row shows "Verified" badge (not a button)
- WhatsApp row shows "Verified" badge (not a button)
- Badges are displayed with green styling
- No "Verify" button is present
- Cannot click on the verified badge

### Expected Result
- Verified state is properly displayed
- User cannot re-verify an already verified contact

---

## Test Case 7: Missing Email/Mobile Contact

### Setup
1. Create/have account with no email or no mobile number set
2. Navigate to **Settings > Profile**

### Expected Behavior
- For Email: shows "—" (dash) when email is not set
- For WhatsApp: shows "—" (dash) when mobile is not set
- Verify button is disabled (appears grayed out)
- Cannot click disabled button

### Expected Result
- Cannot verify when contact information is missing
- UI properly indicates that verification is not available

---

## Test Case 8: Network Error Handling

### Setup
1. Have internet connectivity available
2. Open verification sheet

### Test Steps
1. **Simulate network error (disconnect internet)**
   - Disconnect wifi/ethernet before OTP request completes
   - ✓ Error message appears instead of success toast
   - ✓ User sees: "Unable to send OTP." or similar error
   - ✓ Resend button remains functional

2. **Reconnect and retry**
   - Reconnect to internet
   - Click "Resend code"
   - ✓ OTP is sent successfully
   - ✓ Verification can proceed

### Expected Result
- Network errors are handled gracefully
- User receives clear error messages
- No crashes or hung states
- Can retry after network is restored

---

## Test Case 9: UI Button States

### Setup
1. Open verification sheet for Email or WhatsApp

### Expected States
1. **Initial State**
   - ✓ Resend button: enabled
   - ✓ Verify button: enabled (once OTP is sent)
   - ✓ OTP input: empty, enabled

2. **During OTP Request**
   - ✓ Resend button shows loading spinner
   - ✓ Resend button: disabled
   - ✓ Verify button: enabled
   - ✓ OTP input: enabled

3. **During OTP Submission**
   - ✓ Verify button shows loading spinner
   - ✓ Verify button: disabled
   - ✓ Resend button: enabled
   - ✓ OTP input: disabled

### Expected Result
- All button states are correct
- Loading indicators show appropriate activity
- User cannot accidentally trigger duplicate requests

---

## Test Case 10: Close Sheet & Reopen

### Setup
1. Open verification sheet
2. Receive OTP

### Test Steps
1. **Close the sheet**
   - Click the X button in sheet header
   - Or swipe down to dismiss (if supported)
   - ✓ Sheet closes properly
   - ✓ Back on profile page

2. **Click Verify again on same contact**
   - ✓ Sheet opens again
   - ✓ New OTP is requested and sent
   - ✓ Toast shows: "OTP sent to..."
   - ✓ Can complete verification with new OTP

### Expected Result
- Sheet can be closed and reopened
- Each time sheet opens, new OTP is requested
- No state leakage between sessions

---

## Test Case 11: Rapid Button Clicks

### Setup
1. Open verification sheet

### Test Steps
1. **Rapidly click "Resend code" multiple times**
   - Click Resend 3-4 times rapidly
   - ✓ Only one OTP request is sent
   - ✓ Loading state prevents duplicate requests
   - ✓ Only one new OTP code is received

2. **Rapidly click "Verify" multiple times**
   - Enter OTP code
   - Click Verify 3-4 times rapidly
   - ✓ Only one verification request is sent
   - ✓ Loading state prevents duplicate requests
   - ✓ Success appears only once, sheet closes only once

### Expected Result
- Rapid clicks are properly debounced/prevented
- No duplicate API requests
- No unexpected behavior

---

## Test Case 12: Profile Sync After Verification

### Setup
1. Verify email or mobile in Superadmin
2. Have another device/session with same account

### Test Steps
1. **Check profile on another device**
   - Log in on another device or browser
   - Navigate to Settings > Profile
   - ✓ Verification status is updated
   - ✓ Verified badge appears on other device
   - ✓ No need to refresh or re-login (eventual consistency)

### Expected Result
- Verification status is synced across devices
- Profile state is consistent

---

## Regression Testing Checklist

Before marking as complete, verify:
- [ ] Other profile settings still work (Edit Profile, Change Password, etc.)
- [ ] Email subscription still works
- [ ] Profile photo upload still works
- [ ] Company details can still be edited
- [ ] Address fields work correctly
- [ ] Logout still works
- [ ] Navigation to other settings sections works
- [ ] Page doesn't show any console errors
- [ ] No performance degradation
- [ ] Dark mode displays correctly
- [ ] Responsive design on small screens

---

## Documentation & Screenshots

For QA sign-off, please include:
- [ ] Screenshots of successful email verification
- [ ] Screenshots of successful mobile verification
- [ ] Screenshot of verified state badges
- [ ] Screenshot of error messages
- [ ] Device/browser info tested on
- [ ] Any issues encountered and how they were resolved

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| QA Tester | | | |
| Product Owner | | | |
