import 'package:dio/dio.dart' show Dio, BaseOptions;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../../core/theme/open_vts_colors.dart';
import '../../../../../../core/theme/open_vts_radius.dart';
import '../../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../../core/theme/open_vts_typography.dart';
import '../../../../../../shared/helpers/toast_helper.dart';
import '../../../../../../shared/widgets/open_vts_button.dart';
import '../../../../../../shared/widgets/open_vts_map_layer_selector.dart';
import '../../../../controllers/user_landmark_geometry_editor_controller.dart';
import '../../../../controllers/user_providers.dart';
import '../../../../models/user_landmark_model.dart';
import '../../widgets/user_landmark_measurement_chip.dart';

/// Result returned from the geometry editor on save.
class UserGeofenceEditorResult {
  const UserGeofenceEditorResult({required this.geodata, this.toleranceM});

  final UserGeofenceGeoData geodata;
  final double? toleranceM;
}

/// Full-screen mobile-first geofence geometry editor. Owns no geometry logic
/// itself — every mutation routes through
/// [UserLandmarkGeometryEditorController].
class UserGeofenceEditorScreen extends ConsumerStatefulWidget {
  const UserGeofenceEditorScreen({
    super.key,
    required this.initialMode,
    this.initialGeodata,
    this.initialToleranceM,
    this.initialCenter,
    this.title = 'Draw geometry',
  });

  final UserGeofenceEditorMode initialMode;
  final UserGeofenceGeoData? initialGeodata;
  final double? initialToleranceM;
  final LatLng? initialCenter;
  final String title;

  @override
  ConsumerState<UserGeofenceEditorScreen> createState() =>
      _UserGeofenceEditorScreenState();
}

