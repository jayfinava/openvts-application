import '../../features/superadmin/models/superadmin_vehicle_model.dart';

/// Deduplicates and sorts a raw list of custom commands fetched from any
/// role endpoint (superadmin / admin / user).
///
/// Priority:
///   1. Unique by [SuperadminCustomCommand.id] (stable backend ID wins).
///   2. When the backend repeats semantically identical records under different
///      wrappers, a composite key of deviceTypeId + commandTypeId + normalised
///      command text is used.
///
/// Two commands with the same display title but different command text are
/// kept as separate entries.
///
/// The result is sorted by commandTypeName then command text, matching the
/// ordering the backend applies server-side.
List<SuperadminCustomCommand> deduplicateLiveMapCommandCatalogue(
    List<SuperadminCustomCommand> raw) {
  final seenIds = <String>{};
  final seenCompositeKeys = <String>{};
  final result = <SuperadminCustomCommand>[];

  for (final cmd in raw) {
    final id = cmd.id.trim();

    if (id.isNotEmpty && seenIds.contains(id)) continue;

    final compositeKey = _compositeKey(cmd);
    if (seenCompositeKeys.contains(compositeKey)) continue;

    if (id.isNotEmpty) seenIds.add(id);
    seenCompositeKeys.add(compositeKey);
    result.add(cmd);
  }

  result.sort((a, b) {
    final typeA = (a.commandTypeName ?? '').toLowerCase();
    final typeB = (b.commandTypeName ?? '').toLowerCase();
    final typeCmp = typeA.compareTo(typeB);
    if (typeCmp != 0) return typeCmp;
    return a.command.toLowerCase().compareTo(b.command.toLowerCase());
  });

  return result;
}

String _compositeKey(SuperadminCustomCommand cmd) {
  final deviceType = cmd.deviceTypeId?.toString() ?? '';
  final commandType = cmd.commandTypeId?.toString() ?? '';
  final text = cmd.command.trim().toLowerCase();
  return '$deviceType|$commandType|$text';
}
