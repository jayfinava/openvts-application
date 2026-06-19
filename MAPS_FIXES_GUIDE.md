# MAPS MODULE DARK MODE FIXES GUIDE
**Implementation Guide for Dark Mode Compatibility**

**Status:** Ready for Implementation  
**Total Fixes:** 12 Critical/High Priority Items  
**Estimated Effort:** 6-9 hours  
**Difficulty:** Low-Medium (mostly color/styling changes)

---

## QUICK REFERENCE: ALL ISSUES & FIXES

| # | Issue | File | Line | Severity | Effort | Status |
|---|-------|------|------|----------|--------|--------|
| 1 | Map background hardcoded light | live_map_screen.dart | 1446 | CRITICAL | 5min | ❌ TODO |
| 2 | History route polylines hardcoded | live_map_screen.dart | 8960-9001 | CRITICAL | 30min | ❌ TODO |
| 3 | Modal drawer ignores theme | open_vts_map_layer_selector.dart | 173 | CRITICAL | 15min | ❌ TODO |
| 4 | Unknown vehicle status invisible | live_map_screen.dart | 11702 | CRITICAL | 10min | ❌ TODO |
| 5 | Geofence opacity too low | live_map_screen.dart | 1382, 1400 | HIGH | 5min | ❌ TODO |
| 6 | Replay timeline hardcoded light | replay_widgets.dart | Multiple | HIGH | 45min | ❌ TODO |
| 7 | History markers not theme-aware | map_markers.dart | 107-129 | HIGH | 20min | ❌ TODO |
| 8 | Replay buttons hardcoded | replay_widgets.dart | Multiple | HIGH | 20min | ❌ TODO |
| 9 | Timeline rail border hardcoded | live_map_screen.dart | 7856, 7880 | MEDIUM | 10min | ❌ TODO |
| 10 | Button colors inconsistent | Multiple | Multiple | MEDIUM | 30min | ❌ TODO |
| 11 | Map constants file | New File | N/A | MEDIUM | 30min | ❌ TODO |
| 12 | Text/numbers/icons audit | Multiple | Multiple | MEDIUM | 45min | ❌ TODO |

---

## FIX #1: MAP BACKGROUND COLOR (CRITICAL - 5 min)

### Current Code (BROKEN)
**File:** `lib/features/live_map/screens/live_map_screen.dart` (Line 1446)

```dart
return Stack(
  children: [
    Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFFE8EEF5),  // ❌ HARDCODED LIGHT BLUE
        child: FlutterMap(
          mapController: _mapController,
          // ...
        ),
      ),
    ),
```

### Why This is Broken
- Light blue (0xFFE8EEF5) becomes invisible on dark map tiles
- Map appears blank until tiles load
- Users see nothing until map tiles are fetched
- Looks like the app is broken

### Fixed Code
```dart
return Stack(
  children: [
    Positioned.fill(
      child: Consumer(
        builder: (context, ref, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final backgroundColor = isDark 
            ? const Color(0xFF0F0D12)    // Dark background from theme
            : const Color(0xFFE8EEF5);   // Light background (original)
          
          return ColoredBox(
            color: backgroundColor,
            child: child!,
          );
        },
        child: FlutterMap(
          mapController: _mapController,
          // ...
        ),
      ),
    ),
```

### Alternative (Better)
```dart
// Add to OpenVtsColors class
static const mapBackgroundLight = Color(0xFFE8EEF5);
static const mapBackgroundDark = Color(0xFF0F0D12);

// Then in the map:
return Stack(
  children: [
    Positioned.fill(
      child: Consumer(
        builder: (context, ref, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return ColoredBox(
            color: isDark ? OpenVtsColors.mapBackgroundDark : OpenVtsColors.mapBackgroundLight,
            child: child!,
          );
        },
        child: FlutterMap(...),
      ),
    ),
```

### Testing
- [ ] Light mode: Background shows light blue briefly
- [ ] Dark mode: Background shows dark color
- [ ] Both modes: Map tiles load over background correctly

---

## FIX #2: HISTORY ROUTE POLYLINES (CRITICAL - 30 min)

### Current Code (BROKEN)
**File:** `lib/features/live_map/screens/live_map_screen.dart` (Lines 8960-9001)

```dart
final historyRoadPolylines = historyPathPoints.isEmpty
    ? const <Polyline>[]
    : _historyRoadPolylines(historyPathPoints);

// Looking at the _historyRoadPolylines method:
List<Polyline> _historyRoadPolylines(List<LatLng> points) {
  return [
    // SELECTED ROUTE - Background
    Polyline(
      points: points,
      strokeWidth: 18,
      color: const Color(0xFFC0CBD3).withValues(alpha: 0.70),  // Light gray
    ),
    
    // SELECTED ROUTE - Middle  
    Polyline(
      points: points,
      strokeWidth: 11,
      color: const Color(0xFF111827).withValues(alpha: 0.90),  // Dark
    ),
    
    // SELECTED ROUTE - Dashed pattern
    Polyline(
      points: points,
      strokeWidth: 7,
      isDashed: true,
      dashArray: const [5, 3],
      color: const Color(0xFFFFFFFF).withValues(alpha: 0.88),  // White
    ),
  ];
}

List<Polyline> _selectedHistoryRoadPolylines(
  SuperadminVehicleHistory? history,
  String? selectedSegmentId,
) {
  // ... logic ...
  
  // UNSELECTED ROUTE - Background (NEARLY INVISIBLE)
  Polyline(
    points: points,
    strokeWidth: 18,
    color: const Color(0xFFD6DEE5).withValues(alpha: 0.50),  // ❌ Very light + 50% = nearly invisible
  ),
  
  // UNSELECTED ROUTE - Middle
  Polyline(
    points: points,
    strokeWidth: 11,
    color: const Color(0xFF8B969F).withValues(alpha: 0.58),  // Medium gray
  ),
  
  // UNSELECTED ROUTE - Dashed (CRITICAL VISIBILITY ISSUE)
  Polyline(
    points: points,
    strokeWidth: 7,
    isDashed: true,
    dashArray: const [5, 3],
    color: const Color(0xFFF8FAFC).withValues(alpha: 0.72),  // ❌ Nearly white = invisible on light maps
  ),
}
```

