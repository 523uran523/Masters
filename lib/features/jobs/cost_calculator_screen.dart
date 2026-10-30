import 'package:flutter/cupertino.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';

class _ResourceLine {
  _ResourceLine({
    String name = '',
    String qty = '1',
    bool weight = false,
    String qtyUnit = 'г',
    String price = '0',
    String priceUnit = '100 г',
  })  : nameController = TextEditingController(text: name),
        qtyController = TextEditingController(text: qty),
        qtyUnitValue = qtyUnit,
        weightValue = weight,
        priceController = TextEditingController(text: price),
        priceUnitValue = priceUnit;

  final TextEditingController nameController;
  final TextEditingController qtyController;
  String qtyUnitValue;
  bool weightValue;
  final TextEditingController priceController;
  String priceUnitValue;

  double get qty => double.tryParse(qtyController.text.trim().replaceAll(',', '.')) ?? 0;

  int get totalCents {
    final price = double.tryParse(priceController.text.trim().replaceAll(',', '.')) ?? 0;
    if (!weightValue) {
      return (qty * price * 100).round();
    }
    // весовой расчёт: приводим количество к граммам
    double grams = qty;
    if (qtyUnitValue == 'кг') grams = qty * 1000;
    if (qtyUnitValue == 'т') grams = qty * 1000000;

    double divisor = 1;
    if (priceUnitValue == '100 г') divisor = 100;
    if (priceUnitValue == '1 кг') divisor = 1000;
    if (priceUnitValue == '1 т') divisor = 1000000;

    return ((grams / divisor) * price * 100).round();
  }

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class CostCalculatorScreen extends StatefulWidget {
  const CostCalculatorScreen({
    super.key,
    this.initialMaterialsCents = 0,
  });

  final int initialMaterialsCents;

  @override
  State<CostCalculatorScreen> createState() => _CostCalculatorScreenState();
}

class _CostCalculatorScreenState extends State<CostCalculatorScreen> {
  final List<_ResourceLine> _resources = [];
  final _laborHoursController = TextEditingController(text: '0');
  final _laborRateController = TextEditingController(text: '0');
  final _overheadController = TextEditingController(text: '0');
  final _otherController = TextEditingController(text: '0');
  final _marginController = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    if (widget.initialMaterialsCents > 0) {
      _resources.add(_ResourceLine(
        name: 'Материалы',
        qty: '1',
        weight: false,
        price: (widget.initialMaterialsCents / 100).toStringAsFixed(2),
      ));
    }
  }

  @override
  void dispose() {
    for (final r in _resources) {
      r.dispose();
    }
    _laborHoursController.dispose();
    _laborRateController.dispose();
    _overheadController.dispose();
    _otherController.dispose();
    _marginController.dispose();
    super.dispose();
  }

  double _d(String v) => double.tryParse(v.trim().replaceAll(',', '.')) ?? 0;

  int get _materialsCents => _resources.fold(0, (s, r) => s + r.totalCents);

  int get _laborCents {
    final hours = _d(_laborHoursController.text);
    final rate = _d(_laborRateController.text);
    return (hours * rate * 100).round();
  }

  int get _otherCents => (_d(_otherController.text) * 100).round();

  int get _baseCents => _materialsCents + _laborCents + _otherCents;

  int get _overheadCents {
    final p = _d(_overheadController.text);
    return (_baseCents * p / 100).round();
  }

  int get _costCents => _baseCents + _overheadCents;

  int get _priceCents {
    final m = _d(_marginController.text);
    return (_costCents * (1 + m / 100)).round();
  }

  void _addResource() {
    setState(() => _resources.add(_ResourceLine()));
  }

  void _removeResource(int index) {
    final r = _resources.removeAt(index);
    r.dispose();
    setState(() {});
  }

  void _apply() {
    Navigator.of(context).pop({
      'costCents': _costCents,
      'priceCents': _priceCents,
    });
  }

