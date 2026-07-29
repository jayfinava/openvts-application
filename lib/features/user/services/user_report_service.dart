import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_options.dart';
import '../models/user_report_model.dart';

class UserReportService {
  UserReportService(this._apiClient);

  final ApiClient _apiClient;

  Future<UserReportOptions> getOptions() async {
    debugPrint('[Reports] GET ${ApiEndpoints.user.reportOptions}');
    try {
      final response = await _apiClient.get<UserReportOptions>(
        ApiEndpoints.user.reportOptions,
        options: normalReadOptions(),
        parser: UserReportOptions.fromJson,
      );
      debugPrint(
          '[Reports] options loaded: ${response.data.vehicles.length} vehicles, '
          '${response.data.groups.length} groups');
      return response.data;
    } catch (e) {
      debugPrint('[Reports] options error: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<UserReportPage> generate({
    required UserReportKey reportKey,
    required Map<String, dynamic> vehicleScope,
    required Map<String, dynamic> dateRange,
    required Map<String, dynamic> filters,
    required String timeZone,
    required DateTime from,
    required DateTime to,
    String? cursor,
  }) async {
    debugPrint(
        '[Reports] POST ${ApiEndpoints.user.reportByKey(reportKey.apiValue)} '
        'scope=${vehicleScope['mode']} tz=$timeZone cursor=${cursor ?? 'none'}');
    final response = await _apiClient.post<UserReportPage>(
      ApiEndpoints.user.reportByKey(reportKey.apiValue),
      data: <String, dynamic>{
        'vehicleScope': vehicleScope,
        'dateRange': dateRange,
        'filters': filters,
        'timeZone': timeZone,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (cursor?.trim().isNotEmpty == true) 'cursor': cursor!.trim(),
      },
      options: reportGenerateOptions(),
      parser: UserReportPage.fromJson,
    );
    return response.data;
  }

  Future<List<UserTimelinePoint>> getTimelineMap({
    required String vehicleId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _apiClient.post<List<UserTimelinePoint>>(
      ApiEndpoints.user.reportTimelineMap,
      data: <String, dynamic>{
        'vehicleId': vehicleId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
      options: normalWriteOptions(),
      parser: (json) => reportList(reportMap(json)['points'])
          .map(UserTimelinePoint.fromJson)
          .where((point) => point.isValid)
          .toList(growable: false),
    );
    return response.data;
  }
}
