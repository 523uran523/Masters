import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../data/models/inventory_item.dart';
import '../../state/masters_store.dart';

/// Единицы количества (по ТЗ calculator-v2).
const List<String> kQtyUnits = ['шт', 'г', 'кг', 'л', 'см', 'м', 'м²'];

/// Единицы цены ("цена за ...").
const List<String> kPriceUnits = [
  'за шт',
  'за 100 г',
  'за кг',
  'за л',
  'за м',
  'за см',
  'за м²',
];

/// Базовый коэффициент перевода единицы количества в "базовую" (шт/кг/л/м/м²).
const Map<String, double> kQtyBase = {
  'шт': 1.0,
  'г': 0.001,
  'кг': 1.0,
  'л': 1.0,
  'см': 0.01,
  'м': 1.0,
  'м²': 1.0,
};

/// Базовый коэффициент перевода единицы цены в "базовую" (шт/кг/л/м/м²).
const Map<String, double> kPriceBase = {
  'за шт': 1.0,
  'за г': 0.001,
  'за 100 г': 0.1,
  'за кг': 1.0,
  'за л': 1.0,
  'за м': 1.0,
  'за см': 0.01,
  'за м²': 1.0,
};

String _defaultPriceUnit(String qtyUnit) {
  switch (qtyUnit) {
    case 'г':
      return 'за г';
    case 'см':
      return 'за см';
    case 'кг':
      return 'за кг';
    case 'л':
      return 'за л';
    case 'м':
      return 'за м';
    case 'м²':
      return 'за м²';
    default:
      return 'за шт';
  }
}

List<String> _priceUnitsFor(String qtyUnit) {
  if (qtyUnit == 'г') return ['за г'];
  if (qtyUnit == 'см') return ['за см'];
  return kPriceUnits;
}

class CostCalculatorScreen extends StatefulWidget {
  const CostCalculatorScreen({
    super.key,
    this.initialMaterialsCents = 0,
    this.jobId,
  });

  final int initialMaterialsCents;

  /// Если задан — состояние калькулятора сохраняется/восстанавливается
  /// в jobs.calculator_state через MastersStore.
  final String? jobId;

  @override
  State<CostCalculatorScreen> createState() => _CostCalculatorScreenState();
}

class _ResourceLine {
  _ResourceLine({
    String name = '',
    String qty = '1',
    required this.qtyUnit,
    required this.priceUnit,
    String price = '0',
    this.inventoryItemId,
  }) : nameController = TextEditingController(text: name),
       qtyController = TextEditingController(text: qty),
       priceController = TextEditingController(text: price);

  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  String qtyUnit;
  String priceUnit;
  final String? inventoryItemId;

  double get qty =>
      double.tryParse(qtyController.text.trim().replaceAll(',', '.')) ?? 0;

  int get priceCents =>
      ((double.tryParse(priceController.text.trim().replaceAll(',', '.')) ??
                  0) *
              100)
          .round();

