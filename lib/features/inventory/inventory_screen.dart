import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../data/models/inventory_item.dart';
import '../../data/models/supplier.dart';
import '../../state/masters_store.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _busy = false;
  final _searchController = TextEditingController();
  String _invQuery = '';
  String _invFilter = 'all';

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

  Future<String?> _pickUnit() async {
    final unit = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Единица измерения'),
        actions: [
          for (final item in ['шт', 'г', 'кг', 'мл', 'л', 'м', 'см', 'упак', 'услуга'])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop(item),
              child: Text(item),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('__custom__'),
            child: const Text('Другая...'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (unit == null) return null;
    if (unit == '__custom__') return _prompt('Единица', 'шт');
    return unit;
  }

  List<InventoryItem> _filteredInventory(MastersStore store) {
    var list = store.inventoryItems.where((i) => !i.archived).toList();
    final q = _invQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((i) => i.name.toLowerCase().contains(q) || i.unit.toLowerCase().contains(q)).toList();
    }
    if (_invFilter == 'good') list = list.where((i) => i.kind == 'good').toList();
    if (_invFilter == 'service') list = list.where((i) => i.kind == 'service').toList();
    if (_invFilter == 'low') list = list.where((i) => i.lowStock).toList();
    return list;
  }

  Future<void> _pickInventoryFilter() async {
    final v = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Фильтр склада'),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.of(dialogContext).pop('all'), child: const Text('Все позиции')),
          CupertinoActionSheetAction(onPressed: () => Navigator.of(dialogContext).pop('good'), child: const Text('Только товары')),
          CupertinoActionSheetAction(onPressed: () => Navigator.of(dialogContext).pop('service'), child: const Text('Только услуги')),
          CupertinoActionSheetAction(onPressed: () => Navigator.of(dialogContext).pop('low'), child: const Text('Мало на складе')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Отмена')),
      ),
    );
    if (v != null) setState(() => _invFilter = v);
  }

  Future<void> _newItem() async {
    final name = await _prompt('Название позиции', 'Масло моторное 5W-30');
    if (name == null || name.trim().isEmpty) return;
    final kind = await _pickKind();
    if (kind == null) return;
    final unit = await _pickUnit() ?? 'шт';
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

  Future<void> _importInventoryExcel() async {
    setState(() => _busy = true);
    try {
      final count = await context.read<MastersStore>().importInventoryFromExcel();
      if (!mounted) return;
      await showAppAlert(
        context,
        title: count > 0 ? 'Импорт завершён' : 'Импорт',
        message: count > 0
            ? 'Добавлено товаров/услуг: $count.'
            : 'Не удалось добавить записи. Нужен столбец name; проверьте файл Excel.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newSupplier() async {
    final name = await _prompt('Имя поставщика', 'ООО Поставщик');
    if (name == null || name.trim().isEmpty) return;
    final phone = await _prompt('Телефон', '') ?? '';
    if (!mounted) return;
    await context.read<MastersStore>().createSupplier(name: name.trim(), phone: phone.trim());
  }

  Future<void> _recordPurchase() async {
    final store = context.read<MastersStore>();
    if (store.suppliers.isEmpty) {
      await showAppAlert(context, title: 'Нет поставщиков', message: 'Сначала добавьте поставщика.');
      return;
    }
    final supplierId = await _pickSupplier(store);
    if (supplierId == null || !mounted) return;
    final itemId = await _pickInventoryItem(store);
    if (itemId == null || !mounted) return;
    final qtyStr = await _prompt('Количество', '1');
    final qty = double.tryParse((qtyStr ?? '').trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0 || !mounted) return;
    final priceStr = await _prompt('Цена за ед.', '0');
    final price = ((double.tryParse((priceStr ?? '0').replaceAll(',', '.')) ?? 0) * 100).round();
    if (price <= 0 || !mounted) return;
    final note = await _prompt('Комментарий', '');
    if (!mounted) return;
    final accountId = await _pickAccount(store);
    if (accountId == null || !mounted) return;
    final paidStr = await _prompt('Оплачено сейчас (0 = долг)', '0');
    final paid = ((double.tryParse((paidStr ?? '0').replaceAll(',', '.')) ?? 0) * 100).round();
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await store.createPurchase(
        supplierId: supplierId,
        accountId: paid > 0 ? accountId : null,
        paidCents: paid,
        note: note,
        lines: [
          {'itemId': itemId, 'qty': qty, 'unitPriceCents': price},
        ],
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSupplierDetail(Supplier supplier) async {
    final store = context.read<MastersStore>();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        color: context.colors.card,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(supplier.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Долг: ${_money(store.supplierDebtCents(supplier.id))}', style: TextStyle(color: context.colors.secondaryLabel)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final purchase in store.purchasesForSupplier(supplier.id))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('#${purchase.id.substring(0, 6)} · ${_money(purchase.totalCents)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () async {
                                  Navigator.of(modalContext).pop();
                                  await _paySupplier(supplier);
                                },
                                child: const Text('Оплатить', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (store.purchasesForSupplier(supplier.id).isEmpty)
                      EmptyState(title: 'Нет закупок', message: 'Запишите первую закупку для поставщика.'),
                  ],
                ),
              ),
              SecondaryButton(label: 'Закрыть', icon: CupertinoIcons.xmark, onPressed: () => Navigator.of(modalContext).pop()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _paySupplier(Supplier supplier) async {
    final store = context.read<MastersStore>();
    if (store.accounts.isEmpty) {
      await showAppAlert(context, title: 'Нет счёта', message: 'Сначала создайте счёт в разделе Деньги.');
      return;
    }
    final purchases = store.purchasesForSupplier(supplier.id);
    String? selectedPurchaseId;
    if (purchases.length == 1) {
      selectedPurchaseId = purchases.first.id;
    } else if (purchases.length > 1) {
      selectedPurchaseId = await showCupertinoModalPopup<String?>(
        context: context,
        builder: (ctx) => Container(
          height: 260,
          color: context.colors.card,
          child: ListView(
            children: [
              CupertinoButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Общая оплата (без привязки)')),
              for (final purchase in purchases)
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(purchase.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Закупка ${purchase.id.substring(0, 6)} · ${_money(purchase.totalCents)}'),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final amountStr = await _prompt('Сумма оплаты', '0');
    final amount = ((double.tryParse((amountStr ?? '').replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0 || !mounted) return;
    final accountId = await _pickAccount(store);
    if (accountId == null || !mounted) return;
    final note = await _prompt('Комментарий', '') ?? '';
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final supplierPurchases = store.purchasesForSupplier(supplier.id);
      final purchaseId = selectedPurchaseId ?? (supplierPurchases.isEmpty ? null : supplierPurchases.first.id);
      await store.paySupplier(supplierId: supplier.id, amountCents: amount, accountId: accountId, purchaseId: purchaseId, note: note.trim().isEmpty ? null : note.trim());
      if (mounted) await showAppAlert(context, title: 'Готово', message: 'Оплата поставщику проведена.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final ok = await showAppConfirm(context, title: 'Удалить поставщика?', message: supplier.name, destructive: true, confirmLabel: 'Удалить');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().deleteSupplier(supplier.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickSupplier(MastersStore store) async {
    final suppliers = store.suppliers;
    if (suppliers.isEmpty) return null;
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 220,
        color: context.colors.card,
        child: ListView(
          children: [
            for (final supplier in suppliers)
              CupertinoButton(
                onPressed: () => Navigator.of(ctx).pop(supplier.id),
                child: Align(alignment: Alignment.centerLeft, child: Text(supplier.name)),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickInventoryItem(MastersStore store) async {
    final items = store.inventoryItems.where((i) => !i.archived).toList();
    if (items.isEmpty) return null;
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 220,
        color: context.colors.card,
        child: ListView(
          children: [
            for (final item in items)
              CupertinoButton(
                onPressed: () => Navigator.of(ctx).pop(item.id),
                child: Align(alignment: Alignment.centerLeft, child: Text(item.name)),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickAccount(MastersStore store) async {
    final accounts = store.accounts.where((a) => !a.archived).toList();
    if (accounts.isEmpty) return null;
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 220,
        color: context.colors.card,
        child: ListView(
          children: [
            for (final account in accounts)
              CupertinoButton(
                onPressed: () => Navigator.of(ctx).pop(account.id),
                child: Align(alignment: Alignment.centerLeft, child: Text(account.name)),
              ),
          ],
        ),
      ),
    );
  }

  String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} ₽';

  Future<void> _delete(InventoryItem item) async {
    final ok = await showAppConfirm(context, title: 'Удалить позицию?', message: item.name, destructive: true, confirmLabel: 'Удалить');
    if (!ok) return;
    if (!mounted) return;
    await context.read<MastersStore>().deleteInventoryItem(item.id);
  }

  Future<void> _editItem(InventoryItem item) async {
    final name = await _prompt('Название', item.name, initial: item.name);
    if (name == null || name.trim().isEmpty) return;
    final unit = await _pickUnit() ?? item.unit;
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            CupertinoButton(padding: EdgeInsets.zero, onPressed: _newItem, child: const Icon(CupertinoIcons.plus, semanticLabel: 'Добавить')),
          ],
        ),
      ),
      child: _busy
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
                children: [
                                     if (store.suppliers.isNotEmpty || true) ...[
                     const SizedBox(height: 0),
                   ],
                   SectionLabel('Поставщики и закупки (${store.suppliers.length})'),
                   PrimaryButton(label: 'Новый поставщик', icon: CupertinoIcons.person_badge_plus, onPressed: _newSupplier),
                   const SizedBox(height: 8),
                   SecondaryButton(label: 'Записать закупку', icon: CupertinoIcons.doc_on_clipboard, onPressed: _recordPurchase),
                   const SizedBox(height: 8),
                   if (store.suppliers.isEmpty)
                     EmptyState(title: 'Нет поставщиков', message: 'Добавьте поставщика, чтобы учитывать закупки и долги.', art: Icon(CupertinoIcons.person_2, size: 36, color: colors.tertiaryLabel))
                   else
                     AppCard(
                       child: Column(
                         children: [
                           for (final supplier in store.suppliers)
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 4),
                               child: Row(
                                 children: [
                                   Expanded(child: GestureDetector(onTap: () => _showSupplierDetail(supplier), child: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w600)))),
                                   Text('Долг: ${_money(store.supplierDebtCents(supplier.id))}', style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                                   CupertinoButton(padding: EdgeInsets.zero, onPressed: () => _paySupplier(supplier), child: const Icon(CupertinoIcons.money_dollar, size: 18)),
                                   CupertinoButton(padding: EdgeInsets.zero, onPressed: () => _deleteSupplier(supplier), child: Icon(CupertinoIcons.xmark, size: 16, color: colors.tertiaryLabel)),
                                 ],
                               ),
                             ),
                         ],
                       ),
                     ),
                   const SizedBox(height: 16),
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
                  SecondaryButton(label: 'Импорт из Excel', icon: CupertinoIcons.doc_on_doc, onPressed: _importInventoryExcel),
                  const SizedBox(height: 8),
                   const SizedBox(height: 8),
                   CupertinoTextField(
                     controller: _searchController,
                     placeholder: 'Поиск по складу',
                     onChanged: (v) => setState(() => _invQuery = v),
                   ),
                   const SizedBox(height: 8),
                   SecondaryButton(
                     label: _invFilter == 'all' ? 'Фильтр: все' : (_invFilter == 'good' ? 'Товары' : (_invFilter == 'service' ? 'Услуги' : 'Мало')),
                     icon: CupertinoIcons.line_horizontal_3_decrease,
                     onPressed: _pickInventoryFilter,
                   ),
                   const SizedBox(height: 8),
                   SectionLabel('Позиции (${_filteredInventory(store).length})'),
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