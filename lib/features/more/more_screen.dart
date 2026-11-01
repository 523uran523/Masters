import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/unified_booking/unified_booking_screen.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final settings = context.watch<SettingsController>();

    final tiles = <_MoreTile>[
      _MoreTile(
        icon: CupertinoIcons.person_2,
        title: 'Клиенты',
        subtitle: '${store.clients.length} карточек',
        screen: const ClientsScreen(),
      ),
      _MoreTile(
        icon: CupertinoIcons.cube,
        title: 'Склад',
        subtitle: '${store.inventoryItems.length} позиций',
        screen: const InventoryScreen(),
      ),
      if (settings.teamEnabled)
        _MoreTile(
          icon: CupertinoIcons.person,
          title: 'Сотрудники и зарплата',
          subtitle: '${store.employees.length} человек',
          screen: const EmployeesScreen(),
        ),
      if (settings.showAppointments)
        _MoreTile(
          icon: CupertinoIcons.calendar,
          title: 'Записи',
          subtitle: '${store.appointments.length} визитов',
          screen: const UnifiedBookingScreen(),
        ),
      _MoreTile(
        icon: CupertinoIcons.chart_bar,
        title: 'Аналитика',
        subtitle: 'P&L, срезами',
        screen: const StatsScreen(),
      ),
    ];

    if (settings.yandexConnected) {
      tiles.add(
        _MoreTile(
          icon: CupertinoIcons.cloud_fill,
          title: 'Облако',
          subtitle: 'Связь с Яндекс.Диск',
          screen: const SettingsScreen(),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Ещё')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          children: [
            Text(
              'Разделы приложения',
              style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
            ),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  for (final tile in tiles) ...[
                    CupertinoListTile(
                      leading: Icon(tile.icon, color: colors.accent),
                      title: Text(tile.title),
                      subtitle: tile.subtitle == null
                          ? null
                          : Text(tile.subtitle!),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                      ),
                      onTap: () => Navigator.of(
                        context,
                      ).push(CupertinoPageRoute(builder: (_) => tile.screen)),
                    ),
                    if (tile != tiles.last) const Hairline(indent: 56),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: CupertinoListTile(
                leading: Icon(CupertinoIcons.gear, color: colors.accent),
                title: const Text('Настройки'),
                subtitle: const Text(
                  'Аккаунт, деньги, синхронизация, PIN, биометрия',
                ),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
