import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/inventory_composition.dart';
import '../../data/models/inventory_item.dart';
import '../../state/masters_store.dart';
import '../../core/money_format.dart';

/// Редактор состава себестоимости (BOM) товара склада:
/// компоненты из других позиций склада + ручной труд. В стиле
/// cost_calculator_screen: строки с qty и ценой, итог и сохранение.
class InventoryCompositionScreen extends StatefulWidget {
  const InventoryCompositionScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<InventoryCompositionScreen> createState() =>
      _InventoryCompositionScreenState();
}

class _CompositionRow {
  _CompositionRow(this.base)
    : componentId = base.componentId,
      noteController = TextEditingController(text: base.note ?? ''),
      qtyController = TextEditingController(text: _fmtQty(base.qty)),
      priceController = TextEditingController(
        text: (base.priceCents / 100).toStringAsFixed(2),
      );

  final InventoryCompositionLine base;
  String? componentId;
  final TextEditingController noteController;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  static String _fmtQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toString();

  bool get isLabor => base.isLabor;

  double get qty =>
      double.tryParse(qtyController.text.trim().replaceAll(',', '.')) ?? 0;

  int get priceCents =>
      ((double.tryParse(priceController.text.trim().replaceAll(',', '.')) ??
                  0) *
              100)
          .round();

  int get totalCents => (qty * priceCents).round();

  /// Подставить выбранного товара со склада: его текущая цена (себестоимость).
  void applyStockItem(InventoryItem item) {
    componentId = item.id;
    priceController.text = (item.costCents / 100).toStringAsFixed(2);
  }

  InventoryCompositionLine buildLine(String itemId) {
    final note = noteController.text.trim();
    return InventoryCompositionLine(
      id: base.id,
      itemId: itemId,
      componentId: isLabor ? null : componentId,
      isLabor: isLabor,
      qty: qty,
      priceCents: priceCents,
      note: isLabor ? (note.isEmpty ? null : note) : base.note,
    );
  }

