import '../../../shared/models/vehicle_summary.dart';

/// One server directory page. Keeping pages separate from map scenes prevents
/// the viewport from changing the searchable fleet or its total.
class LiveMapFleetPage {
  const LiveMapFleetPage({
    this.rows = const [],
    this.total = 0,
    this.start = 0,
    this.nextCursor,
    this.previousCursor,
    this.queryRevision = '',
    this.scopeRevision = '',
  });

  final List<Map<String, dynamic>> rows;
  final int total;
  final int start;
  final String? nextCursor;
  final String? previousCursor;
  final String queryRevision;
  final String scopeRevision;
}

class LiveMapFleetView {
  const LiveMapFleetView({
    this.directory = const [],
    this.page = const LiveMapFleetPage(),
    this.clusters = const [],
    this.bounds,
    this.directoryLoading = false,
    this.directoryError,
  });

  final List<VehicleSummary> directory;
  final LiveMapFleetPage page;
  final List<Map<String, dynamic>> clusters;
  final List<double>? bounds;
  final bool directoryLoading;
  final String? directoryError;
}
