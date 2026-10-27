import 'package:flutter/cupertino.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';

class _ResourceLine {
  _ResourceLine({
    String name = '',
    String qty = '1',
    String unit = 'шт',
    String price = '0',
  })  : nameController = TextEditingController(text: name),
        qtyController = TextEditingController(text: qty),
        unitController = TextEditingController(text: unit),
        priceController = TextEditingController(text: price);

  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController unitController;
  final TextEditingController priceController;

  double get qty => double.tryParse(qtyController.text.trim().replaceAll(',', '.')) ?? 0;
  int get unitPriceCents => ((double.tryParse(priceController.text.trim().replaceAll(',', '.')) ?? 0) * 100).round();
  int get totalCents => (unitPriceCents * qty).round();

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    unitController.dispose();
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
        unit: 'компл',
        price: (widget.initialMaterialsCents / 100).toStringAsFixed(2),
      ));
    }
  }

  @override
  void dispose() {
    for (final r in _resources) { r.dispose(); }
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // trigger rebuild on text changes
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SectionLabel('Ресурсы и материалы'),
            AppCard(
              child: Column(
                children: [
                  ..._resources.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: CupertinoTextField(
                                  controller: r.nameController,
                                  placeholder: 'Наименование',
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: CupertinoTextField(
                                  controller: r.qtyController,
                                  placeholder: 'Кол-во',
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: CupertinoTextField(
                                  controller: r.unitController,
                                  placeholder: 'ед.',
                                  onChanged: (_) => setState(() {}),
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
                                  placeholder: 'Цена за ед.',
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                          if (i < _resources.length - 1) const SizedBox(height: 8),
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