import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../data/models/inventory_item.dart';
import '../../data/models/stock_movement.dart';
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

  Future<String?> _prompt(
    String title,
    String placeholder, {
    String? initial,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    return showCupertinoDialog<String?>(
      context: context,
      builder: (dc) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dc).pop(),
            child: const Text('Р С›РЎвЂљР СР ВµР Р…Р В°'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dc).pop(controller.text.trim()),
            child: const Text('Р С›Р С™'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickUnit() async {
    final unit = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Р вЂўР Т‘Р С‘Р Р…Р С‘РЎвЂ Р В° Р С‘Р В·Р СР ВµРЎР‚Р ВµР Р…Р С‘РЎРЏ'),
        actions: [
          for (final item in [
            'РЎв‚¬РЎвЂљ',
            'Р С–',
            'Р С”Р С–',
            'Р СР В»',
            'Р В»',
            'Р С',
            'РЎРѓР С',
            'РЎС“Р С—Р В°Р С”',
            'РЎС“РЎРѓР В»РЎС“Р С–Р В°',
          ])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop(item),
              child: Text(item),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('__custom__'),
            child: const Text('Р вЂќРЎР‚РЎС“Р С–Р В°РЎРЏ...'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Р С›РЎвЂљР СР ВµР Р…Р В°'),
        ),
      ),
    );
    if (unit == null) return null;
    if (unit == '__custom__') return _prompt('Р вЂўР Т‘Р С‘Р Р…Р С‘РЎвЂ Р В°', 'РЎв‚¬РЎвЂљ');
    return unit;
  }

  List<InventoryItem> _filteredInventory(MastersStore store) {
    var list = store.inventoryItems.where((i) => !i.archived).toList();
    final q = _invQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.unit.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_invFilter == 'good') {
      list = list.where((i) => i.kind == 'good').toList();
    }
    if (_invFilter == 'service') {
      list = list.where((i) => i.kind == 'service').toList();
    }
    if (_invFilter == 'low') {
      list = list.where((i) => i.lowStock).toList();
    }
    return list;
  }

  Future<void> _pickInventoryFilter() async {
    final v = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Р В¤Р С‘Р В»РЎРЉРЎвЂљРЎР‚ РЎРѓР С”Р В»Р В°Р Т‘Р В°'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('all'),
            child: const Text('Р вЂ™РЎРѓР Вµ Р С—Р С•Р В·Р С‘РЎвЂ Р С‘Р С‘'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('good'),
            child: const Text('Р СћР С•Р В»РЎРЉР С”Р С• РЎвЂљР С•Р Р†Р В°РЎР‚РЎвЂ№'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('service'),
            child: const Text('Р СћР С•Р В»РЎРЉР С”Р С• РЎС“РЎРѓР В»РЎС“Р С–Р С‘'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('low'),
            child: const Text('Р СљР В°Р В»Р С• Р Р…Р В° РЎРѓР С”Р В»Р В°Р Т‘Р Вµ'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Р С›РЎвЂљР СР ВµР Р…Р В°'),
        ),
      ),
    );
    if (v != null) setState(() => _invFilter = v);
  }

  Future<void> _newItem() async {
    final name = await _prompt('Р СњР В°Р В·Р Р†Р В°Р Р…Р С‘Р Вµ Р С—Р С•Р В·Р С‘РЎвЂ Р С‘Р С‘', 'Р СљР В°РЎРѓР В»Р С• Р СР С•РЎвЂљР С•РЎР‚Р Р…Р С•Р Вµ 5W-30');
    if (name == null || name.trim().isEmpty) return;
    final kind = await _pickKind();
    if (kind == null) return;
    final unit = await _pickUnit() ?? 'РЎв‚¬РЎвЂљ';
    final sellStr = await _prompt('Р В¦Р ВµР Р…Р В° Р С—РЎР‚Р С•Р Т‘Р В°Р В¶Р С‘ (РІвЂљР…)', '0') ?? '0';
    final costStr = await _prompt('Р РЋР ВµР В±Р ВµРЎРѓРЎвЂљР С•Р С‘Р СР С•РЎРѓРЎвЂљРЎРЉ (РІвЂљР…)', '0') ?? '0';
    final minStr = await _prompt('Р СљР С‘Р Р…. Р С•РЎРѓРЎвЂљР В°РЎвЂљР С•Р С”', '0') ?? '0';
    if (!mounted) return;
    final track = await showAppConfirm(
      context,
      title: 'Р Р€РЎвЂЎР С‘РЎвЂљРЎвЂ№Р Р†Р В°РЎвЂљРЎРЉ Р С•РЎРѓРЎвЂљР В°РЎвЂљР С•Р С”?',
      message: 'Р вЂќР В»РЎРЏ РЎС“РЎРѓР В»РЎС“Р С– Р СР С•Р В¶Р Р…Р С• Р С•РЎвЂљР С”Р В»РЎР‹РЎвЂЎР С‘РЎвЂљРЎРЉ РЎС“РЎвЂЎРЎвЂРЎвЂљ РЎРѓР С”Р В»Р В°Р Т‘Р В°.',
      confirmLabel: 'Р Р€РЎвЂЎР С‘РЎвЂљРЎвЂ№Р Р†Р В°РЎвЂљРЎРЉ',
    );
    final sell = ((double.tryParse(sellStr.replaceAll(',', '.')) ?? 0) * 100)
        .round();
    final cost = ((double.tryParse(costStr.replaceAll(',', '.')) ?? 0) * 100)
        .round();
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
            CupertinoButton(
              child: const Text('Р СћР С•Р Р†Р В°РЎР‚'),
              onPressed: () => Navigator.of(ctx).pop('good'),
            ),
            CupertinoButton(
              child: const Text('Р Р€РЎРѓР В»РЎС“Р С–Р В°'),
              onPressed: () => Navigator.of(ctx).pop('service'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _receiveStock(InventoryItem item) async {
    final qtyStr = await _prompt('Р СџР С•РЎРѓРЎвЂљРЎС“Р С—Р В»Р ВµР Р…Р С‘Р Вµ, Р С”Р С•Р В»-Р Р†Р С• (${item.unit})', '1');
    final qty = double.tryParse((qtyStr ?? '').replaceAll(',', '.'));
    if (qty == null || qty <= 0) return;
    final costStr =
        await _prompt(
          'Р В¦Р ВµР Р…Р В° Р В·Р В° Р ВµР Т‘. (РІвЂљР…)',
          (item.costCents / 100).toStringAsFixed(0),
        ) ??
        '0';
    final _ = costStr;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().receiveStock(
        itemId: item.id,
        qty: qty,
        note: 'Р вЂ”Р В°Р С”РЎС“Р С—Р С”Р В°',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _writeOff(InventoryItem item) async {
    final qtyStr = await _prompt('Р РЋР С—Р С‘РЎРѓР В°Р Р…Р С‘Р Вµ, Р С”Р С•Р В»-Р Р†Р С• (${item.unit})', '1');
    final qty = double.tryParse((qtyStr ?? '').replaceAll(',', '.'));
    if (qty == null || qty <= 0) return;
    final reason = await _prompt('Р СџРЎР‚Р С‘РЎвЂЎР С‘Р Р…Р В°', 'Р вЂРЎР‚Р В°Р С”/РЎРѓР С—Р С‘РЎРѓР В°Р Р…Р С‘Р Вµ') ?? 'Р РЋР С—Р С‘РЎРѓР В°Р Р…Р С‘Р Вµ';
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().writeOffStock(
        itemId: item.id,
        qty: qty,
        note: reason,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importInventoryExcel() async {
    setState(() => _busy = true);
    try {
      final count = await context
          .read<MastersStore>()
          .importInventoryFromExcel();
      if (!mounted) return;
      await showAppAlert(
        context,
        title: count > 0 ? 'Р ВР СР С—Р С•РЎР‚РЎвЂљ Р В·Р В°Р Р†Р ВµРЎР‚РЎв‚¬РЎвЂР Р…' : 'Р ВР СР С—Р С•РЎР‚РЎвЂљ',
        message: count > 0 ? 'Р вЂќР С•Р В±Р В°Р Р†Р В»Р ВµР Р…Р С• РЎвЂљР С•Р Р†Р В°РЎР‚Р С•Р Р†/РЎС“РЎРѓР В»РЎС“Р С–: $count.' : 'Р СњР Вµ РЎС“Р Т‘Р В°Р В»Р С•РЎРѓРЎРЉ Р Т‘Р С•Р В±Р В°Р Р†Р С‘РЎвЂљРЎРЉ Р В·Р В°Р С—Р С‘РЎРѓР С‘. Р СњРЎС“Р В¶Р ВµР Р… РЎРѓРЎвЂљР С•Р В»Р В±Р ВµРЎвЂ  name; Р С—РЎР‚Р С•Р Р†Р ВµРЎР‚РЎРЉРЎвЂљР Вµ РЎвЂћР В°Р в„–Р В» Excel.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newSupplier() async {
    final name = await _prompt('Р ВР СРЎРЏ Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”Р В°', 'Р С›Р С›Р С› Р СџР С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”');
    if (name == null || name.trim().isEmpty) return;
    final phone = await _prompt('Р СћР ВµР В»Р ВµРЎвЂћР С•Р Р…', '') ?? '';
    if (!mounted) return;
    await context.read<MastersStore>().createSupplier(
      name: name.trim(),
      phone: phone.trim(),
    );
  }

  Future<void> _recordPurchase() async {
    final store = context.read<MastersStore>();
    if (store.suppliers.isEmpty) {
      await showAppAlert(
        context,
        title: 'Р СњР ВµРЎвЂљ Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”Р С•Р Р†',
        message: 'Р РЋР Р…Р В°РЎвЂЎР В°Р В»Р В° Р Т‘Р С•Р В±Р В°Р Р†РЎРЉРЎвЂљР Вµ Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”Р В°.',
      );
      return;
    }
    final supplierId = await _pickSupplier(store);
    if (supplierId == null || !mounted) return;
    final itemId = await _pickInventoryItem(store);
    if (itemId == null || !mounted) return;
    final qtyStr = await _prompt('Р С™Р С•Р В»Р С‘РЎвЂЎР ВµРЎРѓРЎвЂљР Р†Р С•', '1');
    final qty = double.tryParse((qtyStr ?? '').trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0 || !mounted) return;
    final priceStr = await _prompt('Р В¦Р ВµР Р…Р В° Р В·Р В° Р ВµР Т‘.', '0');
    final price =
        ((double.tryParse((priceStr ?? '0').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    if (price <= 0 || !mounted) return;
    final note = await _prompt('Р С™Р С•Р СР СР ВµР Р…РЎвЂљР В°РЎР‚Р С‘Р в„–', '');
    if (!mounted) return;
    final accountId = await _pickAccount(store);
    if (accountId == null || !mounted) return;
    final paidStr = await _prompt('Р С›Р С—Р В»Р В°РЎвЂЎР ВµР Р…Р С• РЎРѓР ВµР в„–РЎвЂЎР В°РЎРѓ (0 = Р Т‘Р С•Р В»Р С–)', '0');
    final paid =
        ((double.tryParse((paidStr ?? '0').replaceAll(',', '.')) ?? 0) * 100)
            .round();
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
              Text(
                supplier.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Р вЂќР С•Р В»Р С–: ${_money(store.supplierDebtCents(supplier.id))}',
                style: TextStyle(color: context.colors.secondaryLabel),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final purchase in store.purchasesForSupplier(
                      supplier.id,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '#${purchase.id.substring(0, 6)} Р’В· ${_money(purchase.totalCents)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () async {
                                  Navigator.of(modalContext).pop();
                                  await _paySupplier(supplier);
                                },
                                child: const Text(
                                  'Р С›Р С—Р В»Р В°РЎвЂљР С‘РЎвЂљРЎРЉ',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (store.purchasesForSupplier(supplier.id).isEmpty)
                      EmptyState(
                        title: 'Р СњР ВµРЎвЂљ Р В·Р В°Р С”РЎС“Р С—Р С•Р С”',
                        message: 'Р вЂ”Р В°Р С—Р С‘РЎв‚¬Р С‘РЎвЂљР Вµ Р С—Р ВµРЎР‚Р Р†РЎС“РЎР‹ Р В·Р В°Р С”РЎС“Р С—Р С”РЎС“ Р Т‘Р В»РЎРЏ Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”Р В°.',
                      ),
                  ],
                ),
              ),
              SecondaryButton(
                label: 'Р вЂ”Р В°Р С”РЎР‚РЎвЂ№РЎвЂљРЎРЉ',
                icon: CupertinoIcons.xmark,
                onPressed: () => Navigator.of(modalContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _paySupplier(Supplier supplier) async {
    final store = context.read<MastersStore>();
    if (store.accounts.isEmpty) {
      await showAppAlert(
        context,
        title: 'Р СњР ВµРЎвЂљ РЎРѓРЎвЂЎРЎвЂРЎвЂљР В°',
        message: 'Р РЋР Р…Р В°РЎвЂЎР В°Р В»Р В° РЎРѓР С•Р В·Р Т‘Р В°Р в„–РЎвЂљР Вµ РЎРѓРЎвЂЎРЎвЂРЎвЂљ Р Р† РЎР‚Р В°Р В·Р Т‘Р ВµР В»Р Вµ Р вЂќР ВµР Р…РЎРЉР С–Р С‘.',
      );
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
              CupertinoButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Р С›Р В±РЎвЂ°Р В°РЎРЏ Р С•Р С—Р В»Р В°РЎвЂљР В° (Р В±Р ВµР В· Р С—РЎР‚Р С‘Р Р†РЎРЏР В·Р С”Р С‘)'),
              ),
              for (final purchase in purchases)
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(purchase.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Р вЂ”Р В°Р С”РЎС“Р С—Р С”Р В° ${purchase.id.substring(0, 6)} Р’В· ${_money(purchase.totalCents)}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final amountStr = await _prompt('Р РЋРЎС“Р СР СР В° Р С•Р С—Р В»Р В°РЎвЂљРЎвЂ№', '0');
    final amount =
        ((double.tryParse((amountStr ?? '').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    if (amount <= 0 || !mounted) return;
    final accountId = await _pickAccount(store);
    if (accountId == null || !mounted) return;
    final note = await _prompt('Р С™Р С•Р СР СР ВµР Р…РЎвЂљР В°РЎР‚Р С‘Р в„–', '') ?? '';
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final supplierPurchases = store.purchasesForSupplier(supplier.id);
      final purchaseId =
          selectedPurchaseId ??
          (supplierPurchases.isEmpty ? null : supplierPurchases.first.id);
      await store.paySupplier(
        supplierId: supplier.id,
        amountCents: amount,
        accountId: accountId,
        purchaseId: purchaseId,
        note: note.trim().isEmpty ? null : note.trim(),
      );
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Р вЂњР С•РЎвЂљР С•Р Р†Р С•',
          message: 'Р С›Р С—Р В»Р В°РЎвЂљР В° Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”РЎС“ Р С—РЎР‚Р С•Р Р†Р ВµР Т‘Р ВµР Р…Р В°.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final ok = await showAppConfirm(
      context,
      title: 'Р Р€Р Т‘Р В°Р В»Р С‘РЎвЂљРЎРЉ Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”Р В°?',
      message: supplier.name,
      destructive: true,
      confirmLabel: 'Р Р€Р Т‘Р В°Р В»Р С‘РЎвЂљРЎРЉ',
    );
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(supplier.name),
                ),
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(item.name),
                ),
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(account.name),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} РІвЂљР…';

  Future<void> _delete(InventoryItem item) async {
    final ok = await showAppConfirm(
      context,
      title: 'Р Р€Р Т‘Р В°Р В»Р С‘РЎвЂљРЎРЉ Р С—Р С•Р В·Р С‘РЎвЂ Р С‘РЎР‹?',
      message: item.name,
      destructive: true,
      confirmLabel: 'Р Р€Р Т‘Р В°Р В»Р С‘РЎвЂљРЎРЉ',
    );
    if (!ok) return;
    if (!mounted) return;
    await context.read<MastersStore>().deleteInventoryItem(item.id);
  }

  Future<void> _editItem(InventoryItem item) async {
    final name = await _prompt('Р СњР В°Р В·Р Р†Р В°Р Р…Р С‘Р Вµ', item.name, initial: item.name);
    if (name == null || name.trim().isEmpty) return;
    final unit = await _pickUnit() ?? item.unit;
    final sellStr =
        await _prompt(
          'Р В¦Р ВµР Р…Р В° Р С—РЎР‚Р С•Р Т‘Р В°Р В¶Р С‘ (РІвЂљР…)',
          (item.sellPriceCents / 100).toStringAsFixed(0),
          initial: (item.sellPriceCents / 100).toStringAsFixed(0),
        ) ??
        (item.sellPriceCents / 100).toString();
    final costStr =
        await _prompt(
          'Р РЋР ВµР В±Р ВµРЎРѓРЎвЂљР С•Р С‘Р СР С•РЎРѓРЎвЂљРЎРЉ (РІвЂљР…)',
          (item.costCents / 100).toStringAsFixed(0),
          initial: (item.costCents / 100).toStringAsFixed(0),
        ) ??
        '0';
    final minStr =
        await _prompt(
          'Р СљР С‘Р Р…. Р С•РЎРѓРЎвЂљР В°РЎвЂљР С•Р С”',
          item.minQty.toString(),
          initial: item.minQty.toString(),
        ) ??
        '0';
    if (!mounted) return;
    final sell = ((double.tryParse(sellStr.replaceAll(',', '.')) ?? 0) * 100)
        .round();
    final cost = ((double.tryParse(costStr.replaceAll(',', '.')) ?? 0) * 100)
        .round();
    final minQty = double.tryParse(minStr.replaceAll(',', '.')) ?? 0;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().updateInventoryItem(
        item.copyWith(
          name: name.trim(),
          unit: unit.trim(),
          sellPriceCents: sell,
          costCents: cost,
          minQty: minQty,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showItemHistory(InventoryItem item) async {
    final store = context.read<MastersStore>();
    final movements = store.stockMovementsByItem(item.id);

    String typeLabel(String type) {
      switch (type) {
        case 'in':
          return 'Поступление';
        case 'out':
          return 'Расход';
        case 'writeoff':
          return 'Списание';
        case 'adjust':
          return 'Корректировка';
        default:
          return type;
      }
    }

    double signedDelta(StockMovement movement) {
      if (movement.qty < 0) return movement.qty;
      switch (movement.type) {
        case 'out':
        case 'writeoff':
        case 'sale':
          return -movement.qty;
        default:
          return movement.qty;
      }
    }

    final balancesAfter = <String, double>{};
    double running = item.stockQty;
    for (final movement in movements) {
      balancesAfter[movement.id] = running;
      running -= signedDelta(movement);
    }

    String formatQty(double value) {
      final abs = value.abs();
      final decimals = abs % 1 == 0 ? 0 : 2;
      return abs.toStringAsFixed(decimals);
    }

    String formatStock(double value) {
      final prefix = value < 0 ? '−' : '';
      return '$prefix${formatQty(value)}';
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) {
        final colors = context.colors;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          color: colors.card,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(modalContext).pop(),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 18,
                        color: colors.tertiaryLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.stockQty < 0
                      ? 'Текущий остаток: −${formatQty(item.stockQty)} ${item.unit} • Отрицательный остаток'
                      : 'Текущий остаток: ${formatQty(item.stockQty)} ${item.unit}',
                  style: TextStyle(
                    color: item.stockQty < 0 ? colors.red : colors.secondaryLabel,
                    fontSize: 13,
                    fontWeight: item.stockQty < 0
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Себестоимость позиции: ${(item.costCents / 100).toStringAsFixed(2)} ₽/${item.unit}',
                  style: TextStyle(
                    color: colors.secondaryLabel,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: movements.isEmpty
                      ? EmptyState(
                          title: 'Нет движений',
                          message:
                              'История поступлений и списаний по этой позиции появится здесь.',
                          art: Icon(
                            CupertinoIcons.clock,
                            size: 36,
                            color: colors.tertiaryLabel,
                          ),
                        )
                      : ListView.builder(
                          itemCount: movements.length,
                          itemBuilder: (context, index) {
                            final movement = movements[index];
                            final delta = signedDelta(movement);
                            final isIncrease = delta >= 0;
                            final qtyColor = isIncrease ? colors.label : colors.red;
                            final qtyPrefix = isIncrease ? '+' : '−';
                            final reason = movement.note?.trim();
                            final balance = balancesAfter[movement.id] ?? item.stockQty;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${typeLabel(movement.type)}${reason == null || reason.isEmpty ? '' : ' · $reason'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat(
                                                  'dd.MM.yyyy HH:mm',
                                                  'ru',
                                                ).format(movement.createdAt),
                                                style: TextStyle(
                                                  color: colors.secondaryLabel,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '$qtyPrefix${formatQty(delta)} ${item.unit}',
                                          style: TextStyle(
                                            color: qtyColor,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Остаток после: ${formatStock(balance)} ${item.unit}${balance < 0 ? ' • Отрицательный остаток' : ''}',
                                      style: TextStyle(
                                        color: balance < 0
                                            ? colors.red
                                            : colors.secondaryLabel,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SecondaryButton(
                  label: 'Закрыть',
                  icon: CupertinoIcons.xmark,
                  onPressed: () => Navigator.of(modalContext).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
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
        middle: const Text('Р РЋР С”Р В»Р В°Р Т‘'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _newItem,
              child: const Icon(CupertinoIcons.plus, semanticLabel: 'Р вЂќР С•Р В±Р В°Р Р†Р С‘РЎвЂљРЎРЉ'),
            ),
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
                  SectionLabel(
                    'Р СџР С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”Р С‘ Р С‘ Р В·Р В°Р С”РЎС“Р С—Р С”Р С‘ (${store.suppliers.length})',
                  ),
                  PrimaryButton(
                    label: 'Р СњР С•Р Р†РЎвЂ№Р в„– Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”',
                    icon: CupertinoIcons.person_badge_plus,
                    onPressed: _newSupplier,
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Р вЂ”Р В°Р С—Р С‘РЎРѓР В°РЎвЂљРЎРЉ Р В·Р В°Р С”РЎС“Р С—Р С”РЎС“',
                    icon: CupertinoIcons.doc_on_clipboard,
                    onPressed: _recordPurchase,
                  ),
                  const SizedBox(height: 8),
                  if (store.suppliers.isEmpty)
                    EmptyState(
                      title: 'Р СњР ВµРЎвЂљ Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”Р С•Р Р†',
                      message: 'Р вЂќР С•Р В±Р В°Р Р†РЎРЉРЎвЂљР Вµ Р С—Р С•РЎРѓРЎвЂљР В°Р Р†РЎвЂ°Р С‘Р С”Р В°, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ РЎС“РЎвЂЎР С‘РЎвЂљРЎвЂ№Р Р†Р В°РЎвЂљРЎРЉ Р В·Р В°Р С”РЎС“Р С—Р С”Р С‘ Р С‘ Р Т‘Р С•Р В»Р С–Р С‘.',
                      art: Icon(
                        CupertinoIcons.person_2,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        children: [
                          for (final supplier in store.suppliers)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showSupplierDetail(supplier),
                                      child: Text(
                                        supplier.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Р вЂќР С•Р В»Р С–: ${_money(store.supplierDebtCents(supplier.id))}',
                                    style: TextStyle(
                                      color: colors.secondaryLabel,
                                      fontSize: 12,
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _paySupplier(supplier),
                                    child: const Icon(
                                      CupertinoIcons.money_dollar,
                                      size: 18,
                                      semanticLabel: 'Р С›Р С—Р В»Р В°РЎвЂљР С‘РЎвЂљРЎРЉ',
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _deleteSupplier(supplier),
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      size: 16,
                                      color: colors.tertiaryLabel,
                                      semanticLabel: 'Р Р€Р Т‘Р В°Р В»Р С‘РЎвЂљРЎРЉ',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (low.isNotEmpty) ...[
                    SectionLabel('Р СњР С‘Р В·Р С”Р С‘Р в„– Р С•РЎРѓРЎвЂљР В°РЎвЂљР С•Р С” (${low.length})'),
                    AppCard(
                      child: Column(
                        children: low
                            .map(
                              (i) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        i.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${i.stockQty.toStringAsFixed(i.stockQty % 1 == 0 ? 0 : 2)} ${i.unit} (Р СР С‘Р Р… ${i.minQty})',
                                      style: TextStyle(
                                        color: colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SecondaryButton(
                    label: 'Р ВР СР С—Р С•РЎР‚РЎвЂљ Р С‘Р В· Excel',
                    icon: CupertinoIcons.doc_on_doc,
                    onPressed: _importInventoryExcel,
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _searchController,
                    placeholder: 'Р СџР С•Р С‘РЎРѓР С” Р С—Р С• РЎРѓР С”Р В»Р В°Р Т‘РЎС“',
                    onChanged: (v) => setState(() => _invQuery = v),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: _invFilter == 'all'
                        ? 'Р В¤Р С‘Р В»РЎРЉРЎвЂљРЎР‚: Р Р†РЎРѓР Вµ'
                        : (_invFilter == 'good'
                              ? 'Р СћР С•Р Р†Р В°РЎР‚РЎвЂ№'
                              : (_invFilter == 'service' ? 'Р Р€РЎРѓР В»РЎС“Р С–Р С‘' : 'Р СљР В°Р В»Р С•')),
                    icon: CupertinoIcons.line_horizontal_3_decrease,
                    onPressed: _pickInventoryFilter,
                  ),
                  const SizedBox(height: 8),
                  SectionLabel('Р СџР С•Р В·Р С‘РЎвЂ Р С‘Р С‘ (${_filteredInventory(store).length})'),
                  store.inventoryItems.isEmpty
                      ? EmptyState(
                          title: 'Р СњР ВµРЎвЂљ Р С—Р С•Р В·Р С‘РЎвЂ Р С‘Р в„–',
                          message: 'Р вЂќР С•Р В±Р В°Р Р†РЎРЉРЎвЂљР Вµ РЎвЂљР С•Р Р†Р В°РЎР‚ Р С‘Р В»Р С‘ РЎС“РЎРѓР В»РЎС“Р С–РЎС“.',
                          art: Icon(
                            CupertinoIcons.cube,
                            size: 48,
                            color: colors.tertiaryLabel,
                          ),
                          actions: [
                            PrimaryButton(
                              label: 'Р вЂќР С•Р В±Р В°Р Р†Р С‘РЎвЂљРЎРЉ Р С—Р С•Р В·Р С‘РЎвЂ Р С‘РЎР‹',
                              icon: CupertinoIcons.plus,
                              onPressed: _newItem,
                            ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${item.kind == 'service' ? 'Р Р€РЎРѓР В»РЎС“Р С–Р В°' : 'Р СћР С•Р Р†Р В°РЎР‚'} РІР‚Сћ ${item.unit} РІР‚Сћ Р С—РЎР‚Р С•Р Т‘Р В°Р В¶Р В° ${(item.sellPriceCents / 100).toStringAsFixed(0)} РІвЂљР…',
                                            style: TextStyle(
                                              color: colors.secondaryLabel,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (item.trackStock)
                                            Text(
                                              'Р С›РЎРѓРЎвЂљР В°РЎвЂљР С•Р С”: ${item.stockQty.toStringAsFixed(item.stockQty % 1 == 0 ? 0 : 2)} ${item.unit}${item.lowStock ? ' (Р СР В°Р В»Р С•)' : ''}',
                                              style: TextStyle(
                                                color: item.stockQty < 0
                                                    ? colors.red
                                                    : (item.lowStock
                                                          ? colors.red
                                                          : colors
                                                                .secondaryLabel),
                                                fontSize: 12,
                                              ),
                                            ),
                                          if (item.trackStock &&
                                              item.stockQty < 0)
                                            Text(
                                              'Р С›РЎвЂљРЎР‚Р С‘РЎвЂ Р В°РЎвЂљР ВµР В»РЎРЉР Р…РЎвЂ№Р в„– Р С•РЎРѓРЎвЂљР В°РЎвЂљР С•Р С”',
                                              style: TextStyle(
                                                color: colors.red,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (item.trackStock) ...[
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _receiveStock(item),
                                        child: const Icon(
                                          CupertinoIcons.plus_circle,
                                          size: 20,
                                          semanticLabel: 'Р СџРЎР‚Р С‘РЎвЂР С',
                                        ),
                                      ),
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _writeOff(item),
                                        child: const Icon(
                                          CupertinoIcons.minus_circle,
                                          size: 20,
                                          semanticLabel: 'Р РЋР С—Р С‘РЎРѓР В°Р Р…Р С‘Р Вµ',
                                        ),
                                      ),
                                    ],
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showItemHistory(item),
                                      child: const Text(
                                        'Р ВРЎРѓРЎвЂљР С•РЎР‚Р С‘РЎРЏ',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _delete(item),
                                      child: Icon(
                                        CupertinoIcons.xmark,
                                        size: 16,
                                        color: colors.tertiaryLabel,
                                        semanticLabel: 'Р Р€Р Т‘Р В°Р В»Р С‘РЎвЂљРЎРЉ',
                                      ),
                                    ),
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
