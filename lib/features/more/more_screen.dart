import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';
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

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Ещё')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          children: [
            SectionLabel('Отчёты'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: ListRow(
                dense: true,
                icon: CupertinoIcons.chart_bar,
                title: 'Аналитика',
                subtitle: 'P&L, срезы и экспорт',
                showChevron: true,
                onTap: () => _open(context, const StatsScreen()),
              ),
            ),
            if (settings.teamEnabled) ...[
              const SizedBox(height: 16),
              SectionLabel('Сотрудники'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: ListRow(
                  dense: true,
                  icon: CupertinoIcons.person,
                  title: 'Команда',
                  subtitle: countLabel(store.employees.length, const [
                    'сотрудник',
                    'сотрудника',
                    'сотрудников',
                  ]),
                  showChevron: true,
                  onTap: () => _open(context, const EmployeesScreen()),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SectionLabel('Приложение'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                children: [
                  ListRow(
                    dense: true,
                    icon: CupertinoIcons.gear,
                    title: 'Настройки',
                    subtitle: 'Деньги, склад, PIN, обновления',
                    showChevron: true,
                    onTap: () => _open(context, const SettingsScreen()),
                  ),
                  const Hairline(indent: 12),
                  ListRow(
                    dense: true,
                    icon: CupertinoIcons.cloud,
                    title: sync.ready
                        ? 'Синхронизация'
                        : 'Синхронизация не настроена',
                    subtitle: sync.ready
                        ? '${sync.spaceName} · ${sync.pending} в очереди'
                        : 'Яндекс.Диск или свой сервер',
                    trailing: Pill(
                      sync.ready ? 'OK' : 'Настроить',
                      color: sync.ready ? colors.green : colors.accent,
                    ),
                    showChevron: false,
                    onTap: () => _open(context, const SettingsScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));
  }
}