### Why This is Broken
- Unselected route uses very light colors (nearly white) at low opacity
- On light map tiles, the light colored polyline becomes invisible
- Users cannot see vehicle history routes
- Selected routes show fine but unselected routes disappear

### Fixed Code

**Step 1: Add to OpenVtsColors**
```dart
// In lib/core/theme/open_vts_colors.dart

class MapRouteColors {
  const MapRouteColors._();
  
  // Selected route colors (same for both themes - dark middle line shows on both)
  static const selectedRouteBg = Color(0xFFC0CBD3);
  static const selectedRouteBgOpacity = 0.70;
  static const selectedRouteMiddle = Color(0xFF111827);
  static const selectedRouteMiddleOpacity = 0.90;
  static const selectedRouteDash = Color(0xFFFFFFFF);
  static const selectedRouteDashOpacity = 0.88;
  
  // Unselected route colors (LIGHT MODE)
  static const unselectedRouteBgLight = Color(0xFF6B7280);    // Changed: was 0xFFD6DEE5 (nearly invisible)
  static const unselectedRouteBgOpacityLight = 0.50;
  static const unselectedRouteMiddleLight = Color(0xFF4B5563);
  static const unselectedRouteMiddleOpacityLight = 0.58;
  static const unselectedRouteDashLight = Color(0xFF9CA3AF);  // Changed: was 0xFFF8FAFC (nearly invisible)
  static const unselectedRouteDashOpacityLight = 0.72;
  
  // Unselected route colors (DARK MODE)
  static const unselectedRouteBgDark = Color(0xFF4B5563);
  static const unselectedRouteBgOpacityDark = 0.60;
  static const unselectedRouteMiddleDark = Color(0xFF9CA3AF);
  static const unselectedRouteMiddleOpacityDark = 0.70;
  static const unselectedRouteDashDark = Color(0xFFD1D5DB);
  static const unselectedRouteDashOpacityDark = 0.80;
}
```

**Step 2: Update _historyRoadPolylines**
```dart
List<Polyline> _historyRoadPolylines(List<LatLng> points, BuildContext context) {
  return [
    Polyline(
      points: points,
      strokeWidth: 18,
      color: MapRouteColors.selectedRouteBg.withValues(alpha: MapRouteColors.selectedRouteBgOpacity),
    ),
    Polyline(
      points: points,
      strokeWidth: 11,
      color: MapRouteColors.selectedRouteMiddle.withValues(alpha: MapRouteColors.selectedRouteMiddleOpacity),
    ),
    Polyline(
      points: points,
      strokeWidth: 7,
      isDashed: true,
      dashArray: const [5, 3],
      color: MapRouteColors.selectedRouteDash.withValues(alpha: MapRouteColors.selectedRouteDashOpacity),
    ),
  ];
}
```

**Step 3: Update _selectedHistoryRoadPolylines**
```dart
List<Polyline> _selectedHistoryRoadPolylines(
  SuperadminVehicleHistory? history,
  String? selectedSegmentId,
  BuildContext context,  // ADD: Pass context
) {
  if (history == null || selectedSegmentId == null) {
    return const <Polyline>[];
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  // ... existing logic to extract points ...
  
  return [
    // Unselected route
    Polyline(
      points: points,
      strokeWidth: 18,
      color: (isDark 
        ? MapRouteColors.unselectedRouteBgDark 
        : MapRouteColors.unselectedRouteBgLight).withValues(
        alpha: isDark 
          ? MapRouteColors.unselectedRouteBgOpacityDark 
          : MapRouteColors.unselectedRouteBgOpacityLight
      ),
    ),
    Polyline(
      points: points,
      strokeWidth: 11,
      color: (isDark 
        ? MapRouteColors.unselectedRouteMiddleDark 
        : MapRouteColors.unselectedRouteMiddleLight).withValues(
        alpha: isDark 
          ? MapRouteColors.unselectedRouteMiddleOpacityDark 
          : MapRouteColors.unselectedRouteMiddleOpacityLight
      ),
    ),
    Polyline(
      points: points,
      strokeWidth: 7,
      isDashed: true,
      dashArray: const [5, 3],
      color: (isDark 
        ? MapRouteColors.unselectedRouteDashDark 
        : MapRouteColors.unselectedRouteDashLight).withValues(
        alpha: isDark 
          ? MapRouteColors.unselectedRouteDashOpacityDark 
          : MapRouteColors.unselectedRouteDashOpacityLight
      ),
    ),
  ];
}
```

### Testing
- [ ] Light mode: Unselected routes visible as medium gray
- [ ] Dark mode: Unselected routes visible as lighter gray
- [ ] Selected routes: Always visible (dark middle line)
- [ ] Routes contrast well with light and dark map backgrounds

---

