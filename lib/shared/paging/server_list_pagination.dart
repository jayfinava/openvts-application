import 'package:flutter/material.dart';

import '../helpers/mobile_text.dart';
import 'server_list_pager.dart';

class ServerListPagination extends StatelessWidget {
  const ServerListPagination(
      {super.key,
      required this.meta,
      required this.loading,
      required this.onPageChanged});
  final ListPageMeta? meta;
  final bool loading;
  final Future<void> Function(int) onPageChanged;

  Future<void> _go(BuildContext context, int page) async {
    FocusScope.of(context).unfocus();
    await onPageChanged(page);
    if (!context.mounted) return;
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != null && scroll.hasContentDimensions) {
      await scroll.animateTo(scroll.minScrollExtent,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = meta;
    if (p == null) return const SizedBox.shrink();
    final pages = <int>{
      1,
      p.pages,
      p.page,
      for (var n = p.page - 2; n <= p.page + 2; n++)
        if (n >= 1 && n <= p.pages) n
    }.toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(context.mobileText('{value1} rows', {'value1': '${p.total}'})),
          Text(context.mobileText('Page {value1} of {value2}', {
            'value1': '${p.page}',
            'value2': '${p.pages}',
          })),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                tooltip: context.mobileText('Previous page'),
                onPressed: loading || p.page <= 1
                    ? null
                    : () => _go(context, p.page - 1),
                icon: const Icon(Icons.chevron_left)),
            DropdownButton<int>(
                value: p.page,
                items: [
                  for (final page in pages)
                    DropdownMenuItem(value: page, child: Text('$page'))
                ],
                onChanged: loading
                    ? null
                    : (page) {
                        if (page != null) _go(context, page);
                      }),
            IconButton(
                tooltip: context.mobileText('Next page'),
                onPressed: loading || p.page >= p.pages
                    ? null
                    : () => _go(context, p.page + 1),
                icon: const Icon(Icons.chevron_right)),
          ]),
          if (loading)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
