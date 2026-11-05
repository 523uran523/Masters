import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/units.dart';
import '../../data/models/inventory_item.dart';
import '../../state/masters_store.dart';
import 'calculator_core.dart';
import '../../core/money_format.dart';

class CostCalculatorScreen extends StatefulWidget {
  const CostCalculatorScreen({
    super.key,
    this.initialMaterialsCents = 0,
    this.jobId,
    this.inventoryItemId,
  });

  final int initialMaterialsCents;

  /// Если задан — состояние калькулятора сохраняется/восстанавливается
  /// в jobs.calculator_state через MastersStore.
  final String? jobId;

  /// Если задан — калькулятор открыт для позиции склада: результат
  /// записывается в её себестоимость (и цену продажи).
  final String? inventoryItemId;

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
    this.writeOff = false,
  }) : nameController = TextEditingController(text: name),
       qtyController = TextEditingController(text: qty),
       priceController = TextEditingController(text: price);

  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  String qtyUnit;
  String priceUnit;
  final String? inventoryItemId;

  /// Списывать ли эту строку со склада при применении.
  bool writeOff;

  double get qty => _parse(qtyController.text);

  int get priceCents => (_parse(priceController.text) * 100).round();

  int get totalCents => resourceLineTotalCents(
    qty: qty,
    qtyUnit: qtyUnit,
    priceCents: priceCents,
    priceUnit: priceUnit,
  );

  /// Количество в единице склада (если единицы совместимы).
  double? qtyInStockUnit(InventoryItem item) =>
      convertQty(qty, qtyUnit, item.unit);

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }

  static double _parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}

/// Результат выбора в листе позиций склада.
class _PickedStock {
  const _PickedStock(this.item);
  final InventoryItem item;
}

const String _kCustomRow = '__custom__';

class _CostCalculatorScreenState extends State<CostCalculatorScreen> {
  final List<_ResourceLine> _resources = [];
  final _laborHoursController = TextEditingController(text: '0');
  final _laborRateController = TextEditingController(text: '0');
  final _overheadController = TextEditingController(text: '0');
  final _otherController = TextEditingController(text: '0');
  final _marginController = TextEditingController(text: '30');
  bool _busy = false;

