import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:open_vts/shared/paging/server_list_pager.dart';

void main() {
  test('direct action envelope preserves both rows and pagination metadata',
      () async {
    final h = _Harness((r) => _page(r), direct: true);
    addTearDown(h.dispose);
    await h.pager.load();
    expect(h.pager.meta!.total, 10000);
    expect(h.pager.items, hasLength(20));
    expect(h.requests, hasLength(1));
  });
  test('10K rows: only the requested page is fetched, retained, and replaced',
      () async {
    final h = _Harness((r) => _page(r));
    addTearDown(h.dispose);
    expect(h.requests, isEmpty);
    await h.pager.load();
    expect(h.requests, hasLength(1));
    expect(h.pager.meta!.total, 10000);
    expect(h.pager.meta!.pages, 500);
    expect(h.pager.items, List.generate(20, (i) => i + 1));
    await h.pager.goToPage(400);
    expect(h.requests, hasLength(2));
    expect(h.requests.last.queryParameters['page'], 400);
    expect(h.requests.last.queryParameters['limit'], 20);
    expect(h.pager.items, List.generate(20, (i) => 7981 + i));
    expect(h.pager.meta!.page, 400);
    expect(() => h.pager.items.add(999), throwsUnsupportedError);
  });

  test('search is global, debounced, resets to page one, and never prefetches',
      () async {
    final h = _Harness((r) => _page(r));
    addTearDown(h.dispose);
    await h.pager.load();
    await h.pager.goToPage(4);
    await h.pager.change(page: 1, search: 've', debounce: true);
    await h.pager.change(page: 1, search: 'vehicle 9999', debounce: true);
    expect(h.requests, hasLength(2));
    await Future<void>.delayed(const Duration(milliseconds: 420));
    expect(h.requests, hasLength(3));
    expect(h.requests.last.queryParameters['search'], 'vehicle 9999');
    expect(h.pager.items, [9999]);
    expect(h.pager.meta!.total, 1);
    expect(h.pager.meta!.page, 1);
  });

  test('late canceled pages cannot overwrite a newer search', () async {
    final old = Completer<dynamic>();
    final started = Completer<void>();
    final h = _Harness((r) {
      if (r.queryParameters['page'] == 2) {
        started.complete();
        return old.future;
      }
      return _page(r);
    });
    addTearDown(h.dispose);
    await h.pager.load();
    final stale = h.pager.goToPage(2);
    await started.future;
    await h.pager.change(page: 1, search: 'vehicle 9999');
    old.complete(_page(h.requests.first));
    await stale;
    expect(h.pager.items, [9999]);
    expect(h.pager.meta!.page, 1);
    expect(h.pager.error, isNull);
  });

  test(
      'failed page retains the committed page and retries that failed query once',
      () async {
    var failures = 1;
    final h = _Harness((r) {
      if (r.queryParameters['page'] == 3 && failures-- > 0) {
        throw DioException(
            requestOptions: r,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: r, statusCode: 503));
      }
      return _page(r);
    });
    addTearDown(h.dispose);
    await h.pager.load();
    await h.pager.goToPage(3);
    expect(h.pager.meta!.page, 1);
    expect(h.pager.items.first, 1);
    expect(h.pager.error, isNotNull);
    expect(h.pager.loading, false);
    await h.pager.load();
    expect(h.pager.meta!.page, 3);
    expect(h.requests, hasLength(3));
    expect(h.pager.error, isNull);
  });

  test('last-page deletion corrects to a valid page with one bounded read',
      () async {
    var total = 10000;
    final h = _Harness((r) => _page(r, total: total));
    addTearDown(h.dispose);
    await h.pager.load();
    await h.pager.goToPage(500);
    total = 9980;
    await h.pager.load();
    expect(
        h.requests.map((r) => r.queryParameters['page']), [1, 500, 500, 499]);
    expect(h.pager.meta!.page, 499);
    expect(h.pager.items, hasLength(20));
  });

  for (final invalid in ['unpaged', 'oversized', 'wrong page', 'wrong size']) {
    test('rejects $invalid responses without downloading further pages',
        () async {
      final h = _Harness((r) {
        final payload = _page(r);
        if (invalid == 'unpaged') return payload['data'];
        if (invalid == 'oversized') (payload['data'] as List).add({'id': 21});
        if (invalid == 'wrong page') (payload['pagination'] as Map)['page'] = 2;
        if (invalid == 'wrong size') {
          (payload['pagination'] as Map)['limit'] = 100;
        }
        return payload;
      });
      addTearDown(h.dispose);
      await h.pager.load();
      expect(h.requests, hasLength(1));
      expect(h.pager.items, isEmpty);
      expect(h.pager.error, isNotNull);
      expect(h.pager.loading, false);
    });
  }

  test('filters, sorting, and page size are sent to the backend together',
      () async {
    final h = _Harness((r) => _page(r));
    addTearDown(h.dispose);
    await h.pager.change(
        page: 1,
        limit: 50,
        search: ' truck ',
        sortBy: 'createdAt',
        sortDir: 'desc',
        filters: {'status': false, 'vehicleTypeName': 'Truck'});
    final q = h.requests.single.queryParameters;
    expect(q['limit'], 50);
    expect(q['search'], 'truck');
    expect(q['sortBy'], 'createdAt');
    expect(q['sortDir'], 'desc');
    expect(jsonDecode(q['filters']),
        {'status': false, 'vehicleTypeName': 'Truck'});
  });

  test(
      'same query does not refetch and explicit refresh requests only its page',
      () async {
    final h = _Harness((r) => _page(r));
    addTearDown(h.dispose);
    await h.pager.load();
    await h.pager.goToPage(1);
    expect(h.requests, hasLength(1));
    await h.pager.load();
    expect(h.requests, hasLength(2));
  });

  test('dispose cancels search timers and pending HTTP publications', () async {
    final h = _Harness((r) => _page(r));
    await h.pager.change(search: 'not sent', debounce: true);
    h.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    expect(h.requests, isEmpty);
  });

  test('an account change discards a response from the earlier workspace',
      () async {
    final pending = Completer<dynamic>();
    final started = Completer<void>();
    var user = _user('1');
    final h = _Harness((r) {
      started.complete();
      return pending.future;
    }, activeUser: () => user);
    addTearDown(h.dispose);
    final request = h.pager.load();
    await started.future;
    user = _user('2');
    pending.complete(_page(h.requests.single));
    await request;
    expect(h.pager.items, isEmpty);
  });
}

