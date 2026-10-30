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
            child: const Text(
              'Р В РЎвЂєР РЋРІР‚С™Р В РЎВР В Р’ВµР В Р вЂ¦Р В Р’В°',
            ),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dc).pop(controller.text.trim()),
            child: const Text('Р В РЎвЂєР В РЎв„ў'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickUnit() async {
    final unit = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text(
          'Р В РІР‚СћР В РўвЂР В РЎвЂР В Р вЂ¦Р В РЎвЂР РЋРІР‚В Р В Р’В° Р В РЎвЂР В Р’В·Р В РЎВР В Р’ВµР РЋР вЂљР В Р’ВµР В Р вЂ¦Р В РЎвЂР РЋР РЏ',
        ),
        actions: [
          for (final item in [
            'Р РЋРІвЂљВ¬Р РЋРІР‚С™',
            'Р В РЎвЂ“',
            'Р В РЎвЂќР В РЎвЂ“',
            'Р В РЎВР В Р’В»',
            'Р В Р’В»',
            'Р В РЎВ',
            'Р РЋР С“Р В РЎВ',
            'Р РЋРЎвЂњР В РЎвЂ”Р В Р’В°Р В РЎвЂќ',
            'Р РЋРЎвЂњР РЋР С“Р В Р’В»Р РЋРЎвЂњР В РЎвЂ“Р В Р’В°',
          ])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop(item),
              child: Text(item),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('__custom__'),
            child: const Text(
              'Р В РІР‚СњР РЋР вЂљР РЋРЎвЂњР В РЎвЂ“Р В Р’В°Р РЋР РЏ...',
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(
            'Р В РЎвЂєР РЋРІР‚С™Р В РЎВР В Р’ВµР В Р вЂ¦Р В Р’В°',
          ),
        ),
      ),
    );
    if (unit == null) return null;
    if (unit == '__custom__') {
      return _prompt(
        'Р В РІР‚СћР В РўвЂР В РЎвЂР В Р вЂ¦Р В РЎвЂР РЋРІР‚В Р В Р’В°',
        'Р РЋРІвЂљВ¬Р РЋРІР‚С™',
      );
    }
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
        title: const Text(
          'Р В Р’В¤Р В РЎвЂР В Р’В»Р РЋР Р‰Р РЋРІР‚С™Р РЋР вЂљ Р РЋР С“Р В РЎвЂќР В Р’В»Р В Р’В°Р В РўвЂР В Р’В°',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('all'),
            child: const Text(
              'Р В РІР‚в„ўР РЋР С“Р В Р’Вµ Р В РЎвЂ”Р В РЎвЂўР В Р’В·Р В РЎвЂР РЋРІР‚В Р В РЎвЂР В РЎвЂ',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('good'),
            child: const Text(
              'Р В РЎС›Р В РЎвЂўР В Р’В»Р РЋР Р‰Р В РЎвЂќР В РЎвЂў Р РЋРІР‚С™Р В РЎвЂўР В Р вЂ Р В Р’В°Р РЋР вЂљР РЋРІР‚в„–',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('service'),
            child: const Text(
              'Р В РЎС›Р В РЎвЂўР В Р’В»Р РЋР Р‰Р В РЎвЂќР В РЎвЂў Р РЋРЎвЂњР РЋР С“Р В Р’В»Р РЋРЎвЂњР В РЎвЂ“Р В РЎвЂ',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('low'),
            child: const Text(
              'Р В РЎС™Р В Р’В°Р В Р’В»Р В РЎвЂў Р В Р вЂ¦Р В Р’В° Р РЋР С“Р В РЎвЂќР В Р’В»Р В Р’В°Р В РўвЂР В Р’Вµ',
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(
            'Р В РЎвЂєР РЋРІР‚С™Р В РЎВР В Р’ВµР В Р вЂ¦Р В Р’В°',
          ),
        ),
      ),
    );
    if (v != null) setState(() => _invFilter = v);
  }

  Future<void> _newItem() async {
    final name = await _prompt(
      'Р В РЎСљР В Р’В°Р В Р’В·Р В Р вЂ Р В Р’В°Р В Р вЂ¦Р В РЎвЂР В Р’Вµ Р В РЎвЂ”Р В РЎвЂўР В Р’В·Р В РЎвЂР РЋРІР‚В Р В РЎвЂР В РЎвЂ',
      'Р В РЎС™Р В Р’В°Р РЋР С“Р В Р’В»Р В РЎвЂў Р В РЎВР В РЎвЂўР РЋРІР‚С™Р В РЎвЂўР РЋР вЂљР В Р вЂ¦Р В РЎвЂўР В Р’Вµ 5W-30',
    );
    if (name == null || name.trim().isEmpty) return;
    final kind = await _pickKind();
    if (kind == null) return;
    final unit = await _pickUnit() ?? 'Р РЋРІвЂљВ¬Р РЋРІР‚С™';
    final sellStr =
        await _prompt(
          'Р В Р’В¦Р В Р’ВµР В Р вЂ¦Р В Р’В° Р В РЎвЂ”Р РЋР вЂљР В РЎвЂўР В РўвЂР В Р’В°Р В Р’В¶Р В РЎвЂ (Р Р†РІР‚С™Р вЂ¦)',
          '0',
        ) ??
        '0';
    final costStr =
        await _prompt(
          'Р В Р Р‹Р В Р’ВµР В Р’В±Р В Р’ВµР РЋР С“Р РЋРІР‚С™Р В РЎвЂўР В РЎвЂР В РЎВР В РЎвЂўР РЋР С“Р РЋРІР‚С™Р РЋР Р‰ (Р Р†РІР‚С™Р вЂ¦)',
          '0',
        ) ??
        '0';
    final minStr =
        await _prompt(
          'Р В РЎС™Р В РЎвЂР В Р вЂ¦. Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р РЋРІР‚С™Р В РЎвЂўР В РЎвЂќ',
          '0',
        ) ??
        '0';
    if (!mounted) return;
    final track = await showAppConfirm(
      context,
      title: 'Р В Р в‚¬Р РЋРІР‚РЋР В РЎвЂР РЋРІР‚С™Р РЋРІР‚в„–Р В Р вЂ Р В Р’В°Р РЋРІР‚С™Р РЋР Р‰ Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р РЋРІР‚С™Р В РЎвЂўР В РЎвЂќ?',
      message: 'Р В РІР‚СњР В Р’В»Р РЋР РЏ Р РЋРЎвЂњР РЋР С“Р В Р’В»Р РЋРЎвЂњР В РЎвЂ“ Р В РЎВР В РЎвЂўР В Р’В¶Р В Р вЂ¦Р В РЎвЂў Р В РЎвЂўР РЋРІР‚С™Р В РЎвЂќР В Р’В»Р РЋР вЂ№Р РЋРІР‚РЋР В РЎвЂР РЋРІР‚С™Р РЋР Р‰ Р РЋРЎвЂњР РЋРІР‚РЋР РЋРІР‚ВР РЋРІР‚С™ Р РЋР С“Р В РЎвЂќР В Р’В»Р В Р’В°Р В РўвЂР В Р’В°.',
      confirmLabel: 'Р В Р в‚¬Р РЋРІР‚РЋР В РЎвЂР РЋРІР‚С™Р РЋРІР‚в„–Р В Р вЂ Р В Р’В°Р РЋРІР‚С™Р РЋР Р‰',
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
              child: const Text('Р В РЎС›Р В РЎвЂўР В Р вЂ Р В Р’В°Р РЋР вЂљ'),
              onPressed: () => Navigator.of(ctx).pop('good'),
            ),
            CupertinoButton(
              child: const Text(
                'Р В Р в‚¬Р РЋР С“Р В Р’В»Р РЋРЎвЂњР В РЎвЂ“Р В Р’В°',
              ),
              onPressed: () => Navigator.of(ctx).pop('service'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _receiveStock(InventoryItem item) async {
    final qtyStr = await _prompt(
      'Р В РЎСџР В РЎвЂўР РЋР С“Р РЋРІР‚С™Р РЋРЎвЂњР В РЎвЂ”Р В Р’В»Р В Р’ВµР В Р вЂ¦Р В РЎвЂР В Р’Вµ, Р В РЎвЂќР В РЎвЂўР В Р’В»-Р В Р вЂ Р В РЎвЂў (${item.unit})',
      '1',
    );
    final qty = double.tryParse((qtyStr ?? '').replaceAll(',', '.'));
    if (qty == null || qty <= 0) return;
    final costStr =
        await _prompt(
          'Р В Р’В¦Р В Р’ВµР В Р вЂ¦Р В Р’В° Р В Р’В·Р В Р’В° Р В Р’ВµР В РўвЂ. (Р Р†РІР‚С™Р вЂ¦)',
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
        note: 'Р В РІР‚вЂќР В Р’В°Р В РЎвЂќР РЋРЎвЂњР В РЎвЂ”Р В РЎвЂќР В Р’В°',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _writeOff(InventoryItem item) async {
    final qtyStr = await _prompt(
      'Р В Р Р‹Р В РЎвЂ”Р В РЎвЂР РЋР С“Р В Р’В°Р В Р вЂ¦Р В РЎвЂР В Р’Вµ, Р В РЎвЂќР В РЎвЂўР В Р’В»-Р В Р вЂ Р В РЎвЂў (${item.unit})',
      '1',
    );
    final qty = double.tryParse((qtyStr ?? '').replaceAll(',', '.'));
    if (qty == null || qty <= 0) return;
    final reason =
        await _prompt(
          'Р В РЎСџР РЋР вЂљР В РЎвЂР РЋРІР‚РЋР В РЎвЂР В Р вЂ¦Р В Р’В°',
          'Р В РІР‚ВР РЋР вЂљР В Р’В°Р В РЎвЂќ/Р РЋР С“Р В РЎвЂ”Р В РЎвЂР РЋР С“Р В Р’В°Р В Р вЂ¦Р В РЎвЂР В Р’Вµ',
        ) ??
        'Р В Р Р‹Р В РЎвЂ”Р В РЎвЂР РЋР С“Р В Р’В°Р В Р вЂ¦Р В РЎвЂР В Р’Вµ';
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
        title: count > 0
            ? 'Р В Р’ВР В РЎВР В РЎвЂ”Р В РЎвЂўР РЋР вЂљР РЋРІР‚С™ Р В Р’В·Р В Р’В°Р В Р вЂ Р В Р’ВµР РЋР вЂљР РЋРІвЂљВ¬Р РЋРІР‚ВР В Р вЂ¦'
            : 'Р В Р’ВР В РЎВР В РЎвЂ”Р В РЎвЂўР РЋР вЂљР РЋРІР‚С™',
        message: count > 0
            ? 'Р В РІР‚СњР В РЎвЂўР В Р’В±Р В Р’В°Р В Р вЂ Р В Р’В»Р В Р’ВµР В Р вЂ¦Р В РЎвЂў Р РЋРІР‚С™Р В РЎвЂўР В Р вЂ Р В Р’В°Р РЋР вЂљР В РЎвЂўР В Р вЂ /Р РЋРЎвЂњР РЋР С“Р В Р’В»Р РЋРЎвЂњР В РЎвЂ“: $count.'
            : 'Р В РЎСљР В Р’Вµ Р РЋРЎвЂњР В РўвЂР В Р’В°Р В Р’В»Р В РЎвЂўР РЋР С“Р РЋР Р‰ Р В РўвЂР В РЎвЂўР В Р’В±Р В Р’В°Р В Р вЂ Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰ Р В Р’В·Р В Р’В°Р В РЎвЂ”Р В РЎвЂР РЋР С“Р В РЎвЂ. Р В РЎСљР РЋРЎвЂњР В Р’В¶Р В Р’ВµР В Р вЂ¦ Р РЋР С“Р РЋРІР‚С™Р В РЎвЂўР В Р’В»Р В Р’В±Р В Р’ВµР РЋРІР‚В  name; Р В РЎвЂ”Р РЋР вЂљР В РЎвЂўР В Р вЂ Р В Р’ВµР РЋР вЂљР РЋР Р‰Р РЋРІР‚С™Р В Р’Вµ Р РЋРІР‚С›Р В Р’В°Р В РІвЂћвЂ“Р В Р’В» Excel.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newSupplier() async {
    final name = await _prompt(
      'Р В Р’ВР В РЎВР РЋР РЏ Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР В Р’В°',
      'Р В РЎвЂєР В РЎвЂєР В РЎвЂє Р В РЎСџР В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќ',
    );
    if (name == null || name.trim().isEmpty) return;
    final phone =
        await _prompt(
          'Р В РЎС›Р В Р’ВµР В Р’В»Р В Р’ВµР РЋРІР‚С›Р В РЎвЂўР В Р вЂ¦',
          '',
        ) ??
        '';
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
        title: 'Р В РЎСљР В Р’ВµР РЋРІР‚С™ Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР В РЎвЂўР В Р вЂ ',
        message: 'Р В Р Р‹Р В Р вЂ¦Р В Р’В°Р РЋРІР‚РЋР В Р’В°Р В Р’В»Р В Р’В° Р В РўвЂР В РЎвЂўР В Р’В±Р В Р’В°Р В Р вЂ Р РЋР Р‰Р РЋРІР‚С™Р В Р’Вµ Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР В Р’В°.',
      );
      return;
    }
    final supplierId = await _pickSupplier(store);
    if (supplierId == null || !mounted) return;
    final itemId = await _pickInventoryItem(store);
    if (itemId == null || !mounted) return;
    final qtyStr = await _prompt(
      'Р В РЎв„ўР В РЎвЂўР В Р’В»Р В РЎвЂР РЋРІР‚РЋР В Р’ВµР РЋР С“Р РЋРІР‚С™Р В Р вЂ Р В РЎвЂў',
      '1',
    );
    final qty = double.tryParse((qtyStr ?? '').trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0 || !mounted) return;
    final priceStr = await _prompt(
      'Р В Р’В¦Р В Р’ВµР В Р вЂ¦Р В Р’В° Р В Р’В·Р В Р’В° Р В Р’ВµР В РўвЂ.',
      '0',
    );
    final price =
        ((double.tryParse((priceStr ?? '0').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    if (price <= 0 || !mounted) return;
    final note = await _prompt(
      'Р В РЎв„ўР В РЎвЂўР В РЎВР В РЎВР В Р’ВµР В Р вЂ¦Р РЋРІР‚С™Р В Р’В°Р РЋР вЂљР В РЎвЂР В РІвЂћвЂ“',
      '',
    );
    if (!mounted) return;
    final accountId = await _pickAccount(store);
    if (accountId == null || !mounted) return;
    final paidStr = await _prompt(
      'Р В РЎвЂєР В РЎвЂ”Р В Р’В»Р В Р’В°Р РЋРІР‚РЋР В Р’ВµР В Р вЂ¦Р В РЎвЂў Р РЋР С“Р В Р’ВµР В РІвЂћвЂ“Р РЋРІР‚РЋР В Р’В°Р РЋР С“ (0 = Р В РўвЂР В РЎвЂўР В Р’В»Р В РЎвЂ“)',
      '0',
    );
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
                'Р В РІР‚СњР В РЎвЂўР В Р’В»Р В РЎвЂ“: ${_money(store.supplierDebtCents(supplier.id))}',
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
                                  '#${purchase.id.substring(0, 6)} Р вЂ™Р’В· ${_money(purchase.totalCents)}',
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
                                  'Р В РЎвЂєР В РЎвЂ”Р В Р’В»Р В Р’В°Р РЋРІР‚С™Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (store.purchasesForSupplier(supplier.id).isEmpty)
                      EmptyState(
                        title: 'Р В РЎСљР В Р’ВµР РЋРІР‚С™ Р В Р’В·Р В Р’В°Р В РЎвЂќР РЋРЎвЂњР В РЎвЂ”Р В РЎвЂўР В РЎвЂќ',
                        message: 'Р В РІР‚вЂќР В Р’В°Р В РЎвЂ”Р В РЎвЂР РЋРІвЂљВ¬Р В РЎвЂР РЋРІР‚С™Р В Р’Вµ Р В РЎвЂ”Р В Р’ВµР РЋР вЂљР В Р вЂ Р РЋРЎвЂњР РЋР вЂ№ Р В Р’В·Р В Р’В°Р В РЎвЂќР РЋРЎвЂњР В РЎвЂ”Р В РЎвЂќР РЋРЎвЂњ Р В РўвЂР В Р’В»Р РЋР РЏ Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР В Р’В°.',
                      ),
                  ],
                ),
              ),
              SecondaryButton(
                label: 'Р В РІР‚вЂќР В Р’В°Р В РЎвЂќР РЋР вЂљР РЋРІР‚в„–Р РЋРІР‚С™Р РЋР Р‰',
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
        title: 'Р В РЎСљР В Р’ВµР РЋРІР‚С™ Р РЋР С“Р РЋРІР‚РЋР РЋРІР‚ВР РЋРІР‚С™Р В Р’В°',
        message: 'Р В Р Р‹Р В Р вЂ¦Р В Р’В°Р РЋРІР‚РЋР В Р’В°Р В Р’В»Р В Р’В° Р РЋР С“Р В РЎвЂўР В Р’В·Р В РўвЂР В Р’В°Р В РІвЂћвЂ“Р РЋРІР‚С™Р В Р’Вµ Р РЋР С“Р РЋРІР‚РЋР РЋРІР‚ВР РЋРІР‚С™ Р В Р вЂ  Р РЋР вЂљР В Р’В°Р В Р’В·Р В РўвЂР В Р’ВµР В Р’В»Р В Р’Вµ Р В РІР‚СњР В Р’ВµР В Р вЂ¦Р РЋР Р‰Р В РЎвЂ“Р В РЎвЂ.',
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
                child: const Text(
                  'Р В РЎвЂєР В Р’В±Р РЋРІР‚В°Р В Р’В°Р РЋР РЏ Р В РЎвЂўР В РЎвЂ”Р В Р’В»Р В Р’В°Р РЋРІР‚С™Р В Р’В° (Р В Р’В±Р В Р’ВµР В Р’В· Р В РЎвЂ”Р РЋР вЂљР В РЎвЂР В Р вЂ Р РЋР РЏР В Р’В·Р В РЎвЂќР В РЎвЂ)',
                ),
              ),
              for (final purchase in purchases)
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(purchase.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Р В РІР‚вЂќР В Р’В°Р В РЎвЂќР РЋРЎвЂњР В РЎвЂ”Р В РЎвЂќР В Р’В° ${purchase.id.substring(0, 6)} Р вЂ™Р’В· ${_money(purchase.totalCents)}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final amountStr = await _prompt(
      'Р В Р Р‹Р РЋРЎвЂњР В РЎВР В РЎВР В Р’В° Р В РЎвЂўР В РЎвЂ”Р В Р’В»Р В Р’В°Р РЋРІР‚С™Р РЋРІР‚в„–',
      '0',
    );
    final amount =
        ((double.tryParse((amountStr ?? '').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    if (amount <= 0 || !mounted) return;
    final accountId = await _pickAccount(store);
    if (accountId == null || !mounted) return;
    final note =
        await _prompt(
          'Р В РЎв„ўР В РЎвЂўР В РЎВР В РЎВР В Р’ВµР В Р вЂ¦Р РЋРІР‚С™Р В Р’В°Р РЋР вЂљР В РЎвЂР В РІвЂћвЂ“',
          '',
        ) ??
        '';
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
          title: 'Р В РІР‚СљР В РЎвЂўР РЋРІР‚С™Р В РЎвЂўР В Р вЂ Р В РЎвЂў',
          message: 'Р В РЎвЂєР В РЎвЂ”Р В Р’В»Р В Р’В°Р РЋРІР‚С™Р В Р’В° Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР РЋРЎвЂњ Р В РЎвЂ”Р РЋР вЂљР В РЎвЂўР В Р вЂ Р В Р’ВµР В РўвЂР В Р’ВµР В Р вЂ¦Р В Р’В°.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final ok = await showAppConfirm(
      context,
      title: 'Р В Р в‚¬Р В РўвЂР В Р’В°Р В Р’В»Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰ Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР В Р’В°?',
      message: supplier.name,
      destructive: true,
      confirmLabel:
          'Р В Р в‚¬Р В РўвЂР В Р’В°Р В Р’В»Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰',
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

  String _money(int cents) =>
      '${(cents / 100).toStringAsFixed(0)} Р Р†РІР‚С™Р вЂ¦';

  Future<void> _delete(InventoryItem item) async {
    final ok = await showAppConfirm(
      context,
      title: 'Р В Р в‚¬Р В РўвЂР В Р’В°Р В Р’В»Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰ Р В РЎвЂ”Р В РЎвЂўР В Р’В·Р В РЎвЂР РЋРІР‚В Р В РЎвЂР РЋР вЂ№?',
      message: item.name,
      destructive: true,
      confirmLabel:
          'Р В Р в‚¬Р В РўвЂР В Р’В°Р В Р’В»Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰',
    );
    if (!ok) return;
    if (!mounted) return;
    await context.read<MastersStore>().deleteInventoryItem(item.id);
  }

  Future<void> _editItem(InventoryItem item) async {
    final name = await _prompt(
      'Р В РЎСљР В Р’В°Р В Р’В·Р В Р вЂ Р В Р’В°Р В Р вЂ¦Р В РЎвЂР В Р’Вµ',
      item.name,
      initial: item.name,
    );
    if (name == null || name.trim().isEmpty) return;
    final unit = await _pickUnit() ?? item.unit;
    final sellStr =
        await _prompt(
          'Р В Р’В¦Р В Р’ВµР В Р вЂ¦Р В Р’В° Р В РЎвЂ”Р РЋР вЂљР В РЎвЂўР В РўвЂР В Р’В°Р В Р’В¶Р В РЎвЂ (Р Р†РІР‚С™Р вЂ¦)',
          (item.sellPriceCents / 100).toStringAsFixed(0),
          initial: (item.sellPriceCents / 100).toStringAsFixed(0),
        ) ??
        (item.sellPriceCents / 100).toString();
    final costStr =
        await _prompt(
          'Р В Р Р‹Р В Р’ВµР В Р’В±Р В Р’ВµР РЋР С“Р РЋРІР‚С™Р В РЎвЂўР В РЎвЂР В РЎВР В РЎвЂўР РЋР С“Р РЋРІР‚С™Р РЋР Р‰ (Р Р†РІР‚С™Р вЂ¦)',
          (item.costCents / 100).toStringAsFixed(0),
          initial: (item.costCents / 100).toStringAsFixed(0),
        ) ??
        '0';
    final minStr =
        await _prompt(
          'Р В РЎС™Р В РЎвЂР В Р вЂ¦. Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р РЋРІР‚С™Р В РЎвЂўР В РЎвЂќ',
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
    final movements = store.stockMovementsForItem(item.id);

    String typeLabel(String type) {
      switch (type) {
        case 'in':
          return 'РџРѕСЃС‚СѓРїР»РµРЅРёРµ';
        case 'out':
          return 'Р Р°СЃС…РѕРґ';
        case 'writeoff':
          return 'РЎРїРёСЃР°РЅРёРµ';
        case 'adjust':
          return 'РљРѕСЂСЂРµРєС‚РёСЂРѕРІРєР°';
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
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'РћСЃС‚Р°С‚РѕРє: ${item.stockQty.toStringAsFixed(item.stockQty % 1 == 0 ? 0 : 2)} ${item.unit}',
                  style: TextStyle(color: colors.secondaryLabel),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: movements.isEmpty
                      ? EmptyState(
                          title: 'РќРµС‚ РґРІРёР¶РµРЅРёР№',
                          message: 'РСЃС‚РѕСЂРёСЏ РїРѕСЃС‚СѓРїР»РµРЅРёР№ Рё СЃРїРёСЃР°РЅРёР№ РїРѕСЏРІРёС‚СЃСЏ Р·РґРµСЃСЊ.',
                        )
                      : ListView(
                          children: movements.map((movement) {
                            final delta = movement.qty < 0
                                ? movement.qty
                                : (movement.type == 'out' ||
                                      movement.type == 'writeoff' ||
                                      movement.type == 'sale')
                                ? -movement.qty
                                : movement.qty;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            typeLabel(movement.type),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: delta >= 0
                                                  ? colors.green
                                                  : colors.red,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(delta.abs() % 1 == 0 ? 0 : 2)} ${item.unit}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: delta >= 0
                                                ? colors.green
                                                : colors.red,
                                          ),
                                        ),
                                      ],
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
                                    if ((movement.note ?? '')
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'РџСЂРёС‡РёРЅР°: ${movement.note}',
                                        style: TextStyle(
                                          color: colors.secondaryLabel,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'Р—Р°РєСЂС‹С‚СЊ',
                  icon: CupertinoIcons.xmark,
                  onPressed: () => Navigator.of(modalContext).pop(),
                ),
              ],
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
        middle: const Text('Р В Р Р‹Р В РЎвЂќР В Р’В»Р В Р’В°Р В РўвЂ'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _newItem,
              child: const Icon(
                CupertinoIcons.plus,
                semanticLabel: 'Р В РІР‚СњР В РЎвЂўР В Р’В±Р В Р’В°Р В Р вЂ Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰',
              ),
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
                    'Р В РЎСџР В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР В РЎвЂ Р В РЎвЂ Р В Р’В·Р В Р’В°Р В РЎвЂќР РЋРЎвЂњР В РЎвЂ”Р В РЎвЂќР В РЎвЂ (${store.suppliers.length})',
                  ),
                  PrimaryButton(
                    label: 'Р В РЎСљР В РЎвЂўР В Р вЂ Р РЋРІР‚в„–Р В РІвЂћвЂ“ Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќ',
                    icon: CupertinoIcons.person_badge_plus,
                    onPressed: _newSupplier,
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Р В РІР‚вЂќР В Р’В°Р В РЎвЂ”Р В РЎвЂР РЋР С“Р В Р’В°Р РЋРІР‚С™Р РЋР Р‰ Р В Р’В·Р В Р’В°Р В РЎвЂќР РЋРЎвЂњР В РЎвЂ”Р В РЎвЂќР РЋРЎвЂњ',
                    icon: CupertinoIcons.doc_on_clipboard,
                    onPressed: _recordPurchase,
                  ),
                  const SizedBox(height: 8),
                  if (store.suppliers.isEmpty)
                    EmptyState(
                      title: 'Р В РЎСљР В Р’ВµР РЋРІР‚С™ Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР В РЎвЂўР В Р вЂ ',
                      message: 'Р В РІР‚СњР В РЎвЂўР В Р’В±Р В Р’В°Р В Р вЂ Р РЋР Р‰Р РЋРІР‚С™Р В Р’Вµ Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р вЂ Р РЋРІР‚В°Р В РЎвЂР В РЎвЂќР В Р’В°, Р РЋРІР‚РЋР РЋРІР‚С™Р В РЎвЂўР В Р’В±Р РЋРІР‚в„– Р РЋРЎвЂњР РЋРІР‚РЋР В РЎвЂР РЋРІР‚С™Р РЋРІР‚в„–Р В Р вЂ Р В Р’В°Р РЋРІР‚С™Р РЋР Р‰ Р В Р’В·Р В Р’В°Р В РЎвЂќР РЋРЎвЂњР В РЎвЂ”Р В РЎвЂќР В РЎвЂ Р В РЎвЂ Р В РўвЂР В РЎвЂўР В Р’В»Р В РЎвЂ“Р В РЎвЂ.',
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
                                    'Р В РІР‚СњР В РЎвЂўР В Р’В»Р В РЎвЂ“: ${_money(store.supplierDebtCents(supplier.id))}',
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
                                      semanticLabel: 'Р В РЎвЂєР В РЎвЂ”Р В Р’В»Р В Р’В°Р РЋРІР‚С™Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰',
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _deleteSupplier(supplier),
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      size: 16,
                                      color: colors.tertiaryLabel,
                                      semanticLabel: 'Р В Р в‚¬Р В РўвЂР В Р’В°Р В Р’В»Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰',
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
                    SectionLabel(
                      'Р В РЎСљР В РЎвЂР В Р’В·Р В РЎвЂќР В РЎвЂР В РІвЂћвЂ“ Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р РЋРІР‚С™Р В РЎвЂўР В РЎвЂќ (${low.length})',
                    ),
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
                                      '${i.stockQty.toStringAsFixed(i.stockQty % 1 == 0 ? 0 : 2)} ${i.unit} (Р В РЎВР В РЎвЂР В Р вЂ¦ ${i.minQty})',
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
                    label: 'Р В Р’ВР В РЎВР В РЎвЂ”Р В РЎвЂўР РЋР вЂљР РЋРІР‚С™ Р В РЎвЂР В Р’В· Excel',
                    icon: CupertinoIcons.doc_on_doc,
                    onPressed: _importInventoryExcel,
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _searchController,
                    placeholder: 'Р В РЎСџР В РЎвЂўР В РЎвЂР РЋР С“Р В РЎвЂќ Р В РЎвЂ”Р В РЎвЂў Р РЋР С“Р В РЎвЂќР В Р’В»Р В Р’В°Р В РўвЂР РЋРЎвЂњ',
                    onChanged: (v) => setState(() => _invQuery = v),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: _invFilter == 'all'
                        ? 'Р В Р’В¤Р В РЎвЂР В Р’В»Р РЋР Р‰Р РЋРІР‚С™Р РЋР вЂљ: Р В Р вЂ Р РЋР С“Р В Р’Вµ'
                        : (_invFilter == 'good'
                              ? 'Р В РЎС›Р В РЎвЂўР В Р вЂ Р В Р’В°Р РЋР вЂљР РЋРІР‚в„–'
                              : (_invFilter == 'service'
                                    ? 'Р В Р в‚¬Р РЋР С“Р В Р’В»Р РЋРЎвЂњР В РЎвЂ“Р В РЎвЂ'
                                    : 'Р В РЎС™Р В Р’В°Р В Р’В»Р В РЎвЂў')),
                    icon: CupertinoIcons.line_horizontal_3_decrease,
                    onPressed: _pickInventoryFilter,
                  ),
                  const SizedBox(height: 8),
                  SectionLabel(
                    'Р В РЎСџР В РЎвЂўР В Р’В·Р В РЎвЂР РЋРІР‚В Р В РЎвЂР В РЎвЂ (${_filteredInventory(store).length})',
                  ),
                  store.inventoryItems.isEmpty
                      ? EmptyState(
                          title: 'Р В РЎСљР В Р’ВµР РЋРІР‚С™ Р В РЎвЂ”Р В РЎвЂўР В Р’В·Р В РЎвЂР РЋРІР‚В Р В РЎвЂР В РІвЂћвЂ“',
                          message: 'Р В РІР‚СњР В РЎвЂўР В Р’В±Р В Р’В°Р В Р вЂ Р РЋР Р‰Р РЋРІР‚С™Р В Р’Вµ Р РЋРІР‚С™Р В РЎвЂўР В Р вЂ Р В Р’В°Р РЋР вЂљ Р В РЎвЂР В Р’В»Р В РЎвЂ Р РЋРЎвЂњР РЋР С“Р В Р’В»Р РЋРЎвЂњР В РЎвЂ“Р РЋРЎвЂњ.',
                          art: Icon(
                            CupertinoIcons.cube,
                            size: 48,
                            color: colors.tertiaryLabel,
                          ),
                          actions: [
                            PrimaryButton(
                              label: 'Р В РІР‚СњР В РЎвЂўР В Р’В±Р В Р’В°Р В Р вЂ Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰ Р В РЎвЂ”Р В РЎвЂўР В Р’В·Р В РЎвЂР РЋРІР‚В Р В РЎвЂР РЋР вЂ№',
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
                                            '${item.kind == 'service' ? 'Р В Р в‚¬Р РЋР С“Р В Р’В»Р РЋРЎвЂњР В РЎвЂ“Р В Р’В°' : 'Р В РЎС›Р В РЎвЂўР В Р вЂ Р В Р’В°Р РЋР вЂљ'} Р Р†Р вЂљРЎС› ${item.unit} Р Р†Р вЂљРЎС› Р В РЎвЂ”Р РЋР вЂљР В РЎвЂўР В РўвЂР В Р’В°Р В Р’В¶Р В Р’В° ${(item.sellPriceCents / 100).toStringAsFixed(0)} Р Р†РІР‚С™Р вЂ¦',
                                            style: TextStyle(
                                              color: colors.secondaryLabel,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (item.trackStock)
                                            Text(
                                              'Р В РЎвЂєР РЋР С“Р РЋРІР‚С™Р В Р’В°Р РЋРІР‚С™Р В РЎвЂўР В РЎвЂќ: ${item.stockQty.toStringAsFixed(item.stockQty % 1 == 0 ? 0 : 2)} ${item.unit}${item.lowStock ? ' (Р В РЎВР В Р’В°Р В Р’В»Р В РЎвЂў)' : ''}',
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
                                              'Р В РЎвЂєР РЋРІР‚С™Р РЋР вЂљР В РЎвЂР РЋРІР‚В Р В Р’В°Р РЋРІР‚С™Р В Р’ВµР В Р’В»Р РЋР Р‰Р В Р вЂ¦Р РЋРІР‚в„–Р В РІвЂћвЂ“ Р В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р РЋРІР‚С™Р В РЎвЂўР В РЎвЂќ',
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
                                          semanticLabel: 'Р В РЎСџР РЋР вЂљР В РЎвЂР РЋРІР‚ВР В РЎВ',
                                        ),
                                      ),
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _writeOff(item),
                                        child: const Icon(
                                          CupertinoIcons.minus_circle,
                                          size: 20,
                                          semanticLabel: 'Р В Р Р‹Р В РЎвЂ”Р В РЎвЂР РЋР С“Р В Р’В°Р В Р вЂ¦Р В РЎвЂР В Р’Вµ',
                                        ),
                                      ),
                                    ],
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showItemHistory(item),
                                      child: const Text(
                                        'Р В Р’ВР РЋР С“Р РЋРІР‚С™Р В РЎвЂўР РЋР вЂљР В РЎвЂР РЋР РЏ',
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
                                        semanticLabel: 'Р В Р в‚¬Р В РўвЂР В Р’В°Р В Р’В»Р В РЎвЂР РЋРІР‚С™Р РЋР Р‰',
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
