import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/paging/server_list_pager.dart';
import '../models/admin_drivers_model.dart';
import '../models/admin_drivers_state.dart';
import '../services/admin_driver_timestamp_storage.dart';
import '../services/admin_drivers_service.dart';

class AdminDriversController extends StateNotifier<AdminDriversState> {
  AdminDriversController({this.pager, required AdminDriversService service})
      : _service = service,
        super(const AdminDriversState.initial()) {
    pager?.onChanged = _syncPage;
  }

  final ServerListPager<AdminDriverListItem>? pager;
  bool get isServerPaged => pager != null;
  void _syncPage() {
    final p = pager!;
    if (!mounted) return;
    state = state.copyWith(
        drivers: p.items,
        filteredDrivers: p.items,
        pagination: p.meta,
        currentPage: p.meta?.page ?? state.currentPage,
        recordsPerPage: p.meta?.limit ?? state.recordsPerPage,
        isLoading: p.loading && p.meta == null,
        isRefreshing: p.loading && p.meta != null,
        errorMessage: p.error);
    if (!p.loading && p.meta != null) unawaited(_enrichPage(p.items));
  }

  Future<void> _enrichPage(List<AdminDriverListItem> rows) async {
    try {
      final timestamps = await AdminDriverTimestampStorage.readUpdatedAtMap(
          rows.map((row) => row.id));
      if (!mounted || !identical(pager!.items, rows) || pager!.loading) return;
      final drivers = rows
          .map((row) => row.copyWith(
                updatedAt: resolveDriverEffectiveUpdatedAt(
                    serverUpdatedAt: row.updatedAt,
                    persistedUpdatedAt: timestamps[row.id],
                    createdAt: row.createdAt),
              ))
          .toList(growable: false);
      state = state.copyWith(drivers: drivers, filteredDrivers: drivers);
    } catch (_) {
      // Optional local edit timestamps must never block the server page.
    }
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
            AdminDriversSortOption.nameAsc => 'name',
            AdminDriversSortOption.activeFirst => 'status',
            _ => 'createdAt'
          },
          sortDir: state.sortOption == AdminDriversSortOption.nameAsc
              ? 'asc'
              : 'desc',
          filters: {
            if (state.statusFilter != AdminDriverStatusFilter.all)
              'status': state.statusFilter == AdminDriverStatusFilter.active
          });
  final AdminDriversService _service;

  Future<void> load() async {
    if (pager != null) return pager!.load();
    await _fetchDrivers(
      refreshKey: state.refreshKey == 0 ? null : state.refreshKey.toString(),
      refreshing: state.hasDrivers,
    );
  }

  Future<void> refresh() async {
    if (pager != null) return pager!.load();
    final nextRefreshKey = state.refreshKey + 1;
    state = state.copyWith(refreshKey: nextRefreshKey);
    await _fetchDrivers(
      refreshKey: nextRefreshKey.toString(),
      refreshing: true,
    );
  }

  void setSearchQuery(String value) {
    if (pager != null) {
      state = state.copyWith(searchQuery: value);
      unawaited(_reloadPage(debounce: true));
      return;
    }
    state = _withFilteredDrivers(
      state.copyWith(searchQuery: value, currentPage: 1, errorMessage: null),
    );
  }

  void setStatusFilter(AdminDriverStatusFilter value) {
    if (pager != null) {
      state = state.copyWith(statusFilter: value);
      unawaited(_reloadPage(debounce: false));
      return;
    }
    state = _withFilteredDrivers(
      state.copyWith(statusFilter: value, currentPage: 1, errorMessage: null),
    );
  }

  void setVerifiedFilter(AdminDriverVerifiedFilter value) {
    state = _withFilteredDrivers(
      state.copyWith(verifiedFilter: value, currentPage: 1, errorMessage: null),
    );
  }

  void setCountryFilter(String? value) {
    final normalized = value?.trim();
    state = _withFilteredDrivers(
      state.copyWith(
        countryFilter:
            normalized == null || normalized.isEmpty ? null : normalized,
        currentPage: 1,
        errorMessage: null,
      ),
    );
  }

  void setSortOption(AdminDriversSortOption value) {
    if (pager != null) {
      state = state.copyWith(sortOption: value);
      unawaited(_reloadPage(debounce: false));
      return;
    }
    state = _withFilteredDrivers(
      state.copyWith(sortOption: value, currentPage: 1, errorMessage: null),
    );
  }

  void setRecordsPerPage(int value) {
    if (pager != null) {
      unawaited(pager!.change(page: 1, limit: value));
      return;
    }
    state = state.copyWith(recordsPerPage: value, currentPage: 1);
  }

  void goToPage(int value) {
    if (pager != null) {
      unawaited(pager!.goToPage(value));
      return;
    }
    state = state.copyWith(currentPage: value);
  }

  Future<void> createDriver(AdminDriverCreateRequest request) async {
    state = state.copyWith(isCreating: true, errorMessage: null);
    try {
      await _service.createDriver(request);
      if (!mounted) return;
      await _fetchDrivers(refreshing: true);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: _toErrorMessage(error));
      rethrow;
    } finally {
      if (mounted) {
        state = state.copyWith(isCreating: false);
      }
    }
  }

  Future<List<AdminDriverListItem>> fetchUsersForPrimarySelection() {
    return _service.getUsersForDriverPrimarySelection();
  }

  Future<void> updateDriverStatus(String driverId, bool isActive) async {
    if (pager != null) {
      state = state
          .copyWith(updatingDriverIds: {...state.updatingDriverIds, driverId});
      try {
        await _service.updateDriverStatus(id: driverId, isActive: isActive);
        if (mounted) unawaited(pager!.load());
      } finally {
        if (mounted) {
          state = state.copyWith(
              updatingDriverIds: {...state.updatingDriverIds}
                ..remove(driverId));
        }
      }
      return;
    }
    final driverIndex = state.drivers.indexWhere((d) => d.id == driverId);
    if (driverIndex == -1) return;

    final previousDriver = state.drivers[driverIndex];
    final updatingIds = {...state.updatingDriverIds, driverId};
    state = state.copyWith(updatingDriverIds: updatingIds);

    try {
      await _service.updateDriverStatus(id: driverId, isActive: isActive);
      if (!mounted) return;

      final updatedDriver = previousDriver.copyWith(isActive: isActive);
      final updatedDrivers = <AdminDriverListItem>[...state.drivers];
      updatedDrivers[driverIndex] = updatedDriver;

      state = _withFilteredDrivers(
        state.copyWith(
          drivers: updatedDrivers,
          updatingDriverIds: updatingIds..remove(driverId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        updatingDriverIds: updatingIds..remove(driverId),
      );
      rethrow;
    }
  }

  Future<void> deleteDriver(String driverId) async {
    await _service.deleteDriver(driverId);
    unawaited(AdminDriverTimestampStorage.clearUpdatedAt(driverId));
    if (!mounted) return;
    if (pager != null) {
      await pager!.load();
      return;
    }
    final updated =
        state.drivers.where((d) => d.id != driverId).toList(growable: false);
    state = _withFilteredDrivers(
      state.copyWith(drivers: updated, errorMessage: null),
    );
  }

  void clearFilters() {
    if (pager != null) {
      state = state.copyWith(
          searchQuery: '',
          statusFilter: AdminDriverStatusFilter.all,
          verifiedFilter: AdminDriverVerifiedFilter.all,
          countryFilter: null,
          sortOption: AdminDriversSortOption.newest);
      unawaited(_reloadPage());
      return;
    }
    state = _withFilteredDrivers(
      state.copyWith(
        searchQuery: '',
        statusFilter: AdminDriverStatusFilter.all,
        verifiedFilter: AdminDriverVerifiedFilter.all,
        countryFilter: null,
        sortOption: AdminDriversSortOption.newest,
        currentPage: 1,
        errorMessage: null,
      ),
    );
  }

  Future<void> _fetchDrivers({
    String? refreshKey,
    required bool refreshing,
  }) async {
    if (pager != null) return pager!.load();
    final hasExistingDrivers = state.hasDrivers;
    state = state.copyWith(
      isLoading: !hasExistingDrivers && !refreshing,
      isRefreshing: hasExistingDrivers || refreshing,
      errorMessage: null,
    );

    try {
      final rawDrivers = await _service.getDrivers(refreshKey: refreshKey);
      if (!mounted) {
        return;
      }

      // Enrich every driver with a stable effective updatedAt in one prefs read.
      final ids = rawDrivers.map((d) => d.id).where((id) => id.isNotEmpty);
      final persistedMap =
          await AdminDriverTimestampStorage.readUpdatedAtMap(ids);

      final drivers = rawDrivers.map((driver) {
        final effective = resolveDriverEffectiveUpdatedAt(
          serverUpdatedAt: driver.updatedAt,
          persistedUpdatedAt: persistedMap[driver.id],
          createdAt: driver.createdAt,
        );
        if (effective == driver.updatedAt) return driver;
        return driver.copyWith(updatedAt: effective);
      }).toList(growable: false);

      if (!mounted) {
        return;
      }

      state = _withFilteredDrivers(
        state.copyWith(
          drivers: drivers,
          isLoading: false,
          isRefreshing: false,
          errorMessage: null,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: _toErrorMessage(error),
      );
    }
  }

  AdminDriversState _withFilteredDrivers(AdminDriversState nextState) {
    if (pager != null) {
      return nextState.copyWith(filteredDrivers: nextState.drivers);
    }
    return nextState.copyWith(filteredDrivers: _filterDrivers(nextState));
  }

  List<AdminDriverListItem> _filterDrivers(AdminDriversState nextState) {
    final filtered = nextState.drivers.where((driver) {
      final matchesSearch = driver.matchesQuery(nextState.searchQuery);
      final matchesStatus = switch (nextState.statusFilter) {
        AdminDriverStatusFilter.all => true,
        AdminDriverStatusFilter.active => driver.isActive,
        AdminDriverStatusFilter.inactive => !driver.isActive,
      };
      final matchesVerified = switch (nextState.verifiedFilter) {
        AdminDriverVerifiedFilter.all => true,
        AdminDriverVerifiedFilter.verified => driver.isVerified,
        AdminDriverVerifiedFilter.unverified => !driver.isVerified,
      };
      final normalizedCountry = nextState.countryFilter?.trim().toUpperCase();
      final driverCountry = driver.countryCode.trim().toUpperCase();
      final matchesCountry =
          normalizedCountry == null || normalizedCountry.isEmpty
              ? true
              : driverCountry == normalizedCountry;

      return matchesSearch &&
          matchesStatus &&
          matchesVerified &&
          matchesCountry;
    }).toList(growable: false);

    if (filtered.length < 2) {
      return filtered;
    }

    switch (nextState.sortOption) {
      case AdminDriversSortOption.newest:
        filtered.sort((left, right) {
          final leftDate = left.createdAt;
          final rightDate = right.createdAt;
          if (leftDate == null && rightDate == null) {
            return left.firstName
                .toLowerCase()
                .compareTo(right.firstName.toLowerCase());
          }
          if (leftDate == null) return 1;
          if (rightDate == null) return -1;
          return rightDate.compareTo(leftDate);
        });
      case AdminDriversSortOption.nameAsc:
        filtered.sort(
          (left, right) => left.firstName
              .toLowerCase()
              .compareTo(right.firstName.toLowerCase()),
        );
      case AdminDriversSortOption.activeFirst:
        filtered.sort((left, right) {
          final activeCompare =
              (right.isActive ? 1 : 0).compareTo(left.isActive ? 1 : 0);
          if (activeCompare != 0) return activeCompare;
          return left.firstName
              .toLowerCase()
              .compareTo(right.firstName.toLowerCase());
        });
    }

    return filtered;
  }

  String _toErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    if (error is DioException) {
      final responseMessage = _extractResponseMessage(error.response?.data);
      if (responseMessage != null) {
        return responseMessage;
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'The request timed out. Please try again.';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'Unable to reach the server right now.';
      }

      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }

    return raw;
  }

  String? _extractResponseMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      for (final key in const ['message', 'error']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }

        if (value is List) {
          final parts = value
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      }

      final nestedData = data['data'];
      if (!identical(nestedData, data)) {
        return _extractResponseMessage(nestedData);
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return null;
  }
}
