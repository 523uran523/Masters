import 'package:flutter/cupertino.dart';

import '../features/today/today_screen.dart';
import '../features/jobs/jobs_screen.dart';
import '../features/clients/clients_screen.dart';
import '../features/booking/booking_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/money/money_screen.dart';
import '../features/settings/settings_screen.dart';
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

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        backgroundColor: colors.bar,
        activeColor: colors.accent,
        inactiveColor: colors.secondaryLabel,
        border: Border(
          top: BorderSide(color: colors.separator, width: 0.5),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house, size: 23),
            label: 'Сегодня',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text, size: 23),
            label: 'Заказы',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2, size: 23),
            label: 'Клиенты',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.money_dollar, size: 23),
            label: 'Деньги',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cube, size: 23),
            label: 'Склад',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar, size: 23),
            label: 'Запись',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear, size: 23),
            label: 'Настройки',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return switch (index) {
          0 => CupertinoTabView(builder: (context) => const TodayScreen()),
          1 => CupertinoTabView(builder: (context) => const JobsScreen()),
          2 => CupertinoTabView(builder: (context) => const ClientsScreen()),
          3 => CupertinoTabView(builder: (context) => const MoneyScreen()),
          4 => CupertinoTabView(builder: (context) => const InventoryScreen()),
          5 => CupertinoTabView(builder: (context) => const BookingScreen()),
          _ => CupertinoTabView(builder: (context) => const SettingsScreen()),
        };
      },
    );
  }
}