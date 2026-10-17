import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/api/auth_api_error.dart';
import '../../../../../shared/helpers/mobile_text.dart';
import '../../../../../shared/helpers/toast_helper.dart';
import '../../../../../shared/models/user_role.dart';
import '../../../../../shared/widgets/open_vts_button.dart';
import '../../../../auth/controllers/auth_controller.dart';
import '../../../controllers/user_child_session_controller.dart';

class UserChildLoginButton extends ConsumerWidget {
  const UserChildLoginButton({
    super.key,
    required this.id,
    required this.role,
    required this.isActive,
  });
  final String id;
  final UserRole role;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isRealSession || auth.role != UserRole.user) {
      return const SizedBox.shrink();
    }
    final loggingIn = ref.watch(userChildSessionControllerProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OpenVtsButton(
        label: context.mobileText('Login'),
        trailingIcon: Icons.login_rounded,
        height: 48,
        variant: OpenVtsButtonVariant.secondary,
        isLoading: loggingIn == '${role.name}:$id',
        onPressed: !isActive || id.isEmpty || loggingIn != null
            ? null
            : () async {
                try {
                  await ref
                      .read(userChildSessionControllerProvider.notifier)
                      .login(id, role);
                  // Auth routing follows the verified session's actual role.
                } catch (error) {
                  if (context.mounted) {
                    ToastHelper.showError(
                      AuthApiError.message(error),
                      context: context,
                    );
                  }
                }
              },
      ),
    );
  }
}
