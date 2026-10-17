import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/features/user/controllers/user_transactions_controller.dart';
import 'package:open_vts/features/user/models/user_transactions_model.dart';
import 'package:open_vts/features/user/models/user_transactions_state.dart';
import 'package:open_vts/features/user/services/user_transactions_service.dart';

class _PendingTransactionsService extends UserTransactionsService {
  _PendingTransactionsService() : super(ApiClient(Dio()));

  final requests = <Completer<UserTransactionPage>>[];
  final fromFilters = <String?>[];

  @override
  Future<UserTransactionPage> getTransactions({
    UserTransactionStatus? status,
    String? search,
    String? from,
    String? to,
    int page = 1,
    int limit = 100,
    String? refreshKey,
  }) {
    final request = Completer<UserTransactionPage>();
    requests.add(request);
    fromFilters.add(from);
    return request.future;
  }
}

void main() {
  test('older responses cannot replace a newer transaction filter', () async {
    final service = _PendingTransactionsService();
    final controller = UserTransactionsController(service: service);
    addTearDown(controller.dispose);

    final first = controller.loadInitial();
    final second = controller.setStatusFilter(UserTransactionStatus.success);
    expect(service.requests, hasLength(2));

    service.requests[1].complete(const UserTransactionPage(
      page: 1,
      limit: 100,
      total: 3,
      items: [],
    ));
    await second;
    service.requests[0].complete(const UserTransactionPage(
      page: 1,
      limit: 100,
      total: 1,
      items: [],
    ));
    await first;

    expect(controller.state.total, 3);
    expect(controller.state.selectedStatus, UserTransactionStatus.success);
  });

  test('all history sends a start date to bypass the server month default',
      () async {
    final service = _PendingTransactionsService();
    final controller = UserTransactionsController(service: service);
    addTearDown(controller.dispose);

    final request =
        controller.setRangePreset(UserTransactionsRangePreset.allTime);
    expect(service.fromFilters, ['1970-01-01T00:00:00.000Z']);
    service.requests.single.complete(const UserTransactionPage(
      page: 1,
      limit: 100,
      total: 0,
      items: [],
    ));
    await request;
    expect(controller.state.rangePreset, UserTransactionsRangePreset.allTime);
  });
}
