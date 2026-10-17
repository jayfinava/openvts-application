import 'package:flutter/material.dart';

import '../../../../../shared/helpers/mobile_text.dart';
import '../../../../../shared/widgets/open_vts_button.dart';

/// One scrollable viewport keeps fields and actions reachable with the keyboard
/// or large accessibility text, without a fixed footer overflowing the drawer.
class UserAccountFormSheet extends StatelessWidget {
  const UserAccountFormSheet(
      {super.key,
      required this.formKey,
      required this.title,
      required this.fields,
      required this.submitting,
      required this.attempted,
      required this.onSubmit});
  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> fields;
  final bool submitting, attempted;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: Form(
            key: formKey,
            autovalidateMode: attempted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: SingleChildScrollView(
              controller: PrimaryScrollController.maybeOf(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  for (final field in fields) ...[
                    field,
                    const SizedBox(height: 12)
                  ],
                  const Divider(),
                  const SizedBox(height: 8),
                  Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OpenVtsButton(
                            label: context.mobileText('Cancel'),
                            variant: OpenVtsButtonVariant.secondary,
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(context).pop()),
                        OpenVtsButton(
                            label: title,
                            isLoading: submitting,
                            onPressed: submitting ? null : onSubmit),
                      ]),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ),
      );
}