class _UserGeofenceEditorScreenState
    extends ConsumerState<UserGeofenceEditorScreen> {
  late final UserLandmarkGeometryEditorArgs _args;
  late final MapController _mapController;
  late final TextEditingController _searchCtrl;
  late final Dio _nominatimDio;
  bool _hydrated = false;
  String _selectedLayerId = 'google-road';
  List<_NominatimSearchResult> _searchResults = [];
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    _args = UserLandmarkGeometryEditorArgs(
      initialMode: widget.initialMode,
      initialCenterLat: widget.initialCenter?.latitude,
      initialCenterLon: widget.initialCenter?.longitude,
      initialZoom: 14,
    );
    _mapController = MapController();
    _searchCtrl = TextEditingController();
    _nominatimDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent': 'OpenVTS-Mobile/1.0 (geofence-search)',
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(userLandmarkGeometryEditorControllerProvider(_args).notifier)
          .loadFromExistingGeodata(
            widget.initialGeodata,
            toleranceM: widget.initialToleranceM,
            cameraCenter: widget.initialCenter,
          );
      _hydrated = true;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleMapTap(LatLng point) {
    ref
        .read(userLandmarkGeometryEditorControllerProvider(_args).notifier)
        .tapMap(UserGeoPoint(lat: point.latitude, lon: point.longitude));
  }

  void _handleSave() {
    final controller = ref.read(
      userLandmarkGeometryEditorControllerProvider(_args).notifier,
    );
    final error = controller.validate();
    if (error != null) {
      ToastHelper.showError(error, context: context);
      return;
    }
    final geo = controller.buildGeofenceGeoData();
    if (geo == null) return;
    final state = ref.read(userLandmarkGeometryEditorControllerProvider(_args));
    Navigator.of(context).pop(
      UserGeofenceEditorResult(geodata: geo, toleranceM: state.toleranceM),
    );
  }

  Future<void> _searchPlace() async {
    final query = _searchCtrl.text.trim();
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searchLoading = true);
    try {
      final response = await _nominatimDio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'addressdetails': 0,
        },
      );

      if (!mounted) return;

      final results = <_NominatimSearchResult>[];
      if (response.data is List) {
        for (final item in response.data!) {
          if (item is Map<String, dynamic>) {
            final lat = double.tryParse(item['lat'].toString());
            final lon = double.tryParse(item['lon'].toString());
            if (lat != null && lon != null) {
              results.add(_NominatimSearchResult(
                label: item['display_name'] ?? '',
                lat: lat,
                lon: lon,
              ));
            }
          }
        }
      }

      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
    }
  }

  void _selectSearchResult(_NominatimSearchResult result) {
    final point = LatLng(result.lat, result.lon);
    try {
      _mapController.move(point, _mapController.camera.zoom);
    } catch (_) {}

    final controller = ref.read(
      userLandmarkGeometryEditorControllerProvider(_args).notifier,
    );
    final state = ref.read(userLandmarkGeometryEditorControllerProvider(_args));

    if (state.editorMode == UserGeofenceEditorMode.circle &&
        state.circleCenter == null) {
      controller
          .tapMap(UserGeoPoint(lat: point.latitude, lon: point.longitude));
    }

    _searchCtrl.clear();
    setState(() => _searchResults = []);
  }

  MapLayerOption _getSelectedLayer() {
    final layer = mapLayerOptionById(_selectedLayerId);
    return layer ?? primaryMapLayerOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(userLandmarkGeometryEditorControllerProvider(_args));
    final controller = ref.read(
      userLandmarkGeometryEditorControllerProvider(_args).notifier,
    );

    return Scaffold(
      backgroundColor: OpenVtsColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _EditorTopBar(
              title: widget.title,
              onCancel: () => Navigator.of(context).maybePop(),
              onSave: _hydrated ? _handleSave : null,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: widget.initialCenter ??
                            const LatLng(20.5937, 78.9629),
                        initialZoom: widget.initialCenter == null ? 5 : 14,
                        minZoom: 3,
                        maxZoom: 19,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.drag |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom |
                              InteractiveFlag.scrollWheelZoom,
                        ),
                        onTap: (_, point) => _handleMapTap(point),
                      ),
                      children: _layersFor(state),
                    ),
                  ),
                  // Top row: shape selector (left/center) and layer button (right)
                  Positioned(
                    top: OpenVtsSpacing.sm,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: OpenVtsSpacing.md,
                              ),
                              child: _ModeToggleBar(
                                mode: state.editorMode,
                                onSelect: controller.setMode,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              right: OpenVtsSpacing.sm,
                            ),
                            child: OpenVtsMapLayerSelectorButton(
                              selectedLayerId: _selectedLayerId,
                              onLayerSelected: (layer) {
                                setState(() => _selectedLayerId = layer.id);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Search bar: below shape selector row
                  Positioned(
                    top: OpenVtsSpacing.sm + 56,
                    left: OpenVtsSpacing.sm,
                    right: OpenVtsSpacing.sm,
                    child: _SearchBar(
                      controller: _searchCtrl,
                      isLoading: _searchLoading,
                      results: _searchResults,
                      onSearch: _searchPlace,
                      onSelectResult: _selectSearchResult,
                    ),
                  ),
                  // Measurement chip: below search bar
                  if (state.measurementSummary != null)
                    Positioned(
                      top: OpenVtsSpacing.sm + 112,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: UserLandmarkMeasurementChip(
                          label: state.measurementSummary!,
                        ),
                      ),
                    ),
                  // Editor map controls (zoom, undo, redo, etc.)
                  Positioned(
                    right: OpenVtsSpacing.sm,
                    top: OpenVtsSpacing.sm + 160,
                    child: _EditorMapControls(
                      onZoomIn: () => _mapController.move(
                        _mapController.camera.center,
                        (_mapController.camera.zoom + 1).clamp(3.0, 19.0),
                      ),
                      onZoomOut: () => _mapController.move(
                        _mapController.camera.center,
                        (_mapController.camera.zoom - 1).clamp(3.0, 19.0),
                      ),
                      canUndo: state.canUndo,
                      canRedo: state.canRedo,
                      onUndo: state.canUndo ? controller.undo : null,
                      onRedo: state.canRedo ? controller.redo : null,
                      onClear: controller.clear,
                      showLockSquare:
                          state.editorMode == UserGeofenceEditorMode.rectangle,
                      lockSquare: state.lockSquare,
                      onToggleLockSquare: () =>
                          controller.setLockSquare(!state.lockSquare),
                    ),
                  ),
                ],
              ),
            ),
            _BottomEditorPanel(
              state: state,
              controller: controller,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _layersFor(UserLandmarkGeometryEditorState state) {
    final selectedLayer = _getSelectedLayer();
    final layers = <Widget>[
      TileLayer(
        key: ValueKey<String>(_selectedLayerId),
        urlTemplate: selectedLayer.url,
        subdomains: selectedLayer.subdomains,
        userAgentPackageName: 'com.openvts.mobile',
      ),
    ];

    // Mode-specific preview layers.
    switch (state.editorMode) {
      case UserGeofenceEditorMode.circle:
        if (state.circleCenter != null) {
          final center = state.circleCenter!.toLatLng();
          if ((state.circleRadiusM ?? 0) > 0) {
            layers.add(CircleLayer(circles: [
              CircleMarker(
                point: center,
                radius: state.circleRadiusM!,
                useRadiusInMeter: true,
                color: OpenVtsColors.info.withValues(alpha: 0.18),
                borderColor: OpenVtsColors.brandInk,
                borderStrokeWidth: 2,
              ),
            ]));
          }
          layers.add(MarkerLayer(markers: [_centerMarker(center)]));
        }
        break;
      case UserGeofenceEditorMode.polygon:
        final pts = state.points.map((p) => p.toLatLng()).toList();
        if (pts.length >= 3) {
          layers.add(PolygonLayer(polygons: [
            Polygon(
              points: pts,
              color: OpenVtsColors.info.withValues(alpha: 0.18),
              borderColor: OpenVtsColors.brandInk,
              borderStrokeWidth: 1.6,
            ),
          ]));
        }
        if (pts.length >= 2) {
          layers.add(PolylineLayer(polylines: [
            Polyline(
              points: pts,
              color: OpenVtsColors.brandInk,
              strokeWidth: 1.6,
            ),
          ]));
        }
        layers.add(MarkerLayer(
          markers: [
            for (var i = 0; i < pts.length; i++)
              _vertexMarker(
                pts[i],
                index: i,
                isSelected: state.selectedVertexIndex == i,
                onTap: () => controller(state).selectVertex(i),
              ),
          ],
        ));
        break;
      case UserGeofenceEditorMode.rectangle:
        final corners =
            state.rectangleCorners.map((p) => p.toLatLng()).toList();
        if (corners.length == 4) {
          layers.add(PolygonLayer(polygons: [
            Polygon(
              points: corners,
              color: OpenVtsColors.info.withValues(alpha: 0.18),
              borderColor: OpenVtsColors.brandInk,
              borderStrokeWidth: 1.6,
            ),
          ]));
          layers.add(MarkerLayer(
            markers: [for (final c in corners) _cornerMarker(c)],
          ));
        } else if (state.rectangleStart != null) {
          layers.add(MarkerLayer(
            markers: [_cornerMarker(state.rectangleStart!.toLatLng())],
          ));
        }
        break;
      case UserGeofenceEditorMode.line:
        final pts = state.points.map((p) => p.toLatLng()).toList();
        if (pts.length >= 2) {
          layers.add(PolylineLayer(polylines: [
            Polyline(
              points: pts,
              color: OpenVtsColors.brandInk,
              strokeWidth: 3,
            ),
          ]));
        }
        layers.add(MarkerLayer(
          markers: [
            for (var i = 0; i < pts.length; i++)
              _vertexMarker(
                pts[i],
                index: i,
                isSelected: state.selectedVertexIndex == i,
                onTap: () => controller(state).selectVertex(i),
              ),
          ],
        ));
        break;
      case UserGeofenceEditorMode.view:
        break;
    }
    return layers;
  }

  UserLandmarkGeometryEditorController controller(
    UserLandmarkGeometryEditorState _,
  ) =>
      ref.read(userLandmarkGeometryEditorControllerProvider(_args).notifier);

  Marker _centerMarker(LatLng point) => Marker(
        point: point,
        width: 18,
        height: 18,
        child: Container(
          decoration: BoxDecoration(
            color: OpenVtsColors.brandInk,
            shape: BoxShape.circle,
            border: Border.all(color: OpenVtsColors.white, width: 2),
          ),
        ),
      );

  Marker _cornerMarker(LatLng point) => Marker(
        point: point,
        width: 16,
        height: 16,
        child: Container(
          decoration: BoxDecoration(
            color: OpenVtsColors.brandInk,
            border: Border.all(color: OpenVtsColors.white, width: 2),
          ),
        ),
      );

  Marker _vertexMarker(
    LatLng point, {
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Marker(
      point: point,
      width: 22,
      height: 22,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? OpenVtsColors.brandInk : OpenVtsColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: OpenVtsColors.brandInk,
              width: isSelected ? 2 : 1.4,
            ),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: OpenVtsTypography.meta.copyWith(
                color:
                    isSelected ? OpenVtsColors.white : OpenVtsColors.brandInk,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({
    required this.title,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        OpenVtsSpacing.sm,
        OpenVtsSpacing.xs,
        OpenVtsSpacing.sm,
        OpenVtsSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: OpenVtsColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: OpenVtsColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 18,
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
          ),
          Expanded(
            child: Text(
              title,
              style: OpenVtsTypography.titleSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            height: 36,
            child: OpenVtsButton(
              label: 'Save',
              onPressed: onSave,
              height: 36,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggleBar extends StatelessWidget {
  const _ModeToggleBar({required this.mode, required this.onSelect});

  final UserGeofenceEditorMode mode;
  final ValueChanged<UserGeofenceEditorMode> onSelect;

  static const _modes = <UserGeofenceEditorMode>[
    UserGeofenceEditorMode.circle,
    UserGeofenceEditorMode.polygon,
    UserGeofenceEditorMode.rectangle,
    UserGeofenceEditorMode.line,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OpenVtsColors.brandInk,
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        border: Border.all(color: OpenVtsColors.white),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in _modes)
            _ModeChip(
              icon: _iconFor(m),
              label: m.label,
              selected: m == mode,
              onTap: () => onSelect(m),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(UserGeofenceEditorMode m) {
    switch (m) {
      case UserGeofenceEditorMode.circle:
        return Icons.radio_button_unchecked;
      case UserGeofenceEditorMode.polygon:
        return Icons.hexagon_outlined;
      case UserGeofenceEditorMode.rectangle:
        return Icons.crop_square;
      case UserGeofenceEditorMode.line:
        return Icons.show_chart;
      case UserGeofenceEditorMode.view:
        return Icons.visibility_outlined;
    }
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? OpenVtsColors.brandInk : Colors.transparent,
          borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? OpenVtsColors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: OpenVtsTypography.meta.copyWith(
                color: selected
                    ? OpenVtsColors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorMapControls extends StatelessWidget {
  const _EditorMapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.showLockSquare,
    required this.lockSquare,
    required this.onToggleLockSquare,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onClear;
  final bool showLockSquare;
  final bool lockSquare;
  final VoidCallback onToggleLockSquare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OpenVtsColors.brandInk,
        borderRadius: BorderRadius.circular(OpenVtsRadius.md),
        border: Border.all(color: OpenVtsColors.white),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(icon: Icons.add, tooltip: 'Zoom in', onTap: onZoomIn),
          const _ControlDivider(),
          _ControlButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onTap: onZoomOut,
          ),
          const _ControlDivider(),
          _ControlButton(
            icon: Icons.undo,
            tooltip: 'Undo',
            onTap: onUndo,
            enabled: canUndo,
          ),
          _ControlButton(
            icon: Icons.redo,
            tooltip: 'Redo',
            onTap: onRedo,
            enabled: canRedo,
          ),
          const _ControlDivider(),
          _ControlButton(
            icon: Icons.layers_clear_outlined,
            tooltip: 'Clear',
            onTap: onClear,
          ),
          if (showLockSquare) ...[
            const _ControlDivider(),
            _ControlButton(
              icon: lockSquare ? Icons.lock : Icons.lock_open,
              tooltip: lockSquare ? 'Unlock square' : 'Lock square',
              onTap: onToggleLockSquare,
              active: lockSquare,
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlDivider extends StatelessWidget {
  const _ControlDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: OpenVtsColors.divider);
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool enabled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled || onTap == null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          color: active
              ? OpenVtsColors.brandInk.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Icon(
            icon,
            size: 16,
            color: disabled
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _BottomEditorPanel extends StatelessWidget {
  const _BottomEditorPanel({required this.state, required this.controller});

  final UserLandmarkGeometryEditorState state;
  final UserLandmarkGeometryEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OpenVtsColors.brandInk,
        border: Border(top: BorderSide(color: OpenVtsColors.white)),
      ),
      padding: const EdgeInsets.fromLTRB(
        OpenVtsSpacing.md,
        OpenVtsSpacing.sm,
        OpenVtsSpacing.md,
        OpenVtsSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _hintFor(state.editorMode),
            style: OpenVtsTypography.meta.copyWith(
              color: OpenVtsColors.white,
            ),
          ),
          const SizedBox(height: OpenVtsSpacing.xs),
          if (state.editorMode == UserGeofenceEditorMode.circle)
            _CircleControls(state: state, controller: controller),
          if (state.editorMode == UserGeofenceEditorMode.line)
            _LineControls(state: state, controller: controller),
          if (state.editorMode == UserGeofenceEditorMode.polygon ||
              state.editorMode == UserGeofenceEditorMode.line)
            _VertexControls(state: state, controller: controller),
          if (state.validationError != null) ...[
            const SizedBox(height: OpenVtsSpacing.xs),
            Text(
              state.validationError!,
              style: OpenVtsTypography.meta.copyWith(
                color: OpenVtsColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _hintFor(UserGeofenceEditorMode mode) {
    switch (mode) {
      case UserGeofenceEditorMode.circle:
        return 'Tap the map to set center, tap again to set radius.';
      case UserGeofenceEditorMode.polygon:
        return 'Tap the map to add vertices. Minimum 3 unique points.';
      case UserGeofenceEditorMode.rectangle:
        return 'Tap two opposite corners to define the rectangle.';
      case UserGeofenceEditorMode.line:
        return 'Tap the map to add line points. Minimum 2 points.';
      case UserGeofenceEditorMode.view:
        return '';
    }
  }
}

class _CircleControls extends StatefulWidget {
  const _CircleControls({required this.state, required this.controller});

  final UserLandmarkGeometryEditorState state;
  final UserLandmarkGeometryEditorController controller;

  @override
  State<_CircleControls> createState() => _CircleControlsState();
}

class _CircleControlsState extends State<_CircleControls> {
  late final TextEditingController _radius = TextEditingController(
    text: widget.state.circleRadiusM == null
        ? ''
        : widget.state.circleRadiusM!.round().toString(),
  );

  @override
  void didUpdateWidget(covariant _CircleControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final r = widget.state.circleRadiusM;
    final text = r == null ? '' : r.round().toString();
    if (text != _radius.text) {
      _radius.text = text;
      _radius.selection = TextSelection.collapsed(offset: _radius.text.length);
    }
  }

  @override
  void dispose() {
    _radius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.state.circleRadiusM ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(1, 5000).toDouble(),
                min: 1,
                max: 5000,
                divisions: 99,
                onChanged: widget.state.circleCenter == null
                    ? null
                    : (v) => widget.controller.setCircleRadius(v),
              ),
            ),
            SizedBox(
              width: 96,
              child: TextField(
                controller: _radius,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: OpenVtsTypography.body.copyWith(
                  color: OpenVtsColors.white,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: 'm',
                  suffixStyle: OpenVtsTypography.body.copyWith(
                    color: OpenVtsColors.white,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  enabled: widget.state.circleCenter != null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OpenVtsRadius.button),
                    borderSide: const BorderSide(
                      color: OpenVtsColors.white,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OpenVtsRadius.button),
                    borderSide: const BorderSide(
                      color: OpenVtsColors.white,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OpenVtsRadius.button),
                    borderSide: const BorderSide(
                      color: OpenVtsColors.white,
                      width: 1.4,
                    ),
                  ),
                ),
                onSubmitted: (text) {
                  final parsed = double.tryParse(text.trim());
                  if (parsed != null && parsed.isFinite && parsed >= 1) {
                    widget.controller.setCircleRadius(parsed);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LineControls extends StatefulWidget {
  const _LineControls({required this.state, required this.controller});

  final UserLandmarkGeometryEditorState state;
  final UserLandmarkGeometryEditorController controller;

  @override
  State<_LineControls> createState() => _LineControlsState();
}

class _LineControlsState extends State<_LineControls> {
  late final TextEditingController _tolerance = TextEditingController(
    text: widget.state.toleranceM == null
        ? ''
        : widget.state.toleranceM!.round().toString(),
  );

  @override
  void didUpdateWidget(covariant _LineControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final t = widget.state.toleranceM;
    final text = t == null ? '' : t.round().toString();
    if (text != _tolerance.text) {
      _tolerance.text = text;
      _tolerance.selection =
          TextSelection.collapsed(offset: _tolerance.text.length);
    }
  }

  @override
  void dispose() {
    _tolerance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.state.toleranceM ?? 0;
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value.clamp(0, 1000).toDouble(),
            min: 0,
            max: 1000,
            divisions: 100,
            onChanged: widget.controller.updateTolerance,
          ),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _tolerance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: OpenVtsTypography.body.copyWith(
              color: OpenVtsColors.white,
            ),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Tolerance',
              labelStyle: OpenVtsTypography.body.copyWith(
                color: OpenVtsColors.white,
              ),
              suffixText: 'm',
              suffixStyle: OpenVtsTypography.body.copyWith(
                color: OpenVtsColors.white,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OpenVtsRadius.button),
                borderSide: const BorderSide(color: OpenVtsColors.white),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OpenVtsRadius.button),
                borderSide: const BorderSide(color: OpenVtsColors.white),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OpenVtsRadius.button),
                borderSide: const BorderSide(
                  color: OpenVtsColors.white,
                  width: 1.4,
                ),
              ),
            ),
            onSubmitted: (text) {
              final parsed = double.tryParse(text.trim());
              if (parsed != null && parsed.isFinite && parsed >= 0) {
                widget.controller.updateTolerance(parsed);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _VertexControls extends StatelessWidget {
  const _VertexControls({required this.state, required this.controller});

  final UserLandmarkGeometryEditorState state;
  final UserLandmarkGeometryEditorController controller;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedVertexIndex;
    final count = state.points.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: OpenVtsSpacing.xs),
        Row(
          children: [
            Text(
              '$count point${count == 1 ? '' : 's'}',
              style: OpenVtsTypography.meta.copyWith(
                color: OpenVtsColors.white,
              ),
            ),
            const Spacer(),
            if (selected != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: OpenVtsColors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: OpenVtsSpacing.sm,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 32),
                  side: const BorderSide(
                    color: OpenVtsColors.error,
                  ),
                ),
                onPressed: () => controller.removePoint(selected),
                icon: const Icon(Icons.delete_outline, size: 14),
                label: Text(
                  'Remove #${selected + 1}',
                  style: OpenVtsTypography.meta.copyWith(
                    fontWeight: FontWeight.w600,
                    color: OpenVtsColors.error,
                  ),
                ),
              ),
          ],
        ),
        if (selected != null && selected < state.points.length)
          _NudgeRow(
            onNudge: ({double north = 0, double east = 0}) =>
                controller.moveSelectedPointByMeters(north: north, east: east),
          ),
      ],
    );
  }
}

class _NudgeRow extends StatelessWidget {
  const _NudgeRow({required this.onNudge});

  final void Function({double north, double east}) onNudge;

  static const double _stepM = 10;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: OpenVtsSpacing.xs),
      child: Row(
        children: [
          Text(
            'Nudge (${_stepM.toInt()} m)',
            style: OpenVtsTypography.meta.copyWith(
              color: OpenVtsColors.white,
            ),
          ),
          const SizedBox(width: OpenVtsSpacing.sm),
          _NudgeBtn(icon: Icons.north, onTap: () => onNudge(north: _stepM)),
          _NudgeBtn(icon: Icons.south, onTap: () => onNudge(north: -_stepM)),
          _NudgeBtn(icon: Icons.east, onTap: () => onNudge(east: _stepM)),
          _NudgeBtn(icon: Icons.west, onTap: () => onNudge(east: -_stepM)),
        ],
      ),
    );
  }
}

class _NudgeBtn extends StatelessWidget {
  const _NudgeBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: OpenVtsColors.brandInk,
            borderRadius: BorderRadius.circular(OpenVtsRadius.sm),
            border: Border.all(color: OpenVtsColors.white),
          ),
          child: Icon(icon, size: 14, color: OpenVtsColors.white),
        ),
      ),
    );
  }
}

class _NominatimSearchResult {
  const _NominatimSearchResult({
    required this.label,
    required this.lat,
    required this.lon,
  });

  final String label;
  final double lat;
  final double lon;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.isLoading,
    required this.results,
    required this.onSearch,
    required this.onSelectResult,
  });

  final TextEditingController controller;
  final bool isLoading;
  final List<_NominatimSearchResult> results;
  final VoidCallback onSearch;
  final Function(_NominatimSearchResult) onSelectResult;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OpenVtsColors.brandInk,
        borderRadius: BorderRadius.circular(OpenVtsRadius.md),
        border: Border.all(color: OpenVtsColors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: controller,
              onChanged: (_) => onSearch(),
              style: OpenVtsTypography.body.copyWith(
                color: OpenVtsColors.white,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search place...',
                hintStyle: OpenVtsTypography.body.copyWith(
                  color: OpenVtsColors.white.withValues(alpha: 0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              OpenVtsColors.brandInk.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      )
                    : controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: OpenVtsColors.white),
                            onPressed: () {
                              controller.clear();
                              onSearch();
                            },
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIconColor: OpenVtsColors.white,
              ),
            ),
          ),
          if (results.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: OpenVtsColors.white.withValues(alpha: 0.2)),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  return InkWell(
                    onTap: () => onSelectResult(result),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        result.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OpenVtsTypography.body.copyWith(
                          color: OpenVtsColors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