## FIX #3: MAP LAYER SELECTOR MODAL (CRITICAL - 15 min)

### Current Code (BROKEN)
**File:** `lib/shared/widgets/open_vts_map_layer_selector.dart` (Line 173)

```dart
void _showLayerSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,  // ❌ HARDCODED WHITE
    builder: (context) => _MapActionDrawer(
      backgroundColor: Colors.white,  // ❌ HARDCODED WHITE
      handleColor: Colors.black.withValues(alpha: 0.08),
      maxHeightFactor: 0.8,
      child: _MapLayerDrawer(
        initialLayerId: _selectedLayerId,
        onLayerSelected: _selectLayer,
      ),
    ),
  );
}
```

### Why This is Broken
- Modal is always white, even in dark mode
- In dark mode, white modal looks jarring and has contrast issues
- Text colors inside drawer assume white background
- Doesn't follow Material Design 3 guidelines for modals

### Fixed Code
```dart
void _showLayerSelector(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final backgroundColor = isDark 
    ? Theme.of(context).colorScheme.surface 
    : Colors.white;
  final handleColor = isDark 
    ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
    : Colors.black.withValues(alpha: 0.08);
  
  showModalBottomSheet(
    context: context,
    backgroundColor: backgroundColor,
    builder: (context) => _MapActionDrawer(
      backgroundColor: backgroundColor,
      handleColor: handleColor,
      maxHeightFactor: 0.8,
      child: _MapLayerDrawer(
        initialLayerId: _selectedLayerId,
        onLayerSelected: _selectLayer,
      ),
    ),
  );
}
```

### Additional Fixes Required
**Also update text colors inside the drawer to respect theme:**

```dart
// Inside _MapLayerDrawer build method
@override
Widget build(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Map Layers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,  // ✅ Use theme instead of hardcoded
          ),
        ),
        // ... rest of drawer ...
      ],
    ),
  );
}

// For layer buttons:
InkWell(
  onTap: () => _selectLayer(layer),
  child: Container(
    decoration: BoxDecoration(
      color: _selectedLayerId == layer.id 
        ? scheme.primary.withValues(alpha: 0.12)  // Use theme
        : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            layer.name,
            style: TextStyle(color: scheme.onSurface),  // Use theme
          ),
          Text(
            layer.description,
            style: TextStyle(color: scheme.onSurfaceVariant),  // Use theme
          ),
        ],
      ),
    ),
  ),
)
```

### Testing
- [ ] Light mode: Drawer shows white background
- [ ] Dark mode: Drawer shows dark surface color
- [ ] All text readable in both modes
- [ ] Layer buttons clearly visible when selected
- [ ] No jarring contrast in dark mode

---

## FIX #4: UNKNOWN VEHICLE STATUS COLOR (CRITICAL - 10 min)

### Current Code (BROKEN)
**File:** `lib/features/live_map/screens/live_map_screen.dart` (Line 11702)

```dart
Color _vehicleMarkerColor(_VehicleMarkerStatus status) {
  return switch (status) {
    _VehicleMarkerStatus.running => const Color(0xFF20B15A),     // Green
    _VehicleMarkerStatus.idle => const Color(0xFFF59E0B),        // Amber
    _VehicleMarkerStatus.stopped => const Color(0xFFEF4444),     // Red
    _VehicleMarkerStatus.inactive => const Color(0xFF64748B),    // Slate
    _VehicleMarkerStatus.unknown => const Color(0xFF141118),     // ❌ DARK = INVISIBLE ON DARK BG
  };
}

// Same issue in _vehicleRippleColor (Line 11718)
```

### Why This is Broken
- Dark color (0xFF141118) is nearly black
- On dark map backgrounds, marker becomes invisible
- Users cannot see vehicles with unknown status
- Same color used in ripple effect

### Fixed Code

**Add to OpenVtsColors:**
```dart
// In lib/core/theme/open_vts_colors.dart

class OpenVtsColors {
  // ... existing colors ...
  
  // Vehicle status colors
  static const vehicleRunning = Color(0xFF20B15A);
  static const vehicleIdle = Color(0xFFF59E0B);
  static const vehicleStopped = Color(0xFFEF4444);
  static const vehicleInactive = Color(0xFF64748B);
  static const vehicleUnknownLight = Color(0xFF141118);  // Dark for light backgrounds
  static const vehicleUnknownDark = Color(0xFFB8B8B8);   // Light gray for dark backgrounds
}
```

**Fix _vehicleMarkerColor:**
```dart
Color _vehicleMarkerColor(_VehicleMarkerStatus status, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  return switch (status) {
    _VehicleMarkerStatus.running => OpenVtsColors.vehicleRunning,
    _VehicleMarkerStatus.idle => OpenVtsColors.vehicleIdle,
    _VehicleMarkerStatus.stopped => OpenVtsColors.vehicleStopped,
    _VehicleMarkerStatus.inactive => OpenVtsColors.vehicleInactive,
    _VehicleMarkerStatus.unknown => isDark 
      ? OpenVtsColors.vehicleUnknownDark 
      : OpenVtsColors.vehicleUnknownLight,
  };
}
```

**Fix _vehicleRippleColor (same pattern):**
```dart
Color _vehicleRippleColor(_VehicleMarkerStatus status, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  return switch (status) {
    _VehicleMarkerStatus.running => OpenVtsColors.vehicleRunning,
    _VehicleMarkerStatus.idle => OpenVtsColors.vehicleIdle,
    _VehicleMarkerStatus.stopped => OpenVtsColors.vehicleStopped,
    _VehicleMarkerStatus.inactive => OpenVtsColors.vehicleInactive,
    _VehicleMarkerStatus.unknown => isDark 
      ? OpenVtsColors.vehicleUnknownDark 
      : OpenVtsColors.vehicleUnknownLight,
  };
}
```

