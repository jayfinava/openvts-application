import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/performance/open_vts_perf.dart';
import '../models/app_notification.dart';
import '../models/notification_center_state.dart';
import '../services/notification_service.dart';

class NotificationCenterController
    extends StateNotifier<NotificationCenterState> {
  NotificationCenterController(this._service)
      : super(const NotificationCenterState.initial());
  final NotificationService _service;
  int _generation = 0;
  final _markingIds = <int>{};
  bool _current(int generation) => mounted && generation == _generation;

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> load({bool refresh = false}) =>
      OpenVtsPerf.traceAsync('notifications.load', () async {
        if (!mounted) return;
        final generation = ++_generation;
        final unreadOnly = state.unreadOnly;
        state = state.copyWith(
            isInitialLoading: !state.hasItems && !refresh,
            isRefreshing: refresh,
            isLoadingMore: false,
            isMarkingAllRead: false,
            errorMessage: null);
        try {
          final page = await _service.getNotifications(
              limit: AppConstants.defaultPageSize, unreadOnly: unreadOnly);
          if (!_current(generation)) return;
          final unread = page.unreadCount ?? await _service.getUnreadCount();
          if (!_current(generation)) return;
          state = state.copyWith(
              items: page.items,
              unreadCount: unread,
              hasMore: page.hasMore,
              nextBeforeId: page.nextBeforeId,
              isInitialLoading: false,
              isRefreshing: false,
              isLoadingMore: false,
              errorMessage: null);
        } catch (error) {
          if (!_current(generation)) return;
          state = state.copyWith(
              isInitialLoading: false,
              isRefreshing: false,
              isLoadingMore: false,
              errorMessage: _toErrorMessage(error));
        }
      });

  Future<void> refresh() => load(refresh: true);

  Future<void> setUnreadOnly(bool unreadOnly) async {
    if (!mounted || state.unreadOnly == unreadOnly) return;
    state = state.copyWith(
        items: [],
        unreadOnly: unreadOnly,
        hasMore: false,
        nextBeforeId: null,
        errorMessage: null);
    await load();
  }

  Future<void> loadMore() async {
    if (!mounted ||
        state.isInitialLoading ||
        state.isRefreshing ||
        state.isLoadingMore ||
        state.isMarkingAllRead ||
        _markingIds.isNotEmpty ||
        !state.hasMore) {
      return;
    }
    final before = state.nextBeforeId ??
        (state.items.isNotEmpty ? state.items.last.id : null);
    if (before == null || before <= 0) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, errorMessage: null);
    try {
      final page = await _service.getNotifications(
          limit: AppConstants.defaultPageSize,
          beforeId: before,
          unreadOnly: state.unreadOnly);
      if (!_current(generation)) return;
      state = state.copyWith(
          items: _mergeById(state.items, page.items),
          unreadCount: page.unreadCount ?? state.unreadCount,
          hasMore: page.hasMore && page.nextBeforeId != before,
          nextBeforeId: page.nextBeforeId,
          isLoadingMore: false,
          errorMessage: null);
    } catch (error) {
      if (!_current(generation)) return;
      state = state.copyWith(
          isLoadingMore: false, errorMessage: _toErrorMessage(error));
    }
  }

  Future<void> markAsRead(int id) async {
    if (!mounted || state.isMarkingAllRead || _markingIds.contains(id)) return;
    final index = state.items.indexWhere((item) => item.id == id);
    if (index < 0 || state.items[index].isRead) return;
    _discardPendingReads();
    final original = state.items[index], generation = _generation;
    final decremented = state.unreadCount > 0;
    _markingIds.add(id);
    state = state.copyWith(
        items: state.items
            .where((item) => !(state.unreadOnly && item.id == id))
            .map((item) => item.id == id
                ? item.copyWith(isRead: true, readAt: DateTime.now())
                : item)
            .toList(growable: false),
        unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
        errorMessage: null);
    try {
      await _service.markAsRead(id);
      if (mounted && !_current(generation)) unawaited(refresh());
    } catch (error) {
      if (_current(generation)) {
        state = state.copyWith(
            items: _mergeById(state.items, [original]),
            unreadCount: state.unreadCount + (decremented ? 1 : 0),
            errorMessage: _toErrorMessage(error));
      }
      rethrow;
    } finally {
      _markingIds.remove(id);
    }
  }

  Future<void> markAllAsRead() async {
    if (!mounted ||
        state.isMarkingAllRead ||
        state.unreadCount == 0 ||
        _markingIds.isNotEmpty) {
      return;
    }
    _discardPendingReads();
    final previous = state, generation = _generation;
    state = state.copyWith(
        items: state.unreadOnly
            ? []
            : state.items
                .map((item) => item.copyWith(
                    isRead: true, readAt: item.readAt ?? DateTime.now()))
                .toList(growable: false),
        hasMore: state.unreadOnly ? false : state.hasMore,
        nextBeforeId: state.unreadOnly ? null : state.nextBeforeId,
        unreadCount: 0,
        isMarkingAllRead: true,
        errorMessage: null);
    try {
      await _service.markAllAsRead();
      if (_current(generation)) {
        state = state.copyWith(isMarkingAllRead: false);
      } else if (mounted) {
        unawaited(refresh());
      }
    } catch (error) {
      if (_current(generation)) {
        state = previous.copyWith(
            isMarkingAllRead: false, errorMessage: _toErrorMessage(error));
      }
      rethrow;
    }
  }

  void _discardPendingReads() {
    if (!state.isInitialLoading &&
        !state.isRefreshing &&
        !state.isLoadingMore) {
      return;
    }
    // A page requested before this mutation may carry the old read flags and
    // unread count. Keep the last displayed page and allow its cursor to retry.
    _generation++;
    state = state.copyWith(
        isInitialLoading: false, isRefreshing: false, isLoadingMore: false);
  }

  List<AppNotification> _mergeById(
      List<AppNotification> current, List<AppNotification> incoming) {
    final merged = <int, AppNotification>{
      for (final item in current) item.id: item
    };
    for (final item in incoming) {
      merged[item.id] = item;
    }
    return merged.values.toList(growable: false)
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  String _toErrorMessage(Object error) => ErrorMapper.from(error).message;
}
