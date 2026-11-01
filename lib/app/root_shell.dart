import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../core/single_tab_coordinator.dart';
import '../features/more/more_screen.dart';
import '../features/today/today_screen.dart';
import '../features/unified_booking/unified_booking_screen.dart';
import '../features/money/money_screen.dart';
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
  void initState() {
    super.initState();
    BrowserTabCoordinator.instance.addListener(() {
      if (mounted) setState(() {});
    });
    if (kIsWeb) BrowserTabCoordinator.instance.start();
  }

  @override
  void dispose() {
    BrowserTabCoordinator.instance.removeListener(() {
      if (mounted) setState(() {});
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsController>();
    final tabDefs = _buildTabDefs(settings.workMode);

    // Settings must remain reachable, otherwise the user could lock itself out.
    final visibleIndices = <int>[
      for (var i = 0; i < tabDefs.length; i++)
        if (settings.isTabVisible(i) || i == tabDefs.length - 1) i,
    ];
    if (visibleIndices.isEmpty) visibleIndices.add(tabDefs.length - 1);
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
        border: Border(top: BorderSide(color: colors.separator, width: 0.5)),
        items: [for (final i in visibleIndices) tabDefs[i].item],
      ),
      tabBuilder: (context, localIndex) {
        final global =
            visibleIndices[localIndex.clamp(0, visibleIndices.length - 1)];
        final showWarning =
            kIsWeb && BrowserTabCoordinator.instance.hasOtherActiveTabs;
        return Column(
          children: [
            if (showWarning)
              Container(
                width: double.infinity,
                color: colors.orange,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Приложение уже открыто в другой вкладке.',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: CupertinoTabView(
                builder: (context) => tabDefs[global].screen,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabDef {
  const _TabDef(this.icon, this.label, this.screen);

  final IconData icon;
  final String label;
  final Widget screen;

  BottomNavigationBarItem get item =>
      BottomNavigationBarItem(icon: Icon(icon, size: 23), label: label);
}

List<_TabDef> _buildTabDefs(String workMode) {
  final unifiedScreen = const UnifiedBookingScreen();
  final bookingTab = switch (workMode) {
    'appointments' => _TabDef(
      CupertinoIcons.calendar,
      'События',
      unifiedScreen,
    ),
    'hybrid' => _TabDef(CupertinoIcons.doc_text, 'События', unifiedScreen),
    _ => _TabDef(CupertinoIcons.doc_text, 'События', unifiedScreen),
  };
  return [
    _TabDef(CupertinoIcons.house, 'Сегодня', TodayScreen()),
    bookingTab,
    _TabDef(CupertinoIcons.money_dollar, 'Деньги', MoneyScreen()),
    _TabDef(CupertinoIcons.ellipsis_circle, 'Ещё', const MoreScreen()),
  ];
}
