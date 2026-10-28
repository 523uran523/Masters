import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../data/models/inventory_item.dart';
import '../../state/masters_store.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _busy = false;

  Future<String?> _prompt(String title, String placeholder, {String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    return showCupertinoDialog<String?>(
      context: context,
      builder: (dc) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: controller, placeholder: placeholder, autofocus: true),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.of(dc).pop(), child: const Text('Отмена')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.of(dc).pop(controller.text.trim()), child: const Text('ОК')),
        ],
      ),
    );
  }

  Future<void> _newItem() async {
    final name = await _prompt('Название позиции', 'Масло моторное 5W-30');
    if (name == null || name.trim().isEmpty) return;
    final kind = await _pickKind();
    if (kind == null) return;
    final unit = await _prompt('Единица', 'шт') ?? 'шт';
    final sellStr = await _prompt('Цена продажи (₽)', '0') ?? '0';
    final costStr = await _prompt('Себестоимость (₽)', '0') ?? '0';
    final minStr = await _prompt('Мин. остаток', '0') ?? '0';
    if (!mounted) return;
    final track = await showAppConfirm(context, title: 'Учитывать остаток?', message: 'Для услуг можно отключить учёт склада.', confirmLabel: 'Учитывать');
    final sell = ((double.tryParse(sellStr.replaceAll(',', '.')) ?? 0) * 100).round();
    final cost = ((double.tryParse(costStr.replaceAll(',', '.')) ?? 0) * 100).round();
    final minQty = double.tryParse(minStr.replaceAll(',', '.')) ?? 0;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().createInventoryItem(
        name: name.trim(),
        kind: kind,
        unit: unit,
        sellPriceCents: sell,
        costCents: cost,
        trackStock: track,
        minQty: minQty,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickKind() async {
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 200,
        color: context.colors.card,
        child: Column(
          children: [
            CupertinoButton(child: const Text('Товар'), onPressed: () => Navigator.of(ctx).pop('good')),
            CupertinoButton(child: const Text('Услуга'), onPressed: () => Navigator.of(ctx).pop('service')),
          ],
        ),
      ),
    );
  }

  Future<void> _receiveStock(InventoryItem item) async {
    final qtyStr = await _prompt('Поступление, кол-во (${item.unit})', '1');
    final qty = double.tryParse((qtyStr ?? '').replaceAll(',', '.'));
    if (qty == null || qty <= 0) return;
    final costStr = await _prompt('Цена за ед. (₽)', (item.costCents / 100).toStringAsFixed(0)) ?? '0';
    final _ = costStr;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().receiveStock(itemId: item.id, qty: qty, note: 'Закупка');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _writeOff(InventoryItem item) async {
    final qtyStr = await _prompt('Списание, кол-во (${item.unit})', '1');
    final qty = double.tryParse((qtyStr ?? '').replaceAll(',', '.'));
    if (qty == null || qty <= 0) return;
    final reason = await _prompt('Причина', 'Брак/списание') ?? 'Списание';
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().writeOffStock(itemId: item.id, qty: qty, note: reason);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(InventoryItem item) async {
    final ok = await showAppConfirm(context, title: 'Удалить позицию?', message: item.name, destructive: true, confirmLabel: 'Удалить');
    if (!ok) return;
    if (!mounted) return;
    await context.read<MastersStore>().deleteInventoryItem(item.id);
  }

  Future<void> _editItem(InventoryItem item) async {
    final name = await _prompt('Название', item.name, initial: item.name);
    if (name == null || name.trim().isEmpty) return;
    final unit = await _prompt('Ед. измерения', item.unit, initial: item.unit) ?? item.unit;
    final sellStr = await _prompt('Цена продажи (₽)', (item.sellPriceCents / 100).toStringAsFixed(0), initial: (item.sellPriceCents / 100).toStringAsFixed(0)) ?? (item.sellPriceCents / 100).toString();
    final costStr = await _prompt('Себестоимость (₽)', (item.costCents / 100).toStringAsFixed(0), initial: (item.costCents / 100).toStringAsFixed(0)) ?? '0';
    final minStr = await _prompt('Мин. остаток', item.minQty.toString(), initial: item.minQty.toString()) ?? '0';
    if (!mounted) return;
    final sell = ((double.tryParse(sellStr.replaceAll(',', '.')) ?? 0) * 100).round();
    final cost = ((double.tryParse(costStr.replaceAll(',', '.')) ?? 0) * 100).round();
    final minQty = double.tryParse(minStr.replaceAll(',', '.')) ?? 0;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().updateInventoryItem(item.copyWith(
        name: name.trim(),
        unit: unit.trim(),
        sellPriceCents: sell,
        costCents: cost,
        minQty: minQty,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final low = store.lowStockItems();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Склад'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(padding: EdgeInsets.zero, onPressed: _newItem, child: const Icon(CupertinoIcons.plus)),
          ],
        ),
      ),
      child: _busy
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (low.isNotEmpty) ...[
                    SectionLabel('Низкий остаток (${low.length})'),
                    AppCard(
                      child: Column(
                        children: low.map((i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                              Text('${i.stockQty.toStringAsFixed(i.stockQty % 1 == 0 ? 0 : 2)} ${i.unit} (мин ${i.minQty})',
                                  style: TextStyle(color: colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SectionLabel('Позиции (${store.inventoryItems.length})'),
                  store.inventoryItems.isEmpty
                      ? EmptyState(
                          title: 'Нет позиций',
                          message: 'Добавьте товар или услугу.',
                          art: Icon(CupertinoIcons.cube, size: 48, color: colors.tertiaryLabel),
                          actions: [
                            PrimaryButton(label: 'Добавить позицию', icon: CupertinoIcons.plus, onPressed: _newItem),
                          ],
                        )
                      : Column(
                          children: store.inventoryItems.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                onTap: () => _editItem(item),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text(
                                            '${item.kind == 'service' ? 'Услуга' : 'Товар'} • ${item.unit} • продажа ${(item.sellPriceCents / 100).toStringAsFixed(0)} ₽',
                                            style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
                                          ),
                                          if (item.trackStock)
                                            Text('Остаток: ${item.stockQty.toStringAsFixed(item.stockQty % 1 == 0 ? 0 : 2)} ${item.unit}${item.lowStock ? ' (мало)' : ''}',
                                                style: TextStyle(color: item.lowStock ? colors.red : colors.secondaryLabel, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (item.trackStock) ...[
                                      CupertinoButton(padding: EdgeInsets.zero, onPressed: () => _receiveStock(item), child: const Icon(CupertinoIcons.plus_circle, size: 20)),
                                      CupertinoButton(padding: EdgeInsets.zero, onPressed: () => _writeOff(item), child: const Icon(CupertinoIcons.minus_circle, size: 20)),
                                    ],
                                    CupertinoButton(padding: EdgeInsets.zero, onPressed: () => _delete(item), child: Icon(CupertinoIcons.xmark, size: 16, color: colors.tertiaryLabel)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }
}