  /// Стоимость строки: qty (в своей единице) × цена (за свою единицу),
  /// приведено к общей базовой мере, в центах.
  int get totalCents {
    final qtyBase = kQtyBase[qtyUnit] ?? 1.0;
    final priceBase = kPriceBase[priceUnit] ?? 1.0;
    return (qty * qtyBase / priceBase * priceCents).round();
  }

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
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
      _resources.add(
        _ResourceLine(
          name: 'Материалы',
          qty: '1',
          qtyUnit: 'шт',
          price: (widget.initialMaterialsCents / 100).toStringAsFixed(2),
          priceUnit: 'за шт',
        ),
      );
    }
    _restoreIfNeeded();
  }

  Future<void> _restoreIfNeeded() async {
    final jobId = widget.jobId;
    if (jobId == null || !mounted) return;
    final store = Provider.of<MastersStore>(context, listen: false);
    final json = await store.calculatorStateForJob(jobId);
    if (!mounted) return;
    final data = json == null ? null : _decodeState(json);
    if (data == null) return;
    _applySaved(data);
    setState(() {});
  }

  Map<String, dynamic>? _decodeState(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schema'] != 1) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  void _applySaved(Map<String, dynamic> data) {
    for (final r in _resources) {
      r.dispose();
    }
    _resources.clear();
    for (final e
        in (data['resources'] as List? ?? <dynamic>[])
            .cast<Map<String, dynamic>>()) {
      final qtyUnit =
          (e['qtyUnit'] is String && kQtyUnits.contains(e['qtyUnit']))
          ? e['qtyUnit'] as String
          : 'шт';
      final priceUnit =
          (e['priceUnit'] is String &&
              _priceUnitsFor(qtyUnit).contains(e['priceUnit']))
          ? e['priceUnit'] as String
          : _defaultPriceUnit(qtyUnit);
      _resources.add(
        _ResourceLine(
          name: (e['name'] as String?) ?? '',
          qty: (e['qty'] as String?) ?? '1',
          qtyUnit: qtyUnit,
          price: (e['price'] as String?) ?? '0',
          priceUnit: priceUnit,
          inventoryItemId: (e['inventoryItemId'] as String?),
        ),
      );
    }
    final labor = data['labor'] as Map<String, dynamic>?;
    _laborHoursController.text = (labor?['hours'] as String?) ?? '0';
    _laborRateController.text = (labor?['rate'] as String?) ?? '0';
    _overheadController.text = (data['overhead'] as String?) ?? '0';
    _otherController.text = (data['other'] as String?) ?? '0';
    _marginController.text = (data['margin'] as String?) ?? '30';
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
    if (widget.jobId != null) {
      unawaited(
        Provider.of<MastersStore>(
          context,
          listen: false,
        ).flushCalculatorState(widget.jobId!),
      );
    }
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

  /// Сохранение состояния с дебаунсом в хранилище (при каждом вводе).
  void _markDirty() {
    setState(() {});
    final jobId = widget.jobId;
    if (jobId != null) {
      Provider.of<MastersStore>(
        context,
        listen: false,
      ).saveCalculatorState(jobId, jsonEncode(_snapshot()));
    }
  }

  Map<String, dynamic> _snapshot() => {
    'schema': 1,
    'resources': _resources.map((r) {
      return {
        'name': r.nameController.text,
        'qty': r.qtyController.text,
        'qtyUnit': r.qtyUnit,
        'price': r.priceController.text,
        'priceUnit': r.priceUnit,
        if (r.inventoryItemId != null) 'inventoryItemId': r.inventoryItemId,
      };
    }).toList(),
    'labor': {
      'role': 'work',
      'hours': _laborHoursController.text,
      'rate': _laborRateController.text,
    },
    'overhead': _overheadController.text,
    'other': _otherController.text,
    'margin': _marginController.text,
  };

  void _addResource() {
    setState(
      () => _resources.add(_ResourceLine(qtyUnit: 'шт', priceUnit: 'за шт')),
    );
    _markDirty();
  }

  void _removeResource(int index) {
    final r = _resources.removeAt(index);
    r.dispose();
    setState(() {});
    _markDirty();
  }

  /// Выбор единицы через CupertinoActionSheet (вместо сегментов/кнопок).
  Future<void> _pickUnit({
    required BuildContext context,
    required String current,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) async {
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Единица измерения'),
        actions: [
          for (final item in items)
            CupertinoActionSheetAction(
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: item == current
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: item == current ? null : null,
                ),
              ),
              onPressed: () => Navigator.pop(context, item),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (result != null && result != current) {
      onChanged(result);
    }
  }

  Widget _unitButton({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _pickUnit(
          context: context,
          current: value,
          items: items,
          onChanged: onChanged,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: const TextStyle(fontSize: 14)),
            const Icon(CupertinoIcons.chevron_down, size: 16),
          ],
        ),
      ),
    );
  }

  void _apply() {
    Navigator.of(context)
        .pop({'costCents': _costCents, 'priceCents': _priceCents});
  }

  /// Добавить строку из позиции склада (заполнить поля, не дублировать —
  /// дублирование проверяется при сохранении на склад).
  void _applyInventoryItem(InventoryItem item) {
    final empty = _resources.indexWhere(
      (r) => r.nameController.text.trim().isEmpty && r.inventoryItemId == null,
    );
    final line = _ResourceLine(
      name: item.name,
      qty: '1',
      qtyUnit: item.unit,
      price: (item.sellPriceCents / 100).toStringAsFixed(2),
      priceUnit: _defaultPriceUnit(item.unit),
      inventoryItemId: item.id,
    );
    if (empty >= 0) {
      _resources[empty].dispose();
      _resources[empty] = line;
    } else {
      setState(() => _resources.add(line));
    }
    _markDirty();
  }

  /// "Сохранить на склад": создать InventoryItem с единицей и ценой строки.
  /// Если позиция с таким названием уже есть — не дублировать.
  Future<void> _saveToStock(_ResourceLine r) async {
    final name = r.nameController.text.trim();
    if (name.isEmpty) return;
    final store = Provider.of<MastersStore>(context, listen: false);
    final exists = store.inventoryItems.any(
      (i) => i.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      HapticFeedback.lightImpact();
      return;
    }
    await store.createInventoryItem(
      name: name,
      unit: r.qtyUnit,
      sellPriceCents: r.priceCents,
      stockQty: 0,
      trackStock: false,
    );
    HapticFeedback.lightImpact();
  }

  Widget _buildResourceRow(_ResourceLine r, int i) {
    final colors = context.colors;
    InventoryItem? inventoryItem;
    final itemId = r.inventoryItemId;
    if (itemId != null) {
      inventoryItem = Provider.of<MastersStore>(context, listen: false)
          .inventoryItems
          .firstWhere(
            (it) => it.id == itemId,
            orElse: () => throw StateError('inventory item $itemId missing'),
          );
    }
    final remainder = inventoryItem == null
        ? ''
        : ' оств. ${inventoryItem.stockQty} ${inventoryItem.unit}';

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
                  onChanged: (_) => _markDirty(),
                ),
              ),
              const SizedBox(width: 8),
              SecondaryButton(
                label: 'На склад',
                icon: CupertinoIcons.cube_box,
                onPressed: () => _saveToStock(r),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 95,
                child: CupertinoTextField(
                  controller: r.qtyController,
                  placeholder: 'Кол-во',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _markDirty(),
                ),
              ),
              const SizedBox(width: 8),
              _unitButton(
                value: r.qtyUnit,
                items: kQtyUnits,
                onChanged: (v) => setState(() => r.qtyUnit = v),
                width: 115,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoTextField(
                  controller: r.priceController,
                  placeholder: 'Цена',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('₽'),
                  ),
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      CupertinoIcons.plus,
                      size: 17,
                      color: colors.accent,
                      semanticLabel: 'Цена за единицу',
                    ),
                  ),
                  onChanged: (_) => _markDirty(),
                ),
              ),
              const SizedBox(width: 8),
              _unitButton(
                value: r.priceUnit,
                items: _priceUnitsFor(r.qtyUnit),
                onChanged: (v) => setState(() => r.priceUnit = v),
                width: 110,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 95 + 8 + 115 + 8),
              Icon(CupertinoIcons.minus, size: 16, color: colors.tertiaryLabel),
              const SizedBox(width: 6),
              Text(
                '${(r.totalCents / 100).toStringAsFixed(0)} ₽',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _removeResource(i),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 16,
                  color: colors.tertiaryLabel,
                  semanticLabel: 'Удалить',
                ),
              ),
            ],
          ),
          if (remainder.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const SizedBox(width: 95 + 8 + 115 + 8),
                  Text(
                    'остаток на складе$remainder',
                    style: TextStyle(color: colors.tertiaryLabel, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return SecondaryButton(
      label: '+ Ресурс',
      icon: CupertinoIcons.add,
      onPressed: _addResource,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<MastersStore>(context, listen: false);
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
            Row(
              children: [
                SectionLabel('Ресурсы и материалы'),
                const SizedBox(width: 8),
                if (store.inventoryItems.isNotEmpty)
                  CupertinoButton(
                    onPressed: () => _pickUnit(
                      context: context,
                      current: '',
                      items: store.inventoryItems
                          .map((it) => '${it.name} (${it.unit})')
                          .toList(),
                      onChanged: (selected) {
                        final item = store.inventoryItems.firstWhere(
                          (it) => '${it.name} (${it.unit})' == selected,
                        );
                        _applyInventoryItem(item);
                      },
                    ),
                    padding: EdgeInsets.zero,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.cube_box, size: 16),
                        SizedBox(width: 6),
                        Text('Со склада', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  ..._resources.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value;
                    return _buildResourceRow(r, i);
                  }),
                  const SizedBox(height: 10),
                  _buildAddButton(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Работа'),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Часы',
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _laborHoursController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ставка (₽/ч)',
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _laborRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Затраты на работу',
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(_laborCents / 100).toStringAsFixed(0)} ₽',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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
                      Expanded(
                        child: Text(
                          'Прочие расходы (₽)',
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _otherController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Накладные (% от базы)',
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _overheadController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Маржа (%)',
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _marginController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Себестоимость',
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(_costCents / 100).toStringAsFixed(0)} ₽',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Цена',
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.minus,
                            size: 16,
                            color: colors.tertiaryLabel,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(_priceCents / 100).toStringAsFixed(0)} ₽',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