**Update all callers to pass context:**
```dart
// Find and update all calls to these methods:
// color: _vehicleMarkerColor(status, context),
// color: _vehicleRippleColor(status, context),

// Example in marker rendering:
color: _vehicleMarkerColor(status, context),  // Add context parameter
```

### Testing
- [ ] Light mode: Unknown status shows as dark marker
- [ ] Dark mode: Unknown status shows as light gray marker
- [ ] Both modes: Marker clearly visible on map
- [ ] Ripple effect color also adapts

---

## FIX #5: GEOFENCE OPACITY (HIGH - 5 min)

### Current Code (BROKEN)
**File:** `lib/features/live_map/screens/live_map_screen.dart` (Lines 1382, 1400)

```dart
final geofencePolygons = geofences
    .where((geofence) => !geofence.isCircle && geofence.points.length >= 3)
    .map((geofence) => Polygon(
      points: geofence.points,
      color: const Color(0xFF16A34A).withValues(alpha: 0.12),  // ❌ 12% opacity = barely visible
      borderColor: const Color(0xFF15803D).withValues(alpha: 0.88),
      borderStrokeWidth: 2.2,
    ))

final geofenceCircles = geofences
    .map((geofence) => CircleMarker(
      point: geofence.center!,
      radius: geofence.radiusMeters!,
      useRadiusInMeter: true,
      color: const Color(0xFF16A34A).withValues(alpha: 0.1),  // ❌ 10% opacity = nearly invisible
      borderColor: const Color(0xFF15803D).withValues(alpha: 0.8),
      borderStrokeWidth: 2,
    ))
```

### Why This is Broken
- 10-12% opacity is too faint
- Geofence boundaries are nearly invisible
- Users can't see defined areas
- Border is visible but fill is not

### Fixed Code
```dart
final geofencePolygons = geofences
    .where((geofence) => !geofence.isCircle && geofence.points.length >= 3)
    .map((geofence) => Polygon(
      points: geofence.points,
      color: const Color(0xFF16A34A).withValues(alpha: 0.28),  // ✅ Increased from 0.12 to 0.28
      borderColor: const Color(0xFF15803D).withValues(alpha: 0.88),
      borderStrokeWidth: 2.2,
    ))

final geofenceCircles = geofences
    .map((geofence) => CircleMarker(
      point: geofence.center!,
      radius: geofence.radiusMeters!,
      useRadiusInMeter: true,
      color: const Color(0xFF16A34A).withValues(alpha: 0.25),  // ✅ Increased from 0.1 to 0.25
      borderColor: const Color(0xFF15803D).withValues(alpha: 0.8),
      borderStrokeWidth: 2,
    ))
```

### Testing
- [ ] Light mode: Geofences clearly visible
- [ ] Dark mode: Geofences clearly visible
- [ ] Opacity not too high (still transparent)
- [ ] Border and fill both visible

---

## FIX #6: REPLAY TIMELINE COLORS (HIGH - 45 min)

### Current Code (BROKEN)
**File:** `lib/features/live_map/screens/replay/replay_widgets.dart` (Multiple lines)

```dart
// Line 67: Container color
Container(
  color: const Color(0xFFF7F7F8),  // ❌ Very light gray
  // ...
)

// Line 124: Border color
Border(
  bottom: BorderSide(color: const Color(0xFFE5E7EB)),  // ❌ Light gray
)

// Line 315: Stop marker container
Container(
  color: const Color(0xFFFFFFFF).withValues(alpha: 0.98),  // ❌ Nearly white
  // ...
)

// Line 317: Border on container
border: Border.all(color: const Color(0xFFE6E8EC)),  // ❌ Very light
```

### Why This is Broken
- All hardcoded to light colors
- No dark mode adaptation
- Text on light backgrounds may have poor contrast
- Looks wrong on dark map backgrounds

### Fixed Code

**Step 1: Create constants in open_vts_colors.dart:**
```dart
class ReplayTimelineColors {
  const ReplayTimelineColors._();
  
  // Light mode colors
  static const containerBgLight = Color(0xFFF7F7F8);
  static const containerBorderLight = Color(0xFFE5E7EB);
  static const stopMarkerBgLight = Color(0xFFFFFFFF);
  static const stopMarkerBorderLight = Color(0xFFE6E8EC);
  static const textColorLight = Color(0xFF1F2937);
  
  // Dark mode colors
  static const containerBgDark = Color(0xFF27272A);
  static const containerBorderDark = Color(0xFF3F3F46);
  static const stopMarkerBgDark = Color(0xFF18141D);
  static const stopMarkerBorderDark = Color(0xFF3F3F46);
  static const textColorDark = Color(0xFFFFFFFF);
}
```

**Step 2: Update replay UI widgets:**
```dart
// In replay_widgets.dart, update all hardcoded colors:

@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  // Replace all hardcoded colors with theme-aware versions:
  
  return Container(
    color: isDark 
      ? ReplayTimelineColors.containerBgDark 
      : ReplayTimelineColors.containerBgLight,
    child: Column(
      children: [
        // ... content ...
        Divider(
          color: isDark 
            ? ReplayTimelineColors.containerBorderDark 
            : ReplayTimelineColors.containerBorderLight,
        ),
      ],
    ),
  );
}
```

