part of '../live_map_screen.dart';

/// Uses the existing drawer, but the search and paging cover the authorized
/// server directory. A single page stays in memory and only built rows request
/// live state and day metrics. Previous/next preserve access to every vehicle.
class _FleetVehiclesTab extends ConsumerStatefulWidget {
  const _FleetVehiclesTab(
      {required this.onVehicleSelected,
      required this.searchController,
      required this.scrollController});
  final ValueChanged<VehicleSummary> onVehicleSelected;
  final TextEditingController searchController;
  final ScrollController scrollController;

  @override
  ConsumerState<_FleetVehiclesTab> createState() => _FleetVehiclesTabState();
}

class _FleetVehiclesTabState extends ConsumerState<_FleetVehiclesTab> {
  late final LiveMapController _controller;
  Timer? _searchTimer;
  final Set<String> _builtRows = {};
  bool _reportScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(liveMapControllerProvider.notifier);
    widget.searchController.addListener(_search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.setFleetQuery(search: widget.searchController.text);
      _controller.setDirectoryVisible(true);
    });
  }

  void _search() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.setFleetQuery(search: widget.searchController.text);
      }
    });
  }

  void _reportRow(String id) {
    _builtRows.add(id);
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (mounted) {
        _controller.setVisibleRowIds(_builtRows.toList(growable: false));
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    widget.searchController.removeListener(_search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.mounted) _controller.setDirectoryVisible(false);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(liveMapControllerProvider).fleet!;
    final scheme = Theme.of(context).colorScheme;
    _builtRows.clear();
    final rows = fleet.directory;
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: TextField(
            key: const ValueKey('fleet-directory-search'),
            controller: widget.searchController,
            maxLength: 120,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
                counterText: '',
                hintText: context.mobileText('Search vehicle'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none)),
          )),
      if (fleet.directoryLoading) const LinearProgressIndicator(minHeight: 2),
      if (fleet.directoryError != null)
        TextButton.icon(
            onPressed: () => _controller.refreshDirectory(),
            icon: const Icon(Icons.refresh),
            label: Text(context.mobileText('Unable to load vehicles. Retry.'))),
      Expanded(
          child: rows.isEmpty
              ? _DrawerScrollFill(
                  scrollController: widget.scrollController,
                  child: _DrawerEmptyState(
                      icon: Icons.search_off_rounded,
                      title: fleet.directoryLoading
                          ? context.mobileText('Loading vehicles…')
                          : context.mobileText('No vehicles found'),
                      message: context
                          .mobileText('Try another name or plate number.')))
              : NotificationListener<ScrollUpdateNotification>(
                  onNotification: (_) {
                    // Row elements currently mounted by the lazy sliver include a
                    // small cache halo. Rebuild to replace, rather than accumulate,
                    // the set after each scroll.
                    setState(() {});
                    return false;
                  },
                  child: ListView.separated(
                    key: ValueKey((
                      'fleet-directory',
                      fleet.page.queryRevision,
                      fleet.page.start
                    )),
                    controller: widget.scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    cacheExtent: 100,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: scheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      _reportRow(row.id);
                      return _VehicleListTile(
                          key: ValueKey(row.id),
                          vehicle: row,
                          onTap: fleet.directoryLoading
                              ? null
                              : () => widget.onVehicleSelected(row));
                    },
                  ),
                )),
      SafeArea(
          top: false,
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
                key: const ValueKey('fleet-directory-previous'),
                tooltip: context.mobileText('Previous'),
                onPressed:
                    fleet.directoryLoading || fleet.page.previousCursor == null
                        ? null
                        : () => _controller.loadDirectoryPage(previous: true),
                icon: const Icon(Icons.chevron_left)),
            Flexible(
                child: Text(
                    rows.isEmpty
                        ? '0 / ${fleet.page.total}'
                        : '${fleet.page.start + 1}–${fleet.page.start + rows.length} / ${fleet.page.total}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            IconButton(
                key: const ValueKey('fleet-directory-next'),
                tooltip: context.mobileText('Next'),
                onPressed:
                    fleet.directoryLoading || fleet.page.nextCursor == null
                        ? null
                        : () => _controller.loadDirectoryPage(),
                icon: const Icon(Icons.chevron_right)),
          ])),
    ]);
  }
}

/// Server search inside the existing history dialog also reaches vehicles
/// outside the current viewport and directory page.
class _FleetHistoryVehicleField extends ConsumerStatefulWidget {
  const _FleetHistoryVehicleField(
      {required this.initialVehicle, required this.onChanged});
  final VehicleSummary? initialVehicle;
  final ValueChanged<VehicleSummary?> onChanged;
  @override
  ConsumerState<_FleetHistoryVehicleField> createState() =>
      _FleetHistoryVehicleFieldState();
}

class _FleetHistoryVehicleFieldState
    extends ConsumerState<_FleetHistoryVehicleField> {
  final TextEditingController _search = TextEditingController();
  Timer? _timer;
  CancelToken? _token;
  LiveMapFleetView? _result;
  VehicleSummary? _selected;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialVehicle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load({String? cursor}) async {
    _token?.cancel('History vehicle search superseded');
    final token = _token = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(liveMapControllerProvider.notifier)
          .lookupFleetPage(
              search: _search.text, cursor: cursor, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(() {
          _loading = false;
          _error = 'Unable to load vehicles. Retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _token?.cancel('History dialog closed');
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices = <String, VehicleSummary>{
      if (_selected != null) _selected!.id: _selected!,
      for (final vehicle in _result?.directory ?? <VehicleSummary>[])
        if (vehicle.imei.isNotEmpty) vehicle.id: vehicle,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
          key: const ValueKey('fleet-history-search'),
          controller: _search,
          maxLength: 120,
          decoration: InputDecoration(
              counterText: '',
              hintText: context.mobileText('Search vehicle'),
              prefixIcon: const Icon(Icons.search)),
          onChanged: (_) {
            _timer?.cancel();
            _token?.cancel('History vehicle search changed');
            _timer = Timer(const Duration(milliseconds: 300), () {
              if (mounted) unawaited(_load());
            });
          }),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_error != null)
        TextButton(
            onPressed: () => _load(),
            child: Text(context.mobileText('Unable to load vehicles. Retry.'))),
      DropdownButtonFormField<String>(
          key: ValueKey(
              ('history-vehicle', _selected?.id, choices.keys.join(','))),
          initialValue: _selected?.id,
          isExpanded: true,
          decoration:
              InputDecoration(hintText: context.mobileText('Select vehicle')),
          items: choices.entries
              .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(_historyVehicleOptionLabel(entry.value),
                      maxLines: 1, overflow: TextOverflow.ellipsis)))
              .toList(growable: false),
          validator: context.localizedValidator((id) =>
              id == null ? 'Select a vehicle from live telemetry.' : null),
          onChanged: _loading
              ? null
              : (id) {
                  setState(() => _selected = choices[id]);
                  widget.onChanged(_selected);
                }),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
            tooltip: context.mobileText('Previous'),
            icon: const Icon(Icons.chevron_left),
            onPressed: _loading || _result?.page.previousCursor == null
                ? null
                : () => _load(cursor: _result!.page.previousCursor)),
        Text('${_result?.page.total ?? 0}'),
        IconButton(
            tooltip: context.mobileText('Next'),
            icon: const Icon(Icons.chevron_right),
            onPressed: _loading || _result?.page.nextCursor == null
                ? null
                : () => _load(cursor: _result!.page.nextCursor)),
      ]),
    ]);
  }
}
