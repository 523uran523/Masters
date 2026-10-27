import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../state/settings_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  String _businessType = 'auto';
  String _team = 'solo';
  String _workMode = 'orders';
  bool _sellsGoods = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = context.read<SettingsController>();
    await settings.setBusinessType(_businessType);
    // modules
    final modules = <String>['money', 'orders', 'clients'];
    if (_team == 'team') modules.add('employees');
    if (_sellsGoods) modules.add('inventory');
    if (_workMode == 'booking') modules.add('booking');
    await settings.setModules(modules);
    // terms
    switch (_businessType) {
      case 'auto':
        await settings.setObjectTerm('Автомобиль');
        await settings.setClientTerm('Клиент');
        break;
      case 'bakery':
        await settings.setObjectTerm('Изделие');
        await settings.setClientTerm('Покупатель');
        break;
      case 'barber':
        await settings.setObjectTerm('Клиент');
        await settings.setClientTerm('Клиент');
        break;
      default:
        await settings.setObjectTerm('Объект');
        await settings.setClientTerm('Клиент');
    }
    await settings.completeOnboarding();
  }

  void _next() {
    if (_page < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _pageWrap(
                    title: 'Чем занимаетесь?',
                    child: Column(
                      children: [
                        _choice('Шиномонтаж / автосервис', 'auto', _businessType, (v) => setState(() => _businessType = v)),
                        _choice('Пекарня / кондитерская', 'bakery', _businessType, (v) => setState(() => _businessType = v)),
                        _choice('Барбер / салон', 'barber', _businessType, (v) => setState(() => _businessType = v)),
                        _choice('Мастерская / ремонт', 'repair', _businessType, (v) => setState(() => _businessType = v)),
                        _choice('Другое', 'other', _businessType, (v) => setState(() => _businessType = v)),
                      ],
                    ),
                  ),
                  _pageWrap(
                    title: 'Работаете одни или с командой?',
                    child: Column(
                      children: [
                        _choice('Я один', 'solo', _team, (v) => setState(() => _team = v)),
                        _choice('Есть сотрудники', 'team', _team, (v) => setState(() => _team = v)),
                      ],
                    ),
                  ),
                  _pageWrap(
                    title: 'Как принимаете клиентов?',
                    child: Column(
                      children: [
                        _choice('По записи (календарь)', 'booking', _workMode, (v) => setState(() => _workMode = v)),
                        _choice('Заказы со сроком', 'orders', _workMode, (v) => setState(() => _workMode = v)),
                        _choice('Продаю на месте', 'counter', _workMode, (v) => setState(() => _workMode = v)),
                      ],
                    ),
                  ),
                  _pageWrap(
                    title: 'Продаёте товары?',
                    child: Column(
                      children: [
                        _choice('Только услуги', 'services', _sellsGoods ? 'goods' : 'services', (v) => setState(() => _sellsGoods = v == 'goods')),
                        _choice('Услуги и товары', 'goods', _sellsGoods ? 'goods' : 'services', (v) => setState(() => _sellsGoods = v == 'goods')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Text('Шаг ${_page + 1} из 4', style: TextStyle(color: colors.secondaryLabel)),
                  const SizedBox(height: 8),
                  PrimaryButton(label: _page < 3 ? 'Далее' : 'Начать работу', onPressed: _next),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageWrap({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _choice(String label, String value, String current, ValueChanged<String> onSelect) {
    final selected = value == current;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => onSelect(value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? colors.accent : colors.cardElevated,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFFFFFFFF) : colors.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}