**Step 3: Update stop marker styling:**
```dart
// Stop marker container
Container(
  decoration: BoxDecoration(
    color: isDark 
      ? ReplayTimelineColors.stopMarkerBgDark 
      : ReplayTimelineColors.stopMarkerBgLight,
    border: Border.all(
      color: isDark 
        ? ReplayTimelineColors.stopMarkerBorderDark 
        : ReplayTimelineColors.stopMarkerBorderLight,
    ),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Text(
          'Stop Details',
          style: TextStyle(
            color: isDark 
              ? ReplayTimelineColors.textColorDark 
              : ReplayTimelineColors.textColorLight,
          ),
        ),
        // ... more content ...
      ],
    ),
  ),
)
```

### Testing
- [ ] Light mode: Containers show light colors
- [ ] Dark mode: Containers show dark colors
- [ ] All text readable in both modes
- [ ] Borders visible in both modes
- [ ] Stop markers clearly distinguished

---

## FIX #7: HISTORY MARKER VISUALS (HIGH - 20 min)

### Current Code (BROKEN)
**File:** `lib/features/live_map/screens/markers/map_markers.dart` (Lines 107-129)

```dart
_HistoryMapMarkerVisuals _historyMapMarkerVisuals(_HistoryMapMarkerType type) {
  return switch (type) {
    _HistoryMapMarkerType.start => _HistoryMapMarkerVisuals(
      outerFill: const Color(0xFF111827),      // Dark - good on light bg
      innerFill: const Color(0xFF111827),      // Dark - good on light bg
      innerBorder: const Color(0xFFFFFFFF),    // White - good on dark inner
      iconColor: const Color(0xFFFFFFFF),      // White - good on dark inner
      ringColor: const Color(0xFF111827),      // Dark
    ),
    
    _HistoryMapMarkerType.stop => _HistoryMapMarkerVisuals(
      outerFill: const Color(0xFFF7F7F8),      // ❌ Very light - invisible on light bg
      innerFill: const Color(0xFFFFFFFF),      // White
      innerBorder: const Color(0xFF9EA7B0),    // Light gray
      iconColor: const Color(0xFF4B5563),      // Medium gray
      ringColor: const Color(0xFF3F3F46),      // Dark gray
    ),
    
    _HistoryMapMarkerType.end => _HistoryMapMarkerVisuals(
      outerFill: const Color(0xFF27272A),      // Very dark - good on light bg
      innerFill: const Color(0xFF27272A),      // Very dark - good on light bg
      innerBorder: const Color(0xFFFFFFFF),    // White - good on dark inner
      iconColor: const Color(0xFFFFFFFF),      // White - good on dark inner
      ringColor: const Color(0xFF27272A),      // Very dark
    ),
  };
}
```

### Why This is Broken
- STOP marker uses light outer fill (0xFFF7F7F8)
- On light map backgrounds, stop marker becomes nearly invisible
- START and END markers work fine (dark on light)
- No adaptation to map background

### Fixed Code
```dart
_HistoryMapMarkerVisuals _historyMapMarkerVisuals(
  _HistoryMapMarkerType type,
  bool isDarkMode,  // Add parameter
) {
  return switch (type) {
    _HistoryMapMarkerType.start => _HistoryMapMarkerVisuals(
      outerFill: const Color(0xFF111827),      // Dark - works on light maps
      innerFill: const Color(0xFF111827),      
      innerBorder: const Color(0xFFFFFFFF),    
      iconColor: const Color(0xFFFFFFFF),      
      ringColor: const Color(0xFF111827),      
    ),
    
    _HistoryMapMarkerType.stop => _HistoryMapMarkerVisuals(
      // Adapt STOP marker colors based on theme
      outerFill: isDarkMode 
        ? const Color(0xFF4B5563)               // Medium gray for dark mode
        : const Color(0xFF1F2937),              // ✅ Changed from 0xFFF7F7F8 (was nearly white)
      innerFill: isDarkMode 
        ? const Color(0xFF6B7280)
        : const Color(0xFFFFFFFF),
      innerBorder: isDarkMode 
        ? const Color(0xFF9CA3AF) 
        : const Color(0xFF9EA7B0),
      iconColor: isDarkMode 
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF4B5563),              // ✅ Changed for better contrast on dark outer fill
      ringColor: isDarkMode 
        ? const Color(0xFF6B7280)
        : const Color(0xFF3F3F46),
    ),
    
    _HistoryMapMarkerType.end => _HistoryMapMarkerVisuals(
      outerFill: const Color(0xFF27272A),      // Very dark - works on light maps
      innerFill: const Color(0xFF27272A),      
      innerBorder: const Color(0xFFFFFFFF),    
      iconColor: const Color(0xFFFFFFFF),      
      ringColor: const Color(0xFF27272A),      
    ),
  };
}
```

**Update all calls to this function:**
```dart
// Find all calls like:
// _historyMapMarkerVisuals(markerType)

// And update to:
final isDarkMode = Theme.of(context).brightness == Brightness.dark;
_historyMapMarkerVisuals(markerType, isDarkMode)
```

### Testing
- [ ] Light mode: START and END markers visible (dark)
- [ ] Light mode: STOP marker visible (now darker)
- [ ] Dark mode: All markers visible with appropriate contrast
- [ ] Dark mode: STOP marker uses medium gray outer fill
- [ ] Icons visible on all marker types in both modes

---

## FIX #8: REPLAY CONTROL BUTTONS (HIGH - 20 min)

