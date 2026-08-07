import 'package:flutter/material.dart';

import '../../core/theme/open_vts_spacing.dart';

class SearchableDropdownItem<T> {
  const SearchableDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.searchTerms = const <String>[],
  });

  final T value;
  final String label;

  /// Optional second line shown in the search sheet list tile.
  final String? subtitle;

  /// Extra strings searched alongside [label] (e.g. email, username).
  /// Not displayed — used only for filtering.
  final List<String> searchTerms;

  bool matchesQuery(String q) {
    if (q.isEmpty) return true;
    if (label.toLowerCase().contains(q)) return true;
    if (subtitle != null && subtitle!.toLowerCase().contains(q)) return true;
    return searchTerms.any((t) => t.toLowerCase().contains(q));
  }
}

/// A [FormField] that shows the selected label in a tappable outlined tile
/// and opens a bottom-sheet with a live search bar + scrollable item list.
class SearchableDropdownField<T> extends FormField<T> {
  SearchableDropdownField({
    required String label,
    required List<SearchableDropdownItem<T>> items,
    required ValueChanged<T?> onChanged,
    super.initialValue,
    super.validator,
    super.enabled = true,
    String hintText = 'Select',
    String searchHint = 'Search…',
    super.key,
  }) : super(
          builder: (field) {
            final selectedLabel = items
                .where((i) => i.value == field.value)
                .map((i) => i.label)
                .firstOrNull;

            return _SearchableDropdownTile<T>(
              label: label,
              hintText: hintText,
              searchHint: searchHint,
              selectedLabel: selectedLabel,
              items: items,
              enabled: enabled,
              errorText: field.errorText,
              onSelected: (v) {
                field.didChange(v);
                onChanged(v);
              },
            );
          },
        );
}

class _SearchableDropdownTile<T> extends StatelessWidget {
  const _SearchableDropdownTile({
    required this.label,
    required this.hintText,
    required this.searchHint,
    required this.selectedLabel,
    required this.items,
    required this.enabled,
    required this.onSelected,
    this.errorText,
    super.key,
  });

  final String label;
  final String hintText;
  final String searchHint;
  final String? selectedLabel;
  final List<SearchableDropdownItem<T>> items;
  final bool enabled;
  final String? errorText;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null;
    final borderColor = hasError
        ? theme.colorScheme.error
        : theme.inputDecorationTheme.enabledBorder?.borderSide.color ??
            theme.colorScheme.outline;
    final focusColor =
        hasError ? theme.colorScheme.error : theme.colorScheme.primary;
    final disabledColor = theme.disabledColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: enabled ? () => _openSheet(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: errorText,
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                color: enabled ? null : disabledColor,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: focusColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: theme.colorScheme.error, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: disabledColor),
              ),
            ),
            isEmpty: selectedLabel == null,
            child: Text(
              selectedLabel ?? hintText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? (selectedLabel == null
                        ? theme.hintColor
                        : theme.colorScheme.onSurface)
                    : disabledColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SearchSheet<T>(
        title: label,
        searchHint: searchHint,
        items: items,
      ),
    );
    if (result != null) {
      onSelected(result);
    }
  }
}

class _SearchSheet<T> extends StatefulWidget {
  const _SearchSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    super.key,
  });

  final String title;
  final String searchHint;
  final List<SearchableDropdownItem<T>> items;

  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  final _controller = TextEditingController();
  List<SearchableDropdownItem<T>> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _controller.addListener(_onQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQuery() {
    final q = _controller.text.trim().toLowerCase();
    setState(() {
      _filtered =
          widget.items.where((i) => i.matchesQuery(q)).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: OpenVtsSpacing.xs),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: OpenVtsSpacing.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: OpenVtsSpacing.md),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: OpenVtsSpacing.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: OpenVtsSpacing.md),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (_, val, __) => val.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _controller.clear,
                          ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: OpenVtsSpacing.sm,
                    vertical: OpenVtsSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(height: OpenVtsSpacing.xs),
            const Divider(height: 1),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No results',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(item.label),
                          subtitle: item.subtitle != null
                              ? Text(
                                  item.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(item.value),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
