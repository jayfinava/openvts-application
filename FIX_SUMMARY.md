# Flutter Mobile Driver Create Dropdown Fix

## Problem
The Flutter mobile application's driver create form had incomplete state/city dropdown functionality:
- **India states loaded correctly** (fallback data worked)
- **Other countries (Angola, UAE, Nigeria, Pakistan) showed empty state search**
- The web application shows states correctly for all countries

## Root Cause Analysis

### API Response Contract
The backend API returns states and countries with a consistent structure:

```json
{
  "status": "success",
  "data": {
    "action": true,
    "message": "States fetched successfully",
    "data": [
      { "name": "State Name", "isoCode": "XX" }
    ]
  },
  "timestamp": "2026-06-04T11:17:14.886Z"
}
```

Example responses tested:
- **India**: `/api/states/IN` → Returns 36 states with `isoCode` field
- **Angola**: `/api/states/AO` → Returns 18 provinces with `isoCode` field  
- **UAE**: `/api/states/AE` → Returns 7 emirates with `isoCode` field
- **Nigeria**: `/api/states/NG` → Returns 37 states with `isoCode` field
- **Pakistan**: `/api/states/PK` → Returns 8 states with `isoCode` field

Cities endpoint similarly returns: `{ "name": "City", "stateCode": "XX", "countryCode": "YY" }`

### The Issue
The Flutter mobile parser (`UserDriverStateOption` and `UserDriverCountryOption` classes) was looking for state/country codes in these field names:
- For countries: `countryCode`, `country_code`, `code`, `iso2`, ~~but NOT `isoCode`~~
- For states: `stateCode`, `state_code`, `code`, `iso2`, ~~but NOT `isoCode`~~

When parsing API response items, if the code field wasn't found in the expected names, the parser would:
1. Use an empty string as the value
2. Filter out entries with empty values
3. Result: return empty state/country lists for API responses

**Note**: India had fallback data in `LocationData.statesByCountry['IN']`, which is why it worked as a fallback when API parsing failed.

## Solution

Added `isoCode` and `iso_code` to the field name search lists in both parsers:

### Changes Made

**File**: `lib/features/user/models/user_driver_model.dart`

1. **UserDriverCountryOption** (lines 674-682):
   - Added `'isoCode'` and `'iso_code'` to the value field lookup
   - Now searches: `countryCode`, `country_code`, `code`, `iso2`, `isoCode`, `iso_code`, `country`

2. **UserDriverStateOption** (lines 800-814):
   - Added `'isoCode'` and `'iso_code'` to the value field lookup  
   - Now searches: `stateCode`, `state_code`, `code`, `iso2`, `isoCode`, `iso_code`, `state`, `value`, `id`, `provinceCode`, `province_code`, `regionCode`, `region_code`

## API Contract Alignment

The solution ensures Flutter mobile uses the same API contract as the web application:
- ✅ Endpoint: `/api/states/{countryCode}` and `/api/cities/{countryCode}/{stateCode}`
- ✅ Response format: Nested under `data.data.data`
- ✅ Field names: Recognizes `isoCode` for country/state codes
- ✅ Field names: Recognizes `name` for country/state display labels
- ✅ Dropdown behavior: Shows loaded options, searches within them, retries on failure

## Expected Outcomes After Fix

1. ✅ Country dropdown shows all countries from API
2. ✅ Selecting a country fetches and displays that country's states
3. ✅ Works for all countries including:
   - India (36 states)
   - Angola (18 provinces)
   - UAE (7 emirates)
   - Nigeria (37 states)
   - Pakistan (8 states)
4. ✅ Selecting a state fetches and displays that state's cities
5. ✅ Fallback data from `LocationData` used only as last resort if API fails
6. ✅ No breaking changes to create or edit driver flows

## Testing

All countries should now load states correctly:
- Navigate to: User → Accounts → Driver → Create New Driver
- Select different countries and verify states appear
- Select a state and verify cities appear
- Save a new driver with location data to confirm payload is correct