### Current Code (BROKEN)
**File:** `lib/features/live_map/screens/replay/replay_widgets.dart`

```dart
// Play button - likely hardcoded
IconButton(
  onPressed: _toggleReplayPlay,
  icon: Icon(
    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
    // No color specified - might use defaults
  ),
)

// Speed selector - likely hardcoded colors
DropdownButton(
  items: [/* items */],
  onChanged: _setReplaySpeed,
  // Likely has hardcoded colors
)

// Timeline seekbar - likely hardcoded
CustomPaint(
  painter: _ReplayTimelinePainter(/* hardcoded colors? */),
)
```

### Why This is Broken
- Button colors likely hardcoded to light
- No theme adaptation
- Seekbar colors may be hardcoded
- Dropdown text may have poor contrast

### Fixed Code

**Add button color handling:**
```dart
// In replay_widgets.dart

IconButton(
  onPressed: _toggleReplayPlay,
  icon: Icon(
    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
    color: Theme.of(context).colorScheme.onSurface,  // ✅ Use theme
  ),
)

// Speed selector with theme
DropdownButton<double>(
  value: _replaySpeed,
  items: const [0.5, 1.0, 1.5, 2.0, 3.0].map((speed) {
    return DropdownMenuItem(
      value: speed,
      child: Text(
        '${speed}x',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,  // ✅ Use theme
        ),
      ),
    );
  }).toList(),
  onChanged: _setReplaySpeed,
  dropdownColor: Theme.of(context).colorScheme.surface,  // ✅ Use theme
)

// Timeline painter with theme colors
CustomPaint(
  painter: _ReplayTimelinePainter(
    isDarkMode: Theme.of(context).brightness == Brightness.dark,
  ),
)
```

### Testing
- [ ] Light mode: Buttons visible with light background
- [ ] Dark mode: Buttons visible with dark background
- [ ] Play/pause icons clearly visible
- [ ] Speed dropdown readable
- [ ] Seekbar thumb clearly visible

---

## FIX #9: TIMELINE RAIL BORDER/DIVIDER (MEDIUM - 10 min)

### Current Code (BROKEN)
**File:** `lib/features/live_map/screens/live_map_screen.dart` (Lines 7856, 7880)

```dart
// Timeline rail border
Border.all(color: const Color(0xFFE5E7EB))  // ❌ Light gray = invisible on dark

// Timeline rail paint (dashed line)
Paint()
  ..color = const Color(0xFFE5E7EB)  // ❌ Light gray for dashed line
  ..strokeWidth = 1.5
```

### Fixed Code
```dart
// Get theme in the build method
final scheme = Theme.of(context).colorScheme;

// Timeline rail border
Border.all(
  color: scheme.outlineVariant,  // ✅ Use theme instead of hardcoded
)

// Timeline rail paint (dashed line)
Paint()
  ..color = scheme.outlineVariant  // ✅ Use theme
  ..strokeWidth = 1.5
```

### Testing
- [ ] Light mode: Border visible as light gray
- [ ] Dark mode: Border visible as medium gray
- [ ] Dashed line follows timeline clearly

---

## FIX #10: BUTTON STYLING AUDIT (MEDIUM - 30 min)

### Issue
Multiple buttons across the map UI use inconsistent color logic.

### Approach
1. Audit all button definitions
2. Create a unified button styling pattern
3. Replace all hardcoded button colors

### Files to Review
- `live_map_screen.dart` - Close button, North reset, side buttons
- `map_drawers.dart` - All side buttons
- `replay_widgets.dart` - Replay controls
- `open_vts_map_layer_selector.dart` - Layer selection buttons

### Pattern to Apply

```dart
// GOOD PATTERN (theme-aware)
Ink(
  decoration: BoxDecoration(
    color: scheme.surface,              // ✅ Use theme
    shape: BoxShape.circle,
    border: Border.all(
      color: scheme.outlineVariant,    // ✅ Use theme
    ),
  ),
  child: Icon(
    Icons.icon_name,
    color: scheme.onSurface,           // ✅ Use theme
  ),
)

// BAD PATTERN (hardcoded)
Ink(
  decoration: BoxDecoration(
    color: Colors.white,               // ❌ Hardcoded
    shape: BoxShape.circle,
    border: Border.all(
      color: Colors.black.withValues(alpha: 0.1),  // ❌ Hardcoded
    ),
  ),
  child: Icon(
    Icons.icon_name,
    color: Colors.black,               // ❌ Hardcoded
  ),
)
```

### Checklist
- [ ] Close button colors reviewed
- [ ] North reset button colors reviewed
- [ ] Side buttons colors reviewed
- [ ] Layer selector button colors reviewed
- [ ] Filter buttons colors reviewed
- [ ] All buttons use `scheme.*` colors, not `Color(0xFF...)`

---

## FIX #11: MAP COLOR CONSTANTS FILE (MEDIUM - 30 min)

### Current State
Map colors are scattered throughout multiple files with hardcoded values.

### Proposed Solution
Create a centralized constants file for all map-specific colors.

### New File
**File:** `lib/core/theme/map_colors.dart`