  Widget _segmented<T extends Object>({
    required T groupValue,
    required List<T> values,
    required List<String> labels,
    required ValueChanged<T?> onChanged,
  }) {
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: groupValue,
      onValueChanged: onChanged,
      children: {
        for (var i = 0; i < values.length; i++)
          values[i]: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(labels[i], style: const TextStyle(fontSize: 11)),
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Калькулятор расходов'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _apply,
          child: const Text('Применить'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          children: [
            SectionLabel('Ресурсы и материалы'),
            AppCard(
              child: Column(
                children: [
                  ..._resources.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoTextField(
                                  controller: r.nameController,
                                  placeholder: 'Наименование',
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 70,
                                child: CupertinoSlidingSegmentedControl<bool>(
                                  groupValue: r.weightValue,
                                  onValueChanged: (v) {
                                    if (v == null) return;
                                    setState(() => r.weightValue = v);
                                  },
                                  children: const {
                                    false: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                      child: Text('шт', style: TextStyle(fontSize: 11)),
                                    ),
                                    true: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                      child: Text('вес', style: TextStyle(fontSize: 11)),
                                    ),
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (!r.weightValue) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: r.qtyController,
                                    placeholder: 'Кол-во (шт)',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: r.priceController,
                                    placeholder: 'Цена за шт',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    prefix: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text('₽'),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${(r.totalCents / 100).toStringAsFixed(0)} ₽',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeResource(i),
                                  child: Icon(CupertinoIcons.xmark, size: 16, color: colors.tertiaryLabel),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: r.qtyController,
                                    placeholder: 'Количество',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 90,
                                  child: _segmented<String>(
                                    groupValue: r.qtyUnitValue,
                                    values: const ['г', 'кг'],
                                    labels: const ['г', 'кг'],
                                    onChanged: (v) {
                                      if (v != null) setState(() => r.qtyUnitValue = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: r.priceController,
                                    placeholder: 'Цена',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    prefix: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text('₽'),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 120,
                                  child: _segmented<String>(
                                    groupValue: r.priceUnitValue,
                                    values: const ['г', '100 г', '1 кг'],
                                    labels: const ['за г', 'за 100г', 'за кг'],
                                    onChanged: (v) {
                                      if (v != null) setState(() => r.priceUnitValue = v);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${(r.totalCents / 100).toStringAsFixed(0)} ₽',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeResource(i),
                                  child: Icon(CupertinoIcons.xmark, size: 16, color: colors.tertiaryLabel),
                                ),
                              ],
                            ),
                          ],
                          if (i < _resources.length - 1) const SizedBox(height: 4),
                        ],
                      ),
                    );
                  }),
                  SecondaryButton(
                    label: 'Добавить ресурс',
                    icon: CupertinoIcons.plus,
                    onPressed: _addResource,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Итого материалы', style: TextStyle(color: colors.secondaryLabel)),
                      const Spacer(),
                      Text('${(_materialsCents / 100).toStringAsFixed(0)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Работа'),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Часы', style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                        CupertinoTextField(
                          controller: _laborHoursController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ставка (₽/ч)', style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                        CupertinoTextField(
                          controller: _laborRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Итого', style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                      Text('${(_laborCents / 100).toStringAsFixed(0)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Накладные и маржа'),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Прочие расходы (₽)', style: TextStyle(color: colors.secondaryLabel))),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _otherController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text('Накладные (%)', style: TextStyle(color: colors.secondaryLabel))),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _overheadController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text('Маржа (%)', style: TextStyle(color: colors.secondaryLabel))),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _marginController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Итог'),
            AppCard(
              child: Column(
                children: [
                  _KV('База расходов', '${(_baseCents / 100).toStringAsFixed(0)} ₽'),
                  _KV('Накладные', '${(_overheadCents / 100).toStringAsFixed(0)} ₽'),
                  _KV('Итого расход', '${(_costCents / 100).toStringAsFixed(0)} ₽'),
                  _KV('Цена (с маржой)', '${(_priceCents / 100).toStringAsFixed(0)} ₽'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Применить', icon: CupertinoIcons.checkmark, onPressed: _apply),
          ],
        ),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: colors.secondaryLabel)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}