  void dispose() {
    noteController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _InventoryCompositionScreenState
    extends State<InventoryCompositionScreen> {
  final List<_CompositionRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final store = Provider.of<MastersStore>(context, listen: false);
    for (final line in store.itemComposition(widget.itemId)) {
      _rows.add(_CompositionRow(line));
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  InventoryItem? _findItem(String id) {
    final items = Provider.of<MastersStore>(
      context,
      listen: false,
    ).inventoryItems;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  int get _totalCents => _rows.fold(0, (sum, row) => sum + row.totalCents);

  String _money(int cents) => money(cents);

  /// Пикер компонентов со склада (кроме самого товара). Если [rowIndex]
  /// задан — заменяет компонент в этой строке и подтягивает его цену.
  Future<void> _pickComponent({int? rowIndex}) async {
    final store = Provider.of<MastersStore>(context, listen: false);
    final candidates = store.inventoryItems
        .where((i) => !i.archived && i.id != widget.itemId)
        .toList();
    if (candidates.isEmpty) {
      await showAppAlert(
        context,
        title: 'Нет товаров на складе',
        message:
            'Добавьте позиции на складе, чтобы использовать их как компоненты.',
      );
      return;
    }
    final selected = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        color: context.colors.card,
        child: ListView(
          children: [
            for (final item in candidates)
              CupertinoButton(
                onPressed: () => Navigator.of(ctx).pop(item.id),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${item.name} (${item.unit})'),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final item = _findItem(selected);
    if (item == null) return;
    setState(() {
      if (rowIndex == null) {
        _rows.add(
          _CompositionRow(
            InventoryCompositionLine(
              id: newId(),
              itemId: widget.itemId,
              componentId: item.id,
              isLabor: false,
              qty: 1,
              priceCents: item.costCents,
            ),
          ),
        );
      } else {
        _rows[rowIndex].applyStockItem(item);
      }
    });
  }

  void _addLabor() {
    setState(() {
      _rows.add(
        _CompositionRow(
          InventoryCompositionLine(
            id: newId(),
            itemId: widget.itemId,
            isLabor: true,
            qty: 1,
            priceCents: 0,
          ),
        ),
      );
    });
  }

  void _removeRow(int index) {
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    final store = Provider.of<MastersStore>(context, listen: false);
    final lines = _rows.map((row) => row.buildLine(widget.itemId)).toList();
    setState(() => _saving = true);
    try {
      final total = await store.saveItemComposition(widget.itemId, lines);
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Состав сохранён',
        message: 'Себестоимость товара обновлена: ${_money(total)}.',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteComposition() async {
    final ok = await showAppConfirm(
      context,
      title: 'Удалить состав?',
      message: 'Состав стоимости будет удалён, себестоимость станет 0 ${moneySymbol}.',
      destructive: true,
      confirmLabel: 'Удалить',
    );
    if (!ok || !mounted) return;
    final store = Provider.of<MastersStore>(context, listen: false);
    setState(() => _saving = true);
    try {
      await store.saveItemComposition(widget.itemId, const []);
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Готово',
        message: 'Состав удалён, себестоимость обновлена: 0 ${moneySymbol}.',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _componentLabel(_CompositionRow row) {
    final id = row.componentId;
    if (id == null) return 'Компонент (не выбран)';
    final item = _findItem(id);
    if (item == null) return 'Товар удалён';
    return '${item.name} (${item.unit})';
  }

  Widget _componentRow(_CompositionRow row, int index) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickComponent(rowIndex: index),
                child: Text(
                  _componentLabel(row),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: colors.tertiaryLabel,
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _removeRow(index),
              child: Icon(
                CupertinoIcons.xmark,
                size: 16,
                color: colors.tertiaryLabel,
                semanticLabel: 'Удалить',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _qtyPriceRow(row),
      ],
    );
  }

  Widget _laborRow(_CompositionRow row, int index) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ручной труд',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoTextField(
                controller: row.noteController,
                placeholder: 'Описание (напр., работа мастера)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _removeRow(index),
              child: Icon(
                CupertinoIcons.xmark,
                size: 16,
                color: colors.tertiaryLabel,
                semanticLabel: 'Удалить',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _qtyPriceRow(row),
      ],
    );
  }

  /// Строка qty + цена с иконками ± у валюты (по аналогии с
  /// cost_calculator_screen).
  Widget _qtyPriceRow(_CompositionRow row) {
    final colors = context.colors;
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: CupertinoTextField(
            controller: row.qtyController,
            placeholder: 'Кол-во',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CupertinoTextField(
            controller: row.priceController,
            placeholder: 'Цена',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(moneySymbol),
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
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Icon(CupertinoIcons.minus, size: 16, color: colors.tertiaryLabel),
        const SizedBox(width: 6),
        Text(
          _money(row.totalCents),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = _findItem(widget.itemId);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Расчёт себестоимости'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: Text(
            'Сохранить',
            style: TextStyle(
              color: _saving ? colors.tertiaryLabel : colors.accent,
            ),
          ),
        ),
      ),
      child: item == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Товар не найден. Вернитесь и выберите позицию.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.secondaryLabel),
                ),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Текущая себестоимость: ${_money(item.costCents)}',
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: SectionLabel('Состав')),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _pickComponent(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.cube_box,
                              size: 15,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Со склада',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      children: [
                        if (_rows.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Позиций пока нет. Добавьте компонент со склада или ручной труд.',
                              style: TextStyle(color: colors.tertiaryLabel),
                            ),
                          ),
                        for (var i = 0; i < _rows.length; i++) ...[
                          if (i > 0) const Hairline(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: _rows[i].isLabor
                                ? _laborRow(_rows[i], i)
                                : _componentRow(_rows[i], i),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: '+ Ручной труд',
                    icon: CupertinoIcons.hand_raised,
                    onPressed: _addLabor,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Итого себестоимость',
                        style: TextStyle(color: colors.secondaryLabel),
                      ),
                      Text(
                        _money(_totalCents),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'Сохранить состав',
                    icon: CupertinoIcons.checkmark,
                    enabled: !_saving,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _saving ? null : _deleteComposition,
                    child: Text(
                      'Удалить состав',
                      style: TextStyle(color: colors.red, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
