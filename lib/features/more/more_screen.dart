import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/unified_booking/unified_booking_screen.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';
import '../../state/sync_service.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final settings = context.watch<SettingsController>();
    final sync = context.watch<SyncService>();

    final workTiles = <_MoreTile>[
      _MoreTile(
        icon: CupertinoIcons.person_2,
        title: 'Клиенты',
        subtitle: countLabel(store.clients.length, const [
          'карточка',
          'карточки',
          'карточек',
        ]),
        screen: const ClientsScreen(),
      ),
      if (settings.showAppointments)
        _MoreTile(
          icon: CupertinoIcons.calendar,
          title: 'Записи',
          subtitle: countLabel(store.appointments.length, const [
            'визит',
            'визита',
            'визитов',
          ]),
          screen: const UnifiedBookingScreen(),
        ),
      _MoreTile(
        icon: CupertinoIcons.chart_bar,
        title: 'Аналитика',
        subtitle: 'P&L, срезы и экспорт',
        screen: const StatsScreen(),
      ),
    ];

    final resourceTiles = <_MoreTile>[
      _MoreTile(
        icon: CupertinoIcons.cube,
        title: 'Склад',
        subtitle: countLabel(store.inventoryItems.length, const [
          'позиция',
          'позиции',
          'позиций',
        ]),
        screen: const InventoryScreen(),
      ),
      if (settings.teamEnabled)
        _MoreTile(
          icon: CupertinoIcons.person,
          title: 'Команда',
          subtitle: countLabel(store.employees.length, const [
            'сотрудник',
            'сотрудника',
            'сотрудников',
          ]),
          screen: const EmployeesScreen(),
        ),
    ];

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Ещё')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          children: [
            Row(
              children: [
                Expanded(
                  child: SectionLabel(
                    'Работа',
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  ),
                ),
                if (settings.showAppointments)
                  ChipButton(
                    label: 'Записи',
                    icon: CupertinoIcons.calendar,
                    onPressed: () => _open(context, const UnifiedBookingScreen()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                children: [
                  for (var i = 0; i < workTiles.length; i++) ...[
                    if (i > 0) const Hairline(indent: 12),
                    _tile(context, workTiles[i], colors),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (resourceTiles.isNotEmpty) ...[
              SectionLabel('Склад и команда'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  children: [
                    for (var i = 0; i < resourceTiles.length; i++) ...[
                      if (i > 0) const Hairline(indent: 12),
                      _tile(context, resourceTiles[i], colors),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: ListRow(
                dense: true,
                icon: CupertinoIcons.gear,
                title: 'Настройки',
                subtitle: 'Деньги, склад, PIN, обновления',
                showChevron: true,
                onTap: () => _open(context, const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _open(context, const SettingsScreen()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.cloud,
                      size: 14,
                      color: sync.ready ? colors.accent : colors.tertiaryLabel,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sync.ready
                            ? 'Синхронизация: ${sync.spaceName}'
                            : 'Синхронизация не настроена',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.tertiaryLabel,
                        ),
                      ),
                    ),
                    if (sync.ready)
                      Text(
                        '${sync.pending}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.tertiaryLabel,
                        ),
                      )
                    else
                      Pill('Настроить', color: colors.accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, _MoreTile tile, AppColors colors) {
    return ListRow(
      dense: true,
      icon: tile.icon,
      title: tile.title,
      subtitle: tile.subtitle,
      showChevron: true,
      onTap: () => _open(context, tile.screen),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));
  }
}

class _MoreTile {
  const _MoreTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.screen,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget screen;
}