```dart
import 'package:flutter/material.dart';

/// Map-specific color constants for both light and dark modes.
class MapColors {
  const MapColors._();
  
  // ============ MAP BACKGROUND ============
  static const mapBackgroundLight = Color(0xFFE8EEF5);
  static const mapBackgroundDark = Color(0xFF0F0D12);
  
  // ============ VEHICLE STATUS COLORS ============
  static const vehicleRunning = Color(0xFF20B15A);      // Green
  static const vehicleIdle = Color(0xFFF59E0B);         // Amber
  static const vehicleStopped = Color(0xFFEF4444);      // Red
  static const vehicleInactive = Color(0xFF64748B);     // Slate
  static const vehicleUnknownLight = Color(0xFF141118); // Dark for light mode
  static const vehicleUnknownDark = Color(0xFFB8B8B8);  // Light gray for dark mode
  
  // ============ GEOFENCE OVERLAY ============
  static const geofenceFillColor = Color(0xFF16A34A);
  static const geofenceFillOpacity = 0.28;              // Increased from 0.12
  static const geofenceBorderColor = Color(0xFF15803D);
  static const geofenceBorderOpacity = 0.88;
  
  // ============ POI OVERLAY ============
  // Add when implementing POI colors
  
  // ============ ROUTE POLYLINES ============
  // Selected route (light + dark compatible)
  static const routeSelectedBg = Color(0xFFC0CBD3);
  static const routeSelectedBgOpacity = 0.70;
  static const routeSelectedMiddle = Color(0xFF111827);
  static const routeSelectedMiddleOpacity = 0.90;
  static const routeSelectedDash = Color(0xFFFFFFFF);
  static const routeSelectedDashOpacity = 0.88;
  
  // Unselected route (light mode)
  static const routeUnselectedBgLight = Color(0xFF6B7280);
  static const routeUnselectedBgOpacityLight = 0.50;
  static const routeUnselectedMiddleLight = Color(0xFF4B5563);
  static const routeUnselectedMiddleOpacityLight = 0.58;
  static const routeUnselectedDashLight = Color(0xFF9CA3AF);
  static const routeUnselectedDashOpacityLight = 0.72;
  
  // Unselected route (dark mode)
  static const routeUnselectedBgDark = Color(0xFF4B5563);
  static const routeUnselectedBgOpacityDark = 0.60;
  static const routeUnselectedMiddleDark = Color(0xFF9CA3AF);
  static const routeUnselectedMiddleOpacityDark = 0.70;
  static const routeUnselectedDashDark = Color(0xFFD1D5DB);
  static const routeUnselectedDashOpacityDark = 0.80;
  
  // ============ HISTORY MARKERS ============
  // Start marker
  static const historyStartOuter = Color(0xFF111827);
  static const historyStartInner = Color(0xFF111827);
  static const historyStartBorder = Color(0xFFFFFFFF);
  static const historyStartIcon = Color(0xFFFFFFFF);
  
  // Stop marker (light mode)
  static const historyStopOuterLight = Color(0xFF1F2937);
  static const historyStopInnerLight = Color(0xFFFFFFFF);
  static const historyStopBorderLight = Color(0xFF9EA7B0);
  static const historyStopIconLight = Color(0xFF4B5563);
  
  // Stop marker (dark mode)
  static const historyStopOuterDark = Color(0xFF4B5563);
  static const historyStopInnerDark = Color(0xFF6B7280);
  static const historyStopBorderDark = Color(0xFF9CA3AF);
  static const historyStopIconDark = Color(0xFFE5E7EB);
  
  // End marker
  static const historyEndOuter = Color(0xFF27272A);
  static const historyEndInner = Color(0xFF27272A);
  static const historyEndBorder = Color(0xFFFFFFFF);
  static const historyEndIcon = Color(0xFFFFFFFF);
  
  // ============ REPLAY TIMELINE ============
  // Light mode
  static const replayContainerBgLight = Color(0xFFF7F7F8);
  static const replayContainerBorderLight = Color(0xFFE5E7EB);
  static const replayStopMarkerBgLight = Color(0xFFFFFFFF);
  static const replayStopMarkerBorderLight = Color(0xFFE6E8EC);
  
  // Dark mode
  static const replayContainerBgDark = Color(0xFF27272A);
  static const replayContainerBorderDark = Color(0xFF3F3F46);
  static const replayStopMarkerBgDark = Color(0xFF18141D);
  static const replayStopMarkerBorderDark = Color(0xFF3F3F46);
  
  // ============ HELPER METHODS ============
  
  /// Get map background color based on theme
  static Color mapBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? mapBackgroundDark : mapBackgroundLight;
  }
  
  /// Get vehicle marker color based on status and theme
  static Color vehicleMarkerColor(
    _VehicleMarkerStatus status,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      _VehicleMarkerStatus.running => vehicleRunning,
      _VehicleMarkerStatus.idle => vehicleIdle,
      _VehicleMarkerStatus.stopped => vehicleStopped,
      _VehicleMarkerStatus.inactive => vehicleInactive,
      _VehicleMarkerStatus.unknown => isDark 
        ? vehicleUnknownDark 
        : vehicleUnknownLight,
    };
  }
  
  /// Get route unselected colors based on theme
  static Map<String, dynamic> routeUnselectedColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return {
      'bg': isDark ? routeUnselectedBgDark : routeUnselectedBgLight,
      'bgOpacity': isDark ? routeUnselectedBgOpacityDark : routeUnselectedBgOpacityLight,
      'middle': isDark ? routeUnselectedMiddleDark : routeUnselectedMiddleLight,
      'middleOpacity': isDark ? routeUnselectedMiddleOpacityDark : routeUnselectedMiddleOpacityLight,
      'dash': isDark ? routeUnselectedDashDark : routeUnselectedDashLight,
      'dashOpacity': isDark ? routeUnselectedDashOpacityDark : routeUnselectedDashOpacityLight,
    };
  }
}
```

