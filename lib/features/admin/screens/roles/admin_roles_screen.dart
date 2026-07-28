import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/open_vts_colors.dart';
import '../../../../core/theme/open_vts_radius.dart';
import '../../../../core/theme/open_vts_spacing.dart';
import '../../../../core/theme/open_vts_typography.dart';
import '../../../../shared/widgets/open_vts_page_scaffold.dart';

class AdminRolesScreen extends ConsumerWidget {
  const AdminRolesScreen({super.key});

  static const List<_RoleDefinition> _roles = [
    _RoleDefinition(
      name: 'Admin',
      icon: Icons.admin_panel_settings_outlined,
      description:
          'Full access to the tenant. Can manage users, vehicles, drivers, inventory, payments, support tickets, settings, and reports.',
      permissions: [
        'Manage users & sub-users',
        'Manage vehicles & devices',
        'Manage drivers',
        'View & manage inventory',
        'View payments & transactions',
        'Renew vehicle subscriptions',
        'Manage pricing plans',
        'Manage team members',
        'View & respond to support tickets',
        'Configure SMTP & notifications',
        'View activity, event & telemetry logs',
        'Access map & live telemetry',
        'View calendar events',
        'Update profile & localization',
        'Manage company branding',
      ],
    ),
    _RoleDefinition(
      name: 'User',
      icon: Icons.person_outline_rounded,
      description:
          'Fleet customer. Can view and manage assigned vehicles, geofences, routes, POIs, and reports within their account.',
      permissions: [
        'View assigned vehicles',
        'Access live map',
        'View vehicle history & replay',
        'Manage geofences, POIs, routes',
        'Create & manage share track links',
        'Manage sub-users',
        'Manage drivers',
        'Generate reports',
        'View transactions',
        'Submit support tickets',
        'Configure notification preferences',
        'Update profile & localization',
      ],
    ),
    _RoleDefinition(
      name: 'Subuser',
      icon: Icons.people_outline_rounded,
      description:
          'Delegated identity under a User account. Access is limited to vehicles explicitly assigned by the parent user.',
      permissions: [
        'View assigned vehicles',
        'Access live map (scoped)',
        'View vehicle history & replay (scoped)',
        'View notifications (scoped)',
        'Geocoding lookups',
      ],
    ),
    _RoleDefinition(
      name: 'Driver',
      icon: Icons.badge_outlined,
      description:
          'Driver identity. Can be linked to users and vehicles. Access is limited to geocoding and shared realtime paths.',
      permissions: [
        'Geocoding lookups',
        'Realtime telemetry (linked vehicles)',
      ],
    ),
    _RoleDefinition(
      name: 'Team',
      icon: Icons.groups_2_outlined,
      description:
          'Team member managed by the Admin. Supports shared geocoding and realtime authorization paths.',
      permissions: [
        'Geocoding lookups',
        'Realtime telemetry (authorized)',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OpenVtsPageScaffold(
      title: 'Roles & Permissions',
      headerMode: OpenVtsPageHeaderMode.closeable,
      body: ListView.separated(
        padding: const EdgeInsets.all(OpenVtsSpacing.lg),
        itemCount: _roles.length,
        separatorBuilder: (_, __) => const SizedBox(height: OpenVtsSpacing.md),
        itemBuilder: (context, index) {
          return _RoleCard(role: _roles[index]);
        },
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.role});

  final _RoleDefinition role;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white12 : OpenVtsColors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(OpenVtsRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(OpenVtsRadius.lg),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(OpenVtsSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                    ),
                    child: Icon(
                      widget.role.icon,
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: OpenVtsSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role.name,
                          style: OpenVtsTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.role.description,
                          style: OpenVtsTypography.meta.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: OpenVtsSpacing.xs),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OpenVtsSpacing.md,
                0,
                OpenVtsSpacing.md,
                OpenVtsSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: borderColor, height: 1),
                  const SizedBox(height: OpenVtsSpacing.sm),
                  Text(
                    'Capabilities',
                    style: OpenVtsTypography.meta.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: OpenVtsSpacing.xs),
                  ...widget.role.permissions.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: OpenVtsSpacing.xs / 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: OpenVtsSpacing.xs),
                          Expanded(
                            child: Text(
                              p,
                              style: OpenVtsTypography.body.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleDefinition {
  const _RoleDefinition({
    required this.name,
    required this.icon,
    required this.description,
    required this.permissions,
  });

  final String name;
  final IconData icon;
  final String description;
  final List<String> permissions;
}