CurrentUser _user(String id) =>
    CurrentUser(id: id, name: 'Account', email: '', role: UserRole.admin);

Map<String, dynamic> _page(RequestOptions r, {int total = 10000}) {
  final page = r.queryParameters['page'] as int;
  final limit = r.queryParameters['limit'] as int;
  final search = r.queryParameters['search'] == 'vehicle 9999';
  final start = (page - 1) * limit;
  return {
    'data': search
        ? [
            {'id': 9999}
          ]
        : [
            for (var i = start; i < start + limit && i < total; i++)
              {'id': i + 1}
          ],
    'pagination': {'page': page, 'limit': limit, 'total': search ? 1 : total},
  };
}

class _Harness {
  _Harness(FutureOr<dynamic> Function(RequestOptions) respond,
      {CurrentUser? Function()? activeUser, bool direct = false}) {
    dio = Dio(BaseOptions(baseUrl: 'https://fleet.example/api'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) async {
      requests.add(r);
      try {
        final result = await respond(r);
        h.resolve(Response(
            requestOptions: r,
            statusCode: 200,
            data: direct
                ? {'action': true, 'data': result}
                : {
                    'status': 'success',
                    'data': {'action': true, 'data': result}
                  }));
      } catch (e) {
        h.reject(
            e is DioException ? e : DioException(requestOptions: r, error: e));
      }
    }));
    pager = ServerListPager<int>(
        api: ApiClient(dio, activeUser: activeUser),
        endpoint: '/admin/vehicles',
        parseRows: (rows) =>
            [for (final row in rows as List) (row as Map)['id'] as int]);
  }
  late final Dio dio;
  late final ServerListPager<int> pager;
  final requests = <RequestOptions>[];
  void dispose() {
    pager.dispose();
    dio.close(force: true);
  }
}