  InventoryItem? get _stockTarget {
    final id = widget.inventoryItemId;
    if (id == null) return null;
    for (final item in context.read<MastersStore>().inventoryItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool get _isStockMode => widget.inventoryItemId != null;

  @override
  void initState() {
    super.initState();
    if (_isStockMode) {
      _seedFromStockItem();
    } else if (widget.initialMaterialsCents > 0) {
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

  /// Режим склада: подставить состав позиции (BOM), если он есть,
  /// иначе одну строку с её себестоимостью.
  void _seedFromStockItem() {
    final item = _stockTarget;
    if (item == null) return;
    final store = context.read<MastersStore>();
    final composition = store.itemComposition(item.id);
    if (composition.isEmpty) {
      if (item.costCents > 0) {
        _resources.add(
          _ResourceLine(
            name: item.name,
            qty: '1',
            qtyUnit: item.unit,
            price: (item.costCents / 100).toStringAsFixed(2),
            priceUnit: defaultPriceUnit(item.unit),
            inventoryItemId: item.id,
          ),
        );
      }
      return;
    }
    for (final line in composition) {
      if (line.isLabor || line.componentId == null) {
        _resources.add(
          _ResourceLine(
            name: line.note?.trim().isNotEmpty == true
                ? line.note!.trim()
                : 'Ручной труд',
            qty: formatQty(line.qty),
            qtyUnit: 'шт',
            price: (line.priceCents / 100).toStringAsFixed(2),
            priceUnit: 'за шт',
          ),
        );
        continue;
      }
      InventoryItem? component;
      for (final candidate in store.inventoryItems) {
        if (candidate.id == line.componentId) {
          component = candidate;
          break;
        }
      }
      _resources.add(
        _ResourceLine(
          name: component?.name ?? 'Компонент удалён',
          qty: formatQty(line.qty),
          qtyUnit: component?.unit ?? 'шт',
          price: (line.priceCents / 100).toStringAsFixed(2),
          priceUnit: defaultPriceUnit(component?.unit ?? 'шт'),
          inventoryItemId: component?.id,
          writeOff: component?.trackStock ?? false,
        ),
      );
    }
  }

  Future<void> _restoreIfNeeded() async {
    final jobId = widget.jobId;
    if (jobId == null || !mounted) return;
    final store = Provider.of<MastersStore>(context, listen: false);
    final json = await store.calculatorStateForJob(jobId);
    if (!mounted || json == null) return;
    final data = _decodeState(json);
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
    final rawResources = data['resources'];
    if (rawResources is List) {
      for (final entry in rawResources) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final qtyUnit = (map['qtyUnit'] is String && (map['qtyUnit'] as String).isNotEmpty)
            ? map['qtyUnit'] as String
            : 'шт';
        final allowed = priceUnitsFor(qtyUnit);
        final priceUnit =
            (map['priceUnit'] is String && allowed.contains(map['priceUnit']))
            ? map['priceUnit'] as String
            : defaultPriceUnit(qtyUnit);
        _resources.add(
          _ResourceLine(
            name: (map['name'] as String?) ?? '',
            qty: (map['qty'] as String?) ?? '1',
            qtyUnit: qtyUnit,
            price: (map['price'] as String?) ?? '0',
            priceUnit: priceUnit,
            inventoryItemId: map['inventoryItemId'] as String?,
            writeOff: map['writeOff'] == true,
          ),
        );
      }
    }
    final labor = data['labor'] is Map
        ? (data['labor'] as Map).cast<String, dynamic>()
        : null;
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
    final jobId = widget.jobId;
    if (jobId != null) {
      unawaited(
        Provider.of<MastersStore>(
          context,
          listen: false,
        ).flushCalculatorState(jobId),
      );
    }
    super.dispose();
  }

  double _d(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  int get _materialsCents => _resources.fold(0, (sum, r) => sum + r.totalCents);

  CalculatorTotals get _totals => computeCalculatorTotals(
    materialsCents: _materialsCents,
    laborHours: _d(_laborHoursController.text),
    laborRateCents: (_d(_laborRateController.text) * 100).round(),
    otherCents: (_d(_otherController.text) * 100).round(),
    overheadPercent: _d(_overheadController.text),
    marginPercent: _d(_marginController.text),
  );

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
        if (r.writeOff) 'writeOff': true,
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

  String _money(int cents) => money(cents);

  void _addResource() {
    setState(
      () => _resources.add(_ResourceLine(qtyUnit: 'шт', priceUnit: 'за шт')),
    );
    _markDirty();
  }

  void _removeResource(int index) {
    final line = _resources.removeAt(index);
    line.dispose();
    _markDirty();
  }

  Future<void> _pickOption({
    required String title,
    required List<String> items,
    required String current,
    required ValueChanged<String> onChanged,
  }) async {
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final item in items)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(item),
              child: Text(
                item,
                style: TextStyle(
                  fontWeight: item == current
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (result != null && result != current) {
      onChanged(result);
    }
  }

  Future<void> _pickQtyUnit(_ResourceLine line) async {
    final extra = line.qtyUnit.isNotEmpty && !kQtyUnits.contains(line.qtyUnit)
        ? [line.qtyUnit]
        : const <String>[];
    await _pickOption(
      title: 'Единица количества',
      items: [...kQtyUnits, ...extra],
      current: line.qtyUnit,
      onChanged: (value) {
        setState(() {
          line.qtyUnit = value;
          final allowed = priceUnitsFor(value);
          if (!allowed.contains(line.priceUnit)) {
            line.priceUnit = defaultPriceUnit(value);
          }
        });
        _markDirty();
      },
    );
  }

  Future<void> _pickPriceUnit(_ResourceLine line) async {
    final allowed = priceUnitsFor(line.qtyUnit);
    await _pickOption(
      title: 'Цена за',
      items: allowed,
      current: line.priceUnit,
      onChanged: (value) {
        setState(() => line.priceUnit = value);
        _markDirty();
      },
    );
  }

  /// Лист выбора позиции склада с поиском и вариантом «Своя строка».
  Future<void> _openStockPicker() async {
    final store = context.read<MastersStore>();
    final items = store.inventoryItems.where((i) => !i.archived).toList();
    if (items.isEmpty) {
      await showAppAlert(
        context,
        title: 'Склад пуст',
        message:
            'Добавьте позиции на складе или создайте свою строку расчёта.',
      );
      _addResource();
      return;
    }
    final result = await showCupertinoModalPopup<Object>(
      context: context,
      builder: (sheetContext) => _StockPickerSheet(items: items),
    );
    if (result == null || !mounted) return;
    if (result is _PickedStock) {
      _applyInventoryItem(result.item);
    } else if (result == _kCustomRow) {
      _addResource();
    }
  }

  void _applyInventoryItem(InventoryItem item) {
    final existing = _resources.indexWhere(
      (r) => r.inventoryItemId == item.id,
    );
    if (existing >= 0) {
      final line = _resources[existing];
      final current = line.qty;
      line.qtyController.text = formatQty(current <= 0 ? 1 : current + 1);
      _markDirty();
      return;
    }
    final empty = _resources.indexWhere(
      (r) => r.nameController.text.trim().isEmpty && r.inventoryItemId == null,
    );
    final price = item.costCents > 0 ? item.costCents : item.sellPriceCents;
    final line = _ResourceLine(
      name: item.name,
      qty: '1',
      qtyUnit: item.unit,
      price: (price / 100).toStringAsFixed(2),
      priceUnit: defaultPriceUnit(item.unit),
      inventoryItemId: item.id,
      writeOff: item.trackStock,
    );
    if (empty >= 0) {
      _resources[empty].dispose();
      _resources[empty] = line;
    } else {
      _resources.add(line);
    }
    _markDirty();
  }

  /// «На склад»: создать позицию или обновить себестоимость существующей.
  Future<void> _saveToStock(_ResourceLine line) async {
    final name = line.nameController.text.trim();
    if (name.isEmpty) {
      await showAppAlert(context, title: 'Нет названия', message: 'Введите наименование строки.');
      return;
    }
    final store = context.read<MastersStore>();
    final total = line.totalCents;
    final existing = _lineItem(store, line);
    setState(() => _busy = true);
    try {
      if (existing != null) {
        final stockQty = convertQty(line.qty, line.qtyUnit, existing.unit);
        await store.updateInventoryItem(
          existing.copyWith(
            name: name,
            costCents: line.priceCents,
            stockQty: stockQty == null
                ? existing.stockQty
                : existing.stockQty + stockQty,
          ),
        );
      } else {
        final duplicate = store.inventoryItems.where(
          (i) => i.name.trim().toLowerCase() == name.toLowerCase(),
        );
        if (duplicate.isNotEmpty) {
          final item = duplicate.first;
          await store.updateInventoryItem(
            item.copyWith(
              unit: line.qtyUnit,
              costCents: line.priceCents,
              sellPriceCents: line.priceCents,
            ),
          );
        } else {
          await store.createInventoryItem(
            name: name,
            unit: line.qtyUnit,
            sellPriceCents: line.priceCents,
            costCents: line.priceCents,
            trackStock: false,
          );
        }
      }
      HapticFeedback.lightImpact();
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Сохранено на склад',
        message: total > 0
            ? '$name — себестоимость ${_money(line.priceCents)}.'
            : '$name — позиция создана.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Списать количество строки со склада.
  Future<void> _writeOffLine(_ResourceLine line) async {
    final store = context.read<MastersStore>();
    final item = _lineItem(store, line);
    if (item == null) return;
    final qty = line.qtyInStockUnit(item);
    if (qty == null || qty <= 0) {
      await showAppAlert(
        context,
        title: 'Единицы не совпадают',
        message:
            'Количество указано в «${line.qtyUnit}», а склад ведётся в «${item.unit}».',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await store.writeOffStock(
        itemId: item.id,
        qty: qty,
        note: widget.jobId == null ? 'Калькулятор' : 'Материалы заказа',
      );
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Пополнить склад на количество строки по указанной цене.
  Future<void> _receiveLine(_ResourceLine line) async {
    final store = context.read<MastersStore>();
    final item = _lineItem(store, line);
    if (item == null) return;
    final qty = line.qtyInStockUnit(item);
    if (qty == null || qty <= 0) {
      await showAppAlert(
        context,
        title: 'Единицы не совпадают',
        message:
            'Количество указано в «${line.qtyUnit}», а склад ведётся в «${item.unit}».',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await store.receiveStock(
        itemId: item.id,
        qty: qty,
        unitPriceCents: line.priceCents,
        note: 'Поступление из калькулятора',
      );
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InventoryItem? _lineItem(MastersStore store, _ResourceLine line) {
    final id = line.inventoryItemId;
    if (id == null) return null;
    for (final item in store.inventoryItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _showLineActions(_ResourceLine line) async {
    final store = context.read<MastersStore>();
    final item = _lineItem(store, line);
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(
          line.nameController.text.trim().isEmpty
              ? 'Строка расчёта'
              : line.nameController.text.trim(),
        ),
        message: item == null
            ? const Text('Строка не связана с позицией склада')
            : Text('Остаток: ${formatQty(item.stockQty)} ${item.unit}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop('save'),
            child: const Text('Сохранить на склад'),
          ),
          if (item != null) ...[
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop('writeoff'),
              child: const Text('Списать со склада'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop('receive'),
              child: const Text('Пополнить склад'),
            ),
          ],
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop('delete'),
            child: const Text('Удалить строку'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'save':
        await _saveToStock(line);
      case 'writeoff':
        await _writeOffLine(line);
      case 'receive':
        await _receiveLine(line);
      case 'delete':
        final index = _resources.indexOf(line);
        if (index >= 0) _removeResource(index);
    }
  }

  Future<void> _apply() async {
    final totals = _totals;
    final store = context.read<MastersStore>();
    final stockTarget = _stockTarget;
    if (stockTarget != null) {
      setState(() => _busy = true);
      try {
        await store.updateInventoryItem(
          stockTarget.copyWith(
            costCents: totals.costCents,
            sellPriceCents: totals.priceCents > 0
                ? totals.priceCents
                : stockTarget.sellPriceCents,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop({
          'costCents': totals.costCents,
          'priceCents': totals.priceCents,
        });
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final toWriteOff = _resources
        .where((r) => r.writeOff && r.inventoryItemId != null)
        .toList();
    if (toWriteOff.isNotEmpty) {
      setState(() => _busy = true);
      try {
        for (final line in toWriteOff) {
          final item = _lineItem(store, line);
          if (item == null) continue;
          final qty = line.qtyInStockUnit(item);
          if (qty == null || qty <= 0) continue;
          await store.writeOffStock(
            itemId: item.id,
            qty: qty,
            note: 'Материалы заказа',
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop({
      'costCents': totals.costCents,
      'priceCents': totals.priceCents,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final store = context.watch<MastersStore>();
    final totals = _totals;
    final title = _isStockMode ? 'Себестоимость' : 'Калькулятор';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _busy ? null : _apply,
          child: Text(_isStockMode ? 'Сохранить' : 'Применить'),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _SummaryCard(totals: totals),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SectionLabel('Ресурсы и материалы')),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _openStockPicker,
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
                if (_resources.isEmpty)
                  AppCard(
                    child: Column(
                      children: [
                        Text(
                          'Добавьте материалы со склада или свою строку.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.secondaryLabel,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SecondaryButton(
                          label: 'Добавить строку',
                          icon: CupertinoIcons.add,
                          onPressed: _addResource,
                        ),
                      ],
                    ),
                  )
                else
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < _resources.length; i++) ...[
                          _buildResourceRow(store, _resources[i], i),
                          if (i != _resources.length - 1) const Hairline(),
                        ],
                        const SizedBox(height: 12),
                        SecondaryButton(
                          label: 'Добавить строку',
                          icon: CupertinoIcons.add,
                          onPressed: _addResource,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const SectionLabel('Работа'),
                AppCard(
                  child: Column(
                    children: [
                      _NumberRow(
                        label: 'Часы',
                        controller: _laborHoursController,
                        suffix: 'ч',
                        onChanged: _markDirty,
                      ),
                      const SizedBox(height: 10),
                      _NumberRow(
                        label: 'Ставка',
                        controller: _laborRateController,
                        prefix: '${moneySymbol}',
                        suffix: '/ч',
                        onChanged: _markDirty,
                      ),
                      const SizedBox(height: 12),
                      _AmountRow(
                        label: 'Затраты на работу',
                        value: _money(totals.laborCents),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionLabel('Накладные и маржа'),
                AppCard(
                  child: Column(
                    children: [
                      _NumberRow(
                        label: 'Прочие расходы',
                        controller: _otherController,
                        prefix: '${moneySymbol}',
                        onChanged: _markDirty,
                      ),
                      const SizedBox(height: 10),
                      _NumberRow(
                        label: 'Накладные',
                        controller: _overheadController,
                        suffix: '%',
                        onChanged: _markDirty,
                      ),
                      const SizedBox(height: 10),
                      _NumberRow(
                        label: 'Маржа',
                        controller: _marginController,
                        suffix: '%',
                        onChanged: _markDirty,
                      ),
                      const SizedBox(height: 14),
                      _AmountRow(
                        label: 'Себестоимость',
                        value: _money(totals.costCents),
                      ),
                      const SizedBox(height: 6),
                      _AmountRow(
                        label: 'Цена',
                        value: _money(totals.priceCents),
                        strong: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isStockMode
                      ? 'Сохранение запишет себестоимость и цену в позицию склада.'
                      : 'Материалы со включённой отметкой спишутся со склада при применении.',
                  style: TextStyle(color: colors.tertiaryLabel, fontSize: 12),
                ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceRow(MastersStore store, _ResourceLine line, int index) {
    final colors = context.colors;
    final item = _lineItem(store, line);
    final remainder = item == null
        ? null
        : 'Остаток: ${formatQty(item.stockQty)} ${item.unit}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: line.nameController,
                  placeholder: 'Наименование',
                  onChanged: (_) => _markDirty(),
                ),
              ),
              const SizedBox(width: 6),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showLineActions(line),
                child: Icon(
                  CupertinoIcons.ellipsis_circle,
                  size: 22,
                  color: colors.secondaryLabel,
                  semanticLabel: 'Действия со строкой',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CupertinoTextField(
                  controller: line.qtyController,
                  placeholder: 'Кол-во',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _markDirty(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: CupertinoTextField(
                  controller: line.priceController,
                  placeholder: 'Цена',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('${moneySymbol}', style: TextStyle(color: colors.secondaryLabel)),
                  ),
                  onChanged: (_) => _markDirty(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _unitChip(
                text: line.qtyUnit,
                onTap: () => _pickQtyUnit(line),
              ),
              const SizedBox(width: 6),
              _unitChip(
                text: line.priceUnit,
                onTap: () => _pickPriceUnit(line),
              ),
              const Spacer(),
              Text(
                _money(line.totalCents),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (remainder != null || item != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (remainder != null)
                  Text(
                    remainder,
                    style: TextStyle(
                      color: item != null && item.lowStock
                          ? colors.orange
                          : colors.tertiaryLabel,
                      fontSize: 12,
                    ),
                  ),
                const Spacer(),
                if (item != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => line.writeOff = !line.writeOff);
                      _markDirty();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          line.writeOff
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          size: 16,
                          color: line.writeOff
                              ? colors.accent
                              : colors.tertiaryLabel,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Списать',
                          style: TextStyle(
                            fontSize: 12,
                            color: line.writeOff
                                ? colors.accent
                                : colors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (item == null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _removeResource(index),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 16,
                      color: colors.tertiaryLabel,
                      semanticLabel: 'Удалить',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _unitChip({required String text, required VoidCallback onTap}) {
    final colors = context.colors;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(width: 3),
            Icon(
              CupertinoIcons.chevron_down,
              size: 11,
              color: colors.secondaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals});

  final CalculatorTotals totals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    String money(int cents) => '${money(cents)}';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              label: 'Себестоимость',
              value: money(totals.costCents),
              color: colors.label,
            ),
          ),
          Container(width: 0.5, height: 34, color: colors.separator),
          Expanded(
            child: _SummaryValue(
              label: 'Цена',
              value: money(totals.priceCents),
              color: colors.accent,
            ),
          ),
          Container(width: 0.5, height: 34, color: colors.separator),
          Expanded(
            child: _SummaryValue(
              label: 'Маржа',
              value: money(totals.marginCents),
              color: totals.marginCents >= 0 ? colors.green : colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.colors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colors.secondaryLabel, fontSize: 15),
          ),
        ),
        SizedBox(
          width: 132,
          child: CupertinoTextField(
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      prefix!,
                      style: TextStyle(color: colors.secondaryLabel),
                    ),
                  ),
            suffix: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      suffix!,
                      style: TextStyle(color: colors.secondaryLabel),
                    ),
                  ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: strong ? 17 : 14,
            color: strong ? colors.accent : colors.label,
          ),
        ),
      ],
    );
  }
}

/// Лист выбора позиции склада: поиск по названию, остаток и цена.
class _StockPickerSheet extends StatefulWidget {
  const _StockPickerSheet({required this.items});

  final List<InventoryItem> items;

  @override
  State<_StockPickerSheet> createState() => _StockPickerSheetState();
}

class _StockPickerSheetState extends State<_StockPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.category.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _filtered;
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Позиции склада',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Поиск по названию',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Ничего не найдено',
                        style: TextStyle(color: colors.secondaryLabel),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Hairline(),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final price = item.costCents > 0
                            ? item.costCents
                            : item.sellPriceCents;
                        return CupertinoListTile(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          title: Text(item.name),
                          subtitle: Text(
                            item.trackStock
                                ? 'Остаток: ${formatQty(item.stockQty)} ${item.unit}'
                                : 'Без учёта остатка',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.lowStock
                                  ? colors.orange
                                  : colors.secondaryLabel,
                            ),
                          ),
                          trailing: Text(
                            '${money(price)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(_PickedStock(item)),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SecondaryButton(
                label: 'Своя строка',
                icon: CupertinoIcons.add,
                onPressed: () => Navigator.of(context).pop(_kCustomRow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
