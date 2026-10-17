import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/paging/server_list_pager.dart';
import '../models/admin_vehicle_model.dart';
import '../models/admin_vehicle_state.dart';
import '../services/admin_vehicle_service.dart';

class AdminVehiclesController extends StateNotifier<AdminVehiclesState> {
  AdminVehiclesController({
    this.pager,
    required AdminVehicleService service,
    this.onDashboardRefresh,
  })  : _service = service,
        super(AdminVehiclesState.initial()) {
    pager?.onChanged = _syncPage;
  }

  final ServerListPager<AdminVehicleListItem>? pager;
  bool get isServerPaged => pager != null;
  void _syncPage() {
    final p = pager!;
    if (!mounted) return;
    state = state.copyWith(
        vehicles: p.items,
        filteredVehicles: p.items,
        pagination: p.meta,
        currentPage: p.meta?.page ?? state.currentPage,
        recordsPerPage: p.meta?.limit ?? state.recordsPerPage,
        isLoading: p.loading && p.meta == null,
        isRefreshing: p.loading && p.meta != null,
        errorMessage: p.error);
  }

  @override
  void dispose() {
    pager?.dispose();
    super.dispose();
  }

  Future<void> _reloadPage({bool debounce = false}) => pager!.change(
          page: 1,
          search: state.searchQuery,
          debounce: debounce,
          sortBy: switch (state.sortOption) {
            AdminVehiclesSortOption.nameAz ||
            AdminVehiclesSortOption.nameZa =>
              'name',
            AdminVehiclesSortOption.activeFirst => 'status',
            _ => 'createdAt'
          },
          sortDir: state.sortOption == AdminVehiclesSortOption.oldest ||
                  state.sortOption == AdminVehiclesSortOption.nameAz
              ? 'asc'
              : 'desc',
          filters: {
            if (state.statusFilter != AdminVehicleStatusFilter.all)
              'status': state.statusFilter == AdminVehicleStatusFilter.active,
            if (state.typeFilter.isNotEmpty) 'vehicleTypeName': state.typeFilter
          });
  final AdminVehicleService _service;
  final void Function()? onDashboardRefresh;

