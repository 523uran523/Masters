import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../features/today/today_screen.dart';
import '../features/jobs/jobs_screen.dart';
import '../features/clients/clients_screen.dart';
import '../features/booking/booking_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/money/money_screen.dart';
import '../features/settings/settings_screen.dart';
import '../state/settings_controller.dart';
import 'theme/app_theme.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsController>();

    // Settings must remain reachable, otherwise the user could lock itself out.
    final visibleIndices = <int>[
      for (var i = 0; i < _tabDefs.length; i++)
        if (settings.isTabVisible(i) || i == _tabDefs.length - 1) i,
    ];
    if (visibleIndices.isEmpty) visibleIndices.add(_tabDefs.length - 1);
    if (_index >= visibleIndices.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 0);
      });
    }
    final safeIndex = _index.clamp(0, visibleIndices.length - 1);

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: safeIndex,
        onTap: (index) => setState(() => _index = index),
        backgroundColor: colors.bar,
        activeColor: colors.accent,
        inactiveColor: colors.secondaryLabel,
        border: Border(
          top: BorderSide(color: colors.separator, width: 0.5),
        ),
        items: [
          for (final i in visibleIndices) _tabDefs[i].item,
        ],
      ),
      tabBuilder: (context, localIndex) {
        final global = visibleIndices[localIndex.clamp(0, visibleIndices.length - 1)];
        return CupertinoTabView(builder: (context) => _tabDefs[global].screen);
      },
    );
  }
}

class _TabDef {
  const _TabDef(this.icon, this.label, this.screen);

  final IconData icon;
  final String label;
  final Widget screen;

  BottomNavigationBarItem get item => BottomNavigationBarItem(
        icon: Icon(icon, size: 23),
        label: label,
      );
}

const List<_TabDef> _tabDefs = [
  _TabDef(CupertinoIcons.house, 'Сегодня', TodayScreen()),
  _TabDef(CupertinoIcons.doc_text, 'Заказы', JobsScreen()),
  _TabDef(CupertinoIcons.person_2, 'Клиенты', ClientsScreen()),
  _TabDef(CupertinoIcons.money_dollar, 'Деньги', MoneyScreen()),
  _TabDef(CupertinoIcons.cube, 'Склад', InventoryScreen()),
  _TabDef(CupertinoIcons.calendar, 'Бронь', BookingScreen()),
  _TabDef(CupertinoIcons.gear, 'Настройки', SettingsScreen()),
];