### Usage
```dart
// Instead of:
ColoredBox(
  color: const Color(0xFFE8EEF5),  // ❌ Hardcoded
)

// Use:
ColoredBox(
  color: MapColors.mapBackground(context),  // ✅ Centralized and theme-aware
)
```

### Testing
- [ ] All map colors now reference MapColors constants
- [ ] No hardcoded 0xFF... colors in map files
- [ ] Helper methods work correctly
- [ ] Colors adapt based on theme

---

## FIX #12: TEXT/NUMBERS/ICONS AUDIT (MEDIUM - 45 min)

### Approach
Audit all text, numbers, and icons to ensure they use theme colors.

### Files to Audit
1. `live_map_screen.dart` - All text labels and values
2. `map_drawers.dart` - All drawer text and icons
3. `replay_widgets.dart` - All replay UI text
4. `map_markers.dart` - All marker labels
5. `open_vts_map_layer_selector.dart` - All layer selection text

### Checklist

#### Text Colors
- [ ] All text uses `scheme.onSurface` or `scheme.onSurfaceVariant` (not hardcoded)
- [ ] Headers use `textTheme.titleLarge`/`titleMedium` (theme-based)
- [ ] Labels use `textTheme.labelMedium` (theme-based)
- [ ] Body text uses `textTheme.bodyMedium` (theme-based)
- [ ] No hardcoded `Color(0xFF...)` for text

#### Numbers
- [ ] Speed values use `scheme.onSurface`
- [ ] Distance values use `scheme.onSurfaceVariant`
- [ ] Timestamps use theme colors
- [ ] Counts use appropriate theme color

#### Icons
- [ ] All icons use `scheme.onSurface` for primary icons
- [ ] Secondary icons use `scheme.onSurfaceVariant` for muted effect
- [ ] Status icons use appropriate vehicle status colors
- [ ] No hardcoded black or white icons (except where intentional)

#### Specific Items to Check

```dart
// Examples to verify:
// Vehicle name text
Text(
  vehicle.name,
  style: TextStyle(
    color: scheme.onSurface,  // ✅ Good
    // NOT color: Color(0xFF141118),  // ❌ Bad
  ),
)

// Vehicle speed value
Text(
  '${vehicle.speed} km/h',
  style: TextStyle(
    color: scheme.onSurfaceVariant,  // ✅ Good for secondary info
  ),
)

// Vehicle status icon
Icon(
  statusIcon,
  color: _vehicleMarkerColor(status, context),  // ✅ Good - uses vehicle color
)

// Close button icon
Icon(
  Icons.close,
  color: scheme.onSurface,  // ✅ Good
)
```

### Testing
- [ ] Light mode: All text readable on light backgrounds
- [ ] Dark mode: All text readable on dark backgrounds
- [ ] All numbers visible and readable
- [ ] All icons clearly visible
- [ ] No contrast issues with any text/numbers/icons

---

## IMPLEMENTATION ORDER

### Phase 1: Critical Fixes (Day 1)
1. Fix #1: Map background color (5 min)
2. Fix #3: Map layer selector modal (15 min)
3. Fix #4: Unknown vehicle status color (10 min)
4. Fix #5: Geofence opacity (5 min)

**Subtotal: 35 minutes**

### Phase 2: High Priority Fixes (Day 1-2)
5. Fix #2: History route polylines (30 min)
6. Fix #7: History marker visuals (20 min)
7. Fix #8: Replay control buttons (20 min)

**Subtotal: 70 minutes**

### Phase 3: Medium Priority Fixes (Day 2)
8. Fix #6: Replay timeline colors (45 min)
9. Fix #9: Timeline rail border (10 min)
10. Fix #11: Map color constants file (30 min)

**Subtotal: 85 minutes**

### Phase 4: Audit & Cleanup (Day 2-3)
11. Fix #10: Button styling audit (30 min)
12. Fix #12: Text/numbers/icons audit (45 min)

**Subtotal: 75 minutes**

### Phase 5: Testing (Day 3)
- Comprehensive dark mode testing
- Light mode regression testing
- Across all roles (Admin, User, SuperAdmin)

---

## TESTING CHECKLIST

### Before Merging

#### Dark Mode Testing
- [ ] Map background correct in light and dark mode
- [ ] All vehicle markers visible
- [ ] History routes visible in both modes
- [ ] Geofence overlays visible with good opacity
- [ ] All text readable in both modes
- [ ] All numbers visible
- [ ] All icons visible
- [ ] All buttons clickable and visible
- [ ] All modals respect theme
- [ ] Replay UI readable in both modes

#### Light Mode Regression Testing
- [ ] All features still work in light mode
- [ ] No colors broken for light mode
- [ ] Contrast still good in light mode
- [ ] Icons still visible
- [ ] Text still readable

#### Cross-Role Testing
- [ ] Admin map works (limited overlays)
- [ ] User map works (full overlays)
- [ ] SuperAdmin map works (all features)

#### Functionality Testing
- [ ] Markers update smoothly
- [ ] Clustering works
- [ ] Selection works
- [ ] History timeline works
- [ ] Replay works
- [ ] Filters work
- [ ] Overlays toggle correctly

---

## SUMMARY

This guide provides detailed, step-by-step fixes for all critical and high-priority dark mode issues in the Maps module. Each fix includes:

1. Current problematic code
2. Explanation of why it's broken
3. Fixed code with explanations
4. Testing checklist

**Total estimated effort: 6-9 hours**

Follow the implementation order for best results, test thoroughly after each phase, and get final approval before merging to main.