  Future<void> load() async {
    if (pager != null) return pager!.load();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final vehicles = await _service.getVehicles();
      _setVehicles(vehicles, isLoading: false);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _errorMessage(error),
      );
    }
  }

  Future<void> refresh() async {
    if (pager != null) return pager!.load();
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    try {
      final vehicles = await _service.getVehicles(
        refreshKey: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _setVehicles(vehicles, isRefreshing: false);
    } catch (error) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: _errorMessage(error),
      );
    }
  }

  void setSearchQuery(String value) {
    if (pager != null) {
      state = state.copyWith(searchQuery: value);
      unawaited(_reloadPage(debounce: true));
      return;
    }
    state = state.copyWith(
      searchQuery: value,
      currentPage: 1,
      errorMessage: null,
    );
    _applyFilters();
  }

  void setStatusFilter(AdminVehicleStatusFilter value) {
    if (pager != null) {
      state = state.copyWith(statusFilter: value);
      unawaited(_reloadPage(debounce: false));
      return;
    }
    state = state.copyWith(
      statusFilter: value,
      currentPage: 1,
      errorMessage: null,
    );
    _applyFilters();
  }

  void setTypeFilter(String value) {
    if (pager != null) {
      state = state.copyWith(typeFilter: value);
      unawaited(_reloadPage(debounce: false));
      return;
    }
    state = state.copyWith(
      typeFilter: value,
      currentPage: 1,
      errorMessage: null,
    );
    _applyFilters();
  }

  void setSortOption(AdminVehiclesSortOption value) {
    if (pager != null) {
      state = state.copyWith(sortOption: value);
      unawaited(_reloadPage(debounce: false));
      return;
    }
    state = state.copyWith(
      sortOption: value,
      currentPage: 1,
      errorMessage: null,
    );
    _applyFilters();
  }

  void setRecordsPerPage(int value) {
    if (pager != null) {
      unawaited(pager!.change(page: 1, limit: value));
      return;
    }
    state = state.copyWith(
      recordsPerPage: value,
      currentPage: 1,
    );
  }

  void goToPage(int value) {
    if (pager != null) {
      unawaited(pager!.goToPage(value));
      return;
    }
    state = state.copyWith(currentPage: value);
  }

  void clearFilters() {
    if (pager != null) {
      state = state.copyWith(
          searchQuery: '',
          statusFilter: AdminVehicleStatusFilter.all,
          typeFilter: '');
      unawaited(_reloadPage());
      return;
    }
    state = state.copyWith(
      searchQuery: '',
      statusFilter: AdminVehicleStatusFilter.all,
      typeFilter: '',
      currentPage: 1,
    );
    _applyFilters();
  }

  Future<void> createVehicle(AdminCreateVehicleRequest request) async {
    if (!mounted) return;
    if (state.isCreating) {
      throw StateError('Vehicle creation is already in progress.');
    }
    state = state.copyWith(isCreating: true, errorMessage: null);
    try {
      await _service.createVehicle(request);
      if (!mounted) {
        return;
      }
      state = state.copyWith(isCreating: false);
      unawaited(refresh());
      onDashboardRefresh?.call();
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isCreating: false,
        errorMessage: _errorMessage(error),
      );
      rethrow;
    }
  }

  Future<AdminCreateVehicleCatalog> getCreateVehicleCatalog() async {
    final results = await Future.wait<dynamic>([
      _service.getUsers(),
      _service.getQuickDevices(),
      _service.getVehicleTypes(),
      _service.getPricingPlans(),
    ]);

    return AdminCreateVehicleCatalog(
      users: results[0] as List<AdminVehicleUserMini>,
      devices: results[1] as List<AdminQuickDeviceOption>,
      vehicleTypes: results[2] as List<AdminVehicleTypeOption>,
      plans: results[3] as List<AdminPricingPlanOption>,
    );
  }

  Future<List<AdminVehicleUserMini>> getUsers() async {
    return await _service.getUsers();
  }

  Future<List<AdminQuickDeviceOption>> getQuickDevices() async {
    return await _service.getQuickDevices();
  }

  Future<List<AdminPricingPlanOption>> getPricingPlans() async {
    return await _service.getPricingPlans();
  }

  Future<bool> updateVehicleStatus(
      {required String id, required bool isActive}) async {
    if (pager != null) {
      state = state.copyWith(updatingIds: {...state.updatingIds, id});
      try {
        await _service.updateVehicleStatus(id: id, isActive: isActive);
        if (!mounted) return false;
        state = state.copyWith(updatingIds: {...state.updatingIds}..remove(id));
        unawaited(pager!.load());
        onDashboardRefresh?.call();
        return true;
      } catch (error) {
        if (mounted) {
          state = state.copyWith(
              updatingIds: {...state.updatingIds}..remove(id),
              errorMessage: _errorMessage(error));
        }
        return false;
      }
    }
    final current = state.vehicles;
    final updating = <String>{...state.updatingIds, id};
    final optimistic = current
        .map((item) => item.id == id
            ? AdminVehicleListItem(
                id: item.id,
                name: item.name,
                vin: item.vin,
                plateNumber: item.plateNumber,
                isActive: isActive,
                isLicenseBlocked: item.isLicenseBlocked,
                licenseBlockedAt: item.licenseBlockedAt,
                licenseBlockReason: item.licenseBlockReason,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt,
                imei: item.imei,
                simNumber: item.simNumber,
                vehicleType: item.vehicleType,
                device: item.device,
                primaryUser: item.primaryUser,
              )
            : item)
        .toList(growable: false);
    state = state.copyWith(
      updatingIds: updating,
      errorMessage: null,
      vehicles: optimistic,
    );
    _applyFilters();
    try {
      await _service.updateVehicleStatus(id: id, isActive: isActive);
      state = state.copyWith(updatingIds: {...state.updatingIds}..remove(id));
      _applyFilters();
      onDashboardRefresh?.call();
      return true;
    } catch (error) {
      state = state.copyWith(
        updatingIds: {...state.updatingIds}..remove(id),
        vehicles: current,
        errorMessage: _errorMessage(error),
      );
      _applyFilters();
      return false;
    }
  }

  Future<bool> deleteVehicle(String id) async {
    if (pager != null) {
      state = state.copyWith(deletingIds: {...state.deletingIds, id});
      try {
        await _service.deleteVehicle(id);
        if (!mounted) return false;
        state = state.copyWith(deletingIds: {...state.deletingIds}..remove(id));
        unawaited(pager!.load());
        onDashboardRefresh?.call();
        return true;
      } catch (error) {
        if (mounted) {
          state = state.copyWith(
              deletingIds: {...state.deletingIds}..remove(id),
              errorMessage: _errorMessage(error));
        }
        return false;
      }
    }
    final deleting = <String>{...state.deletingIds, id};
    state = state.copyWith(deletingIds: deleting, errorMessage: null);
    try {
      await _service.deleteVehicle(id);
      final vehicles =
          state.vehicles.where((item) => item.id != id).toList(growable: false);
      state = state.copyWith(
          deletingIds: {...state.deletingIds}..remove(id), vehicles: vehicles);
      _applyFilters();
      onDashboardRefresh?.call();
      return true;
    } catch (error) {
      state = state.copyWith(
        deletingIds: {...state.deletingIds}..remove(id),
        errorMessage: _errorMessage(error),
      );
      return false;
    }
  }

  void _setVehicles(
    List<AdminVehicleListItem> vehicles, {
    bool? isLoading,
    bool? isRefreshing,
  }) {
    state = state.copyWith(
      vehicles: vehicles,
      isLoading: isLoading,
      isRefreshing: isRefreshing,
      errorMessage: null,
    );
    _applyFilters();
  }

  void _applyFilters() {
    if (pager != null) {
      state = state.copyWith(filteredVehicles: state.vehicles);
      return;
    }
    final query = state.searchQuery.trim().toLowerCase();
    final typeFilter = state.typeFilter.trim().toLowerCase();
    final filtered = state.vehicles.where((vehicle) {
      if (state.statusFilter == AdminVehicleStatusFilter.active &&
          !vehicle.isActive) {
        return false;
      }
      if (state.statusFilter == AdminVehicleStatusFilter.inactive &&
          vehicle.isActive) {
        return false;
      }
      if (state.statusFilter == AdminVehicleStatusFilter.licenseBlocked &&
          !vehicle.isLicenseBlocked) {
        return false;
      }
      if (typeFilter.isNotEmpty &&
          vehicle.vehicleTypeName.toLowerCase() != typeFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }

      final haystack = <String>[
        vehicle.name,
        vehicle.plateNumber,
        vehicle.vin,
        vehicle.imei,
        vehicle.simNumber,
        vehicle.vehicleTypeName,
        vehicle.primaryUserName,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);

    state = state.copyWith(
      filteredVehicles: _sortVehicles(filtered, state.sortOption),
    );
  }

  List<AdminVehicleListItem> _sortVehicles(
    List<AdminVehicleListItem> vehicles,
    AdminVehiclesSortOption sortOption,
  ) {
    if (vehicles.length < 2) {
      return vehicles;
    }

    final sortedVehicles = vehicles.toList(growable: false);
    switch (sortOption) {
      case AdminVehiclesSortOption.newest:
        sortedVehicles.sort((left, right) {
          final dateCompare = _compareDates(
            left.createdAt,
            right.createdAt,
            newestFirst: true,
          );
          return dateCompare != 0
              ? dateCompare
              : _sortName(left).compareTo(_sortName(right));
        });
      case AdminVehiclesSortOption.oldest:
        sortedVehicles.sort((left, right) {
          final dateCompare = _compareDates(
            left.createdAt,
            right.createdAt,
            newestFirst: false,
          );
          return dateCompare != 0
              ? dateCompare
              : _sortName(left).compareTo(_sortName(right));
        });
      case AdminVehiclesSortOption.nameAz:
        sortedVehicles.sort(
          (left, right) => _sortName(left).compareTo(_sortName(right)),
        );
      case AdminVehiclesSortOption.nameZa:
        sortedVehicles.sort(
          (left, right) => _sortName(right).compareTo(_sortName(left)),
        );
      case AdminVehiclesSortOption.activeFirst:
        sortedVehicles.sort((left, right) {
          final statusCompare =
              (right.isActive ? 1 : 0).compareTo(left.isActive ? 1 : 0);
          if (statusCompare != 0) {
            return statusCompare;
          }
          return _sortName(left).compareTo(_sortName(right));
        });
    }

    return sortedVehicles;
  }

  int _compareDates(
    DateTime? left,
    DateTime? right, {
    required bool newestFirst,
  }) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return newestFirst ? right.compareTo(left) : left.compareTo(right);
  }

  String _sortName(AdminVehicleListItem vehicle) {
    final name = vehicle.name.trim();
    if (name.isNotEmpty) {
      return name.toLowerCase();
    }
    final plate = vehicle.plateNumber.trim();
    if (plate.isNotEmpty) {
      return plate.toLowerCase();
    }
    return vehicle.imei.trim().toLowerCase();
  }

  String _errorMessage(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception:')) {
      return message.replaceFirst('Exception:', '').trim();
    }
    return message.isEmpty ? 'Unable to complete request.' : message;
  }
}

class AdminCreateVehicleCatalog {
  const AdminCreateVehicleCatalog({
    required this.users,
    required this.devices,
    required this.vehicleTypes,
    required this.plans,
  });

  final List<AdminVehicleUserMini> users;
  final List<AdminQuickDeviceOption> devices;
  final List<AdminVehicleTypeOption> vehicleTypes;
  final List<AdminPricingPlanOption> plans;
}
