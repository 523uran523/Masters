import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../employees/employees_screen.dart';
import '../stats/stats_screen.dart';
import '../../data/models/money_transaction.dart';
import '../../data/models/recurring_payment.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  bool _busy = false;
  final _txSearchController = TextEditingController();
  String _directionFilter = 'all';
  String? _accountFilter;
  String _txQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _recurringStatusFilter = 'all';

  String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} в‚Ѕ';

  Future<String?> _pickAccount() async {
    final store = context.read<MastersStore>();
    final accounts = store.accounts.where((a) => !a.archived).toList();
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: context.colors.card,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('РћС‚РјРµРЅР°'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final a in accounts)
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(a.id),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(a.name),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool from) async {
    DateTime selected = from
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: context.colors.card,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('РћС‚РјРµРЅР°'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                CupertinoButton(
                  child: const Text('Р“РѕС‚РѕРІРѕ'),
                  onPressed: () {
                    final picked = DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                    );
                    Navigator.of(ctx).pop();
                    setState(() {
                      if (from) {
                        _dateFrom = picked;
                      } else {
                        _dateTo = picked;
                      }
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selected,
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDateFilter() async {
    final action = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('РџРµСЂРёРѕРґ'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('from'),
            child: const Text('РЎ РґР°С‚С‹'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('to'),
            child: const Text('РџРѕ РґР°С‚Сѓ'),
          ),
          if (_dateFrom != null || _dateTo != null)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop('clear'),
              child: const Text('РћС‡РёСЃС‚РёС‚СЊ'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('all'),
            child: const Text('Р’СЃРµ'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('РћС‚РјРµРЅР°'),
        ),
      ),
    );
    if (action == 'from') {
      await _pickDate(true);
    } else if (action == 'to') {
      await _pickDate(false);
    } else if (action == 'clear' || action == 'all') {
      setState(() {
        _dateFrom = null;
        _dateTo = null;
      });
    }
  }

  String _formatDate() {
    final f = DateFormat('d MMM yyyy', 'ru');
    if (_dateFrom != null && _dateTo != null) {
      return '${f.format(_dateFrom!)} вЂ” ${f.format(_dateTo!)}';
    }
    if (_dateFrom != null) {
      return 'РЎ ${f.format(_dateFrom!)}';
    }
    if (_dateTo != null) {
      return 'РџРѕ ${f.format(_dateTo!)}';
    }
    return 'РџРµСЂРёРѕРґ: РІСЃРµ';
  }

  Future<void> _quickSale() async => _quickTransactionSheet(isIncome: true);

  Future<void> _addExpense() async => _quickTransactionSheet(isIncome: false);

  Future<void> _quickTransactionSheet({required bool isIncome}) async {
    final store = context.read<MastersStore>();
    if (store.accounts.isEmpty) {
      await showAppAlert(
        context,
        title: 'РќРµС‚ СЃС‡С‘С‚Р°',
        message: 'РЎРЅР°С‡Р°Р»Р° СЃРѕР·РґР°Р№С‚Рµ СЃС‡С‘С‚ РІ СЂР°Р·РґРµР»Рµ Р”РµРЅСЊРіРё.',
      );
      return;
    }
    final accountId = await _pickAccount();
    if (accountId == null || !mounted) return;
    final amountController = TextEditingController();
    final categoryController = TextEditingController(
      text: isIncome ? 'РџСЂРѕРґР°Р¶Р°' : 'Р Р°СЃС…РѕРґ',
    );
    final noteController = TextEditingController();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        color: context.colors.card,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isIncome
                    ? 'Р‘С‹СЃС‚СЂР°СЏ РїСЂРѕРґР°Р¶Р°'
                    : 'Р‘С‹СЃС‚СЂС‹Р№ СЂР°СЃС…РѕРґ',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: amountController,
                placeholder: 'РЎСѓРјРјР° 0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x00FFFFFF),
                  border: Border.all(color: context.colors.separator),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: categoryController,
                placeholder: 'РљР°С‚РµРіРѕСЂРёСЏ',
                decoration: BoxDecoration(
                  color: const Color(0x00FFFFFF),
                  border: Border.all(color: context.colors.separator),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: noteController,
                placeholder: 'РљРѕРјРјРµРЅС‚Р°СЂРёР№',
                maxLines: 2,
                decoration: BoxDecoration(
                  color: const Color(0x00FFFFFF),
                  border: Border.all(color: context.colors.separator),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                label: isIncome
                    ? 'РџСЂРѕРІРµСЃС‚Рё РїСЂРёС…РѕРґ'
                    : 'РџСЂРѕРІРµСЃС‚Рё СЂР°СЃС…РѕРґ',
                icon: isIncome ? CupertinoIcons.plus : CupertinoIcons.minus,
                onPressed: () async {
                  final amount =
                      ((double.tryParse(
                                    amountController.text.trim().replaceAll(
                                      ',',
                                      '.',
                                    ),
                                  ) ??
                                  0) *
                              100)
                          .round();
                  if (amount <= 0) return;
                  final category = categoryController.text.trim().isEmpty
                      ? (isIncome ? 'РџСЂРѕРґР°Р¶Р°' : 'Р Р°СЃС…РѕРґ')
                      : categoryController.text.trim();
                  final note = noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim();
                  await store.addTransaction(
                    accountId: accountId,
                    kind: isIncome ? 'sale' : 'expense',
                    direction: isIncome ? 'in' : 'out',
                    amountCents: amount,
                    category: category,
                    note: note,
                  );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _transferBetweenAccounts() async {
    final store = context.read<MastersStore>();
    final accounts = store.accounts.where((a) => !a.archived).toList();
    if (accounts.length < 2) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'РџРµСЂРµРІРѕРґ',
        message: 'РќСѓР¶РЅРѕ РјРёРЅРёРјСѓРј 2 СЃС‡С‘С‚Р°.',
      );
      return;
    }
    final amountStr = await _prompt('РЎСѓРјРјР° РїРµСЂРµРІРѕРґР°', '0');
    if (amountStr == null) return;
    final amount =
        ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;

    final fromId = await _pickAccountExcluding(null);
    if (fromId == null || !mounted) return;
    final toId = await _pickAccountExcluding(fromId);
    if (toId == null || !mounted) return;
    final note = await _prompt('РљРѕРјРјРµРЅС‚Р°СЂРёР№', '');

    setState(() => _busy = true);
    try {
      await store.transferBetweenAccounts(fromId, toId, amount, note: note);
    } catch (e) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'РћС€РёР±РєР°',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickAccountExcluding(String? excludedId) async {
    final store = context.read<MastersStore>();
    final accounts = store.accounts
        .where((a) => !a.archived && a.id != excludedId)
        .toList();
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: context.colors.card,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('РћС‚РјРµРЅР°'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final a in accounts)
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(a.id),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(a.name),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importTransactionsExcel() async {
    setState(() => _busy = true);
    try {
      final count = await context
          .read<MastersStore>()
          .importTransactionsFromExcel();
      if (!mounted) return;
      await showAppAlert(
        context,
        title: count > 0 ? 'РРјРїРѕСЂС‚ Р·Р°РІРµСЂС€С‘РЅ' : 'РРјРїРѕСЂС‚',
        message: count > 0
            ? 'Р”РѕР±Р°РІР»РµРЅРѕ С‚СЂР°РЅР·Р°РєС†РёР№: $count.'
            : 'РќРµ СѓРґР°Р»РѕСЃСЊ РґРѕР±Р°РІРёС‚СЊ Р·Р°РїРёСЃРё. РџСЂРѕРІРµСЂСЊС‚Рµ С€Р°Р±Р»РѕРЅ Excel (РєРѕР»РѕРЅРєР° amount РѕР±СЏР·Р°С‚РµР»СЊРЅР°).',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addRecurringPayment() async {
    final store = context.read<MastersStore>();
    if (store.accounts.isEmpty) {
      await showAppAlert(
        context,
        title: 'РќРµС‚ СЃС‡С‘С‚Р°',
        message: 'РЎРЅР°С‡Р°Р»Р° СЃРѕР·РґР°Р№С‚Рµ СЃС‡С‘С‚ РІ СЂР°Р·РґРµР»Рµ Р”РµРЅСЊРіРё.',
      );
      return;
    }
    final interval = await showCupertinoModalPopup<int>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('РљР°Рє С‡Р°СЃС‚Рѕ РїР»Р°С‚С‘Р¶'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(7),
            child: const Text('РљР°Р¶РґСѓСЋ РЅРµРґРµР»СЋ'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(14),
            child: const Text('Р Р°Р· РІ 2 РЅРµРґРµР»Рё'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(30),
            child: const Text('Р•Р¶РµРјРµСЃСЏС‡РЅРѕ'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(90),
            child: const Text('Р Р°Р· РІ РєРІР°СЂС‚Р°Р»'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(-1),
            child: const Text('РЎРІРѕР№ РёРЅС‚РµСЂРІР°Р»'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('РћС‚РјРµРЅР°'),
        ),
      ),
    );
    if (interval == null || !mounted) return;
    int step = interval == -1 ? 30 : interval;
    if (interval == -1) {
      final custom = await _prompt('РРЅС‚РµСЂРІР°Р», РґРЅРµР№', '30');
      final parsed = int.tryParse((custom ?? '').trim());
      if (parsed == null || parsed <= 0 || !mounted) return;
      step = parsed;
    }
    final direction = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('РўРёРї СЂРµРіСѓР»СЏСЂРЅРѕРіРѕ РїР»Р°С‚РµР¶Р°'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('in'),
            child: const Text('РџР»Р°РЅРѕРІС‹Р№ РїСЂРёС…РѕРґ'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('out'),
            child: const Text('РџР»Р°РЅРѕРІС‹Р№ СЂР°СЃС…РѕРґ'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('РћС‚РјРµРЅР°'),
        ),
      ),
    );
    if (direction == null || !mounted) return;
    final name = await _prompt(
      'РќР°Р·РІР°РЅРёРµ РїР»Р°С‚РµР¶Р°',
      'РђСЂРµРЅРґР°',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final amountStr = await _prompt('РЎСѓРјРјР°', '0');
    if (amountStr == null || !mounted) return;
    final amount =
        ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;
    final category =
        await _prompt('РљР°С‚РµРіРѕСЂРёСЏ', 'Р РµРіСѓР»СЏСЂРЅРѕ') ??
        'Р РµРіСѓР»СЏСЂРЅРѕ';
    final accountId = await _pickAccount();
    if (accountId == null || !mounted) return;
    final now = DateTime.now();
    await store.createRecurringPayment(
      name: name.trim(),
      direction: direction,
      amountCents: amount,
      category: category.trim(),
      accountId: accountId,
      intervalDays: step,
      nextDueAt: now.add(Duration(days: step)),
      note: null,
    );
  }

  Future<void> _editRecurringPayment(RecurringPayment payment) async {
    final store = context.read<MastersStore>();
    final nameController = TextEditingController(text: payment.name);
    final intervalController = TextEditingController(
      text: payment.intervalDays.toString(),
    );
    final amountController = TextEditingController(
      text: (payment.amountCents / 100).toStringAsFixed(2),
    );
    final categoryController = TextEditingController(text: payment.category);
    var active = payment.active;
    var nextDue = DateTime(
      payment.nextDueAt.year,
      payment.nextDueAt.month,
      payment.nextDueAt.day,
    );

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (builderContext, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          color: context.colors.card,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Редактирование регулярного платежа',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Название',
                  decoration: BoxDecoration(
                    color: const Color(0x00FFFFFF),
                    border: Border.all(color: context.colors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: intervalController,
                  placeholder: 'Интервал, дней',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x00FFFFFF),
                    border: Border.all(color: context.colors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: amountController,
                  placeholder: 'Сумма 0.00',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x00FFFFFF),
                    border: Border.all(color: context.colors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: categoryController,
                  placeholder: 'Категория',
                  decoration: BoxDecoration(
                    color: const Color(0x00FFFFFF),
                    border: Border.all(color: context.colors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Активен'),
                    CupertinoSwitch(
                      value: active,
                      onChanged: (v) => setModalState(() => active = v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Следующий платёж: '
                      '${nextDue.day.toString().padLeft(2, '0')}'
                      '.${nextDue.month.toString().padLeft(2, '0')}'
                      '.${nextDue.year}',
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        DateTime selected = nextDue;
                        await showCupertinoModalPopup<void>(
                          context: context,
                          builder: (pickerContext) => Container(
                            height: 300,
                            color: context.colors.card,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    CupertinoButton(
                                      child: const Text('Отмена'),
                                      onPressed: () =>
                                          Navigator.of(pickerContext).pop(),
                                    ),
                                    CupertinoButton(
                                      child: const Text('Готово'),
                                      onPressed: () {
                                        final picked = DateTime(
                                          selected.year,
                                          selected.month,
                                          selected.day,
                                        );
                                        Navigator.of(pickerContext).pop();
                                        setModalState(() => nextDue = picked);
                                      },
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: CupertinoDatePicker(
                                    mode: CupertinoDatePickerMode.date,
                                    initialDateTime: selected,
                                    onDateTimeChanged: (dt) => selected = dt,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: const Text('Выбрать дату'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SecondaryButton(
                  label: 'Сохранить',
                  icon: CupertinoIcons.checkmark,
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final interval =
                        int.tryParse(intervalController.text.trim()) ?? 0;
                    if (interval <= 0) return;
                    final amount =
                        ((double.tryParse(
                                      amountController.text.trim().replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    ) ??
                                    0) *
                                100)
                            .round();
                    if (amount <= 0) return;
                    final category = categoryController.text.trim();
                    await store.updateRecurringPayment(
                      payment.copyWith(
                        name: name,
                        intervalDays: interval,
                        amountCents: amount,
                        category: category,
                        active: active,
                        nextDueAt: DateTime(
                          nextDue.year,
                          nextDue.month,
                          nextDue.day,
                        ),
                      ),
                    );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runDueRecurring() async {
    final store = context.read<MastersStore>();
    setState(() => _busy = true);
    try {
      final count = await store.runDueRecurringPayments();
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Р“РѕС‚РѕРІРѕ',
          message:
              'РџСЂРѕРІРµРґРµРЅРѕ РїР»Р°РЅРѕРІС‹С… РїР»Р°С‚РµР¶РµР№: $count',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newAccount() async {
    final name = await _prompt('РќР°Р·РІР°РЅРёРµ СЃС‡С‘С‚Р°', 'РљР°СЂС‚Р°');
    if (name == null || name.trim().isEmpty) return;
    final type = await _pickType();
    if (type == null) return;
    if (!mounted) return;
    await context.read<MastersStore>().createAccount(
      name: name.trim(),
      type: type,
    );
  }

  List<Widget> _teamCards(MastersStore store, AppColors colors) {
    if (store.employees.isEmpty) {
      return [
        EmptyState(
          title: 'РќРµС‚ СЃРѕС‚СЂСѓРґРЅРёРєРѕРІ',
          message: 'Р”РѕР±Р°РІСЊС‚Рµ СЃРѕС‚СЂСѓРґРЅРёРєР°, С‡С‚РѕР±С‹ РІРёРґРµС‚СЊ РЅР°С‡РёСЃР»РµРЅРёСЏ Рё РІС‹РїР»Р°С‚С‹.',
          art: Icon(
            CupertinoIcons.person_2,
            size: 36,
            color: colors.tertiaryLabel,
          ),
        ),
      ];
    }
    final maxEarned = store.employees
        .map((e) => store.earnedCents(e.id))
        .fold<int>(1, (a, b) => b > a ? b : a)
        .clamp(1, 1 << 30);
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in store.employees) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _money(store.earnedCents(e.id)),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'РќР°С‡РёСЃР»РµРЅРѕ',
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Рљ РІС‹РїР»Р°С‚Рµ ${_money(store.employeeBalanceOwed(e.id))}',
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final earned = store.earnedCents(e.id);
                  final factor = earned <= 0 ? 0.0 : earned / maxEarned;
                  final paid = store
                      .paymentsForEmployee(e.id)
                      .where(
                        (p) =>
                            p.type == 'advance' ||
                            p.type == 'payout' ||
                            p.type == 'bonus',
                      )
                      .fold<int>(0, (s, p) => s + p.amountCents);
                  final paidFactor = earned <= 0 ? 0.0 : paid / earned;
                  return SizedBox(
                    height: 8,
                    width: constraints.maxWidth,
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colors.tertiaryLabel.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: constraints.maxWidth * factor.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (paidFactor > 0)
                          Container(
                            height: 8,
                            width:
                                (constraints.maxWidth *
                                    factor.clamp(0.0, 1.0)) *
                                paidFactor.clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ];
  }

  Future<String?> _pickType() async {
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 220,
        color: context.colors.card,
        child: Column(
          children: [
            CupertinoButton(
              child: const Text('РќР°Р»РёС‡РЅС‹Рµ'),
              onPressed: () => Navigator.of(ctx).pop('cash'),
            ),
            CupertinoButton(
              child: const Text('РљР°СЂС‚Р°'),
              onPressed: () => Navigator.of(ctx).pop('card'),
            ),
            CupertinoButton(
              child: const Text('Р‘Р°РЅРє'),
              onPressed: () => Navigator.of(ctx).pop('bank'),
            ),
            CupertinoButton(
              child: const Text('РљРѕС€РµР»С‘Рє'),
              onPressed: () => Navigator.of(ctx).pop('wallet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openShift() async {
    final store = context.read<MastersStore>();
    if (store.openShift() != null) {
      await showAppAlert(
        context,
        title: 'РЎРјРµРЅР° СѓР¶Рµ РѕС‚РєСЂС‹С‚Р°',
        message: 'РЎРЅР°С‡Р°Р»Р° Р·Р°РєСЂРѕР№С‚Рµ С‚РµРєСѓС‰СѓСЋ СЃРјРµРЅСѓ.',
      );
      return;
    }
    final accountId = await _pickAccount();
    if (accountId == null) return;
    final openingStr = await _prompt(
      'РќР°С‡Р°Р»СЊРЅР°СЏ СЃСѓРјРјР° РІ РєР°СЃСЃРµ',
      '0',
    );
    final opening =
        ((double.tryParse((openingStr ?? '0').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    await store.openCashShift(accountId: accountId, openingCents: opening);
  }

  Future<void> _closeShift() async {
    final store = context.read<MastersStore>();
    final shift = store.openShift();
    if (shift == null) {
      await showAppAlert(
        context,
        title: 'РќРµС‚ РѕС‚РєСЂС‹С‚РѕР№ СЃРјРµРЅС‹',
        message: 'РћС‚РєСЂРѕР№С‚Рµ СЃРјРµРЅСѓ РґР»СЏ СѓС‡С‘С‚Р°.',
      );
      return;
    }
    final closingStr = await _prompt(
      'Р¤Р°РєС‚РёС‡РµСЃРєР°СЏ СЃСѓРјРјР° РїСЂРё Р·Р°РєСЂС‹С‚РёРё',
      '0',
    );
    final closing =
        ((double.tryParse((closingStr ?? '0').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    final expected = store.expectedForShift(shift);
    final disc = closing - expected;
    if (!mounted) return;
    final ok = await showAppConfirm(
      context,
      title: 'Р—Р°РєСЂС‹С‚СЊ СЃРјРµРЅСѓ?',
      message:
          'РћР¶РёРґР°РµС‚СЃСЏ: ${_money(expected)}. Р¤Р°РєС‚: ${_money(closing)}. Р Р°СЃС…РѕР¶РґРµРЅРёРµ: ${_money(disc)}.',
      confirmLabel: 'Р—Р°РєСЂС‹С‚СЊ',
    );
    if (!ok) return;
    await store.closeCashShift(shift, closing);
  }

  Future<String?> _prompt(String title, String placeholder) async {
    final controller = TextEditingController();
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
            child: const Text('РћС‚РјРµРЅР°'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dc).pop(controller.text.trim()),
            child: const Text('РћРљ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTxSearch() async {
    _txSearchController.text = _txQuery;
    if (!mounted) return;
    final result = await showCupertinoDialog<String?>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Поиск'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _txSearchController,
            placeholder: 'Поиск по категории/комментарию',
            autofocus: true,
            onSubmitted: (_) =>
                Navigator.of(dialogContext)
                    .pop(_txSearchController.text.trim()),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(_txSearchController.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _txQuery = result);
  }

  @override
  void dispose() {
    _txSearchController.dispose();
    super.dispose();
  }

  Future<void> _showTransactionDetail(MoneyTransaction t) async {
    final store = context.read<MastersStore>();
    MoneyTransaction current = t;
    final acc = store.accountById(t.accountId);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) => StatefulBuilder(
        builder: (sbContext, setModalState) {
          final currentAcc = store.accountById(current.accountId) ?? acc;
          bool isImage(String path) {
            final lower = path.toLowerCase();
            return lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.png') ||
                lower.endsWith('.gif') ||
                lower.endsWith('.webp') ||
                lower.endsWith('.heic');
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.72,
            color: context.colors.card,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    current.category.isEmpty ? current.kind : current.category,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KV('РЎС‡С‘С‚', currentAcc?.name ?? 'вЂ”'),
                  _KV(
                    'РЎСѓРјРјР°',
                    '${current.direction == 'in' ? '+' : '-'}${_money(current.amountCents)}',
                  ),
                  _KV('РўРёРї', current.kind),
                  _KV(
                    'Р”Р°С‚Р°',
                    DateFormat(
                      'd MMM yyyy, HH:mm',
                      'ru',
                    ).format(current.createdAt),
                  ),
                  if (current.note != null && current.note!.isNotEmpty)
                    _KV('РљРѕРјРјРµРЅС‚Р°СЂРёР№', current.note!),
                  const SizedBox(height: 12),
                  if (current.receiptPath != null &&
                      current.receiptPath!.isNotEmpty) ...[
                    if (isImage(current.receiptPath!))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(current.receiptPath!),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'РћС‚РєСЂС‹С‚СЊ С‡РµРє',
                            icon: CupertinoIcons.doc,
                            onPressed: () async {
                              await OpenFilex.open(current.receiptPath!);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SecondaryButton(
                            label: 'РЈРґР°Р»РёС‚СЊ С‡РµРє',
                            icon: CupertinoIcons.trash,
                            onPressed: () async {
                              final ok = await showAppConfirm(
                                context,
                                title: 'РЈРґР°Р»РёС‚СЊ С‡РµРє?',
                                message: 'Р¤Р°Р№Р» РѕСЃС‚Р°РЅРµС‚СЃСЏ РЅР° СѓСЃС‚СЂРѕР№СЃС‚РІРµ.',
                                destructive: true,
                                confirmLabel: 'РЈРґР°Р»РёС‚СЊ',
                              );
                              if (!ok || !mounted) return;
                              await store.removeReceipt(current.id);
                              final updated = store.moneyTransactions
                                  .firstWhere(
                                    (x) => x.id == current.id,
                                    orElse: () => current,
                                  );
                              setModalState(() => current = updated);
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else
                    SecondaryButton(
                      label: 'РџСЂРёРєСЂРµРїРёС‚СЊ С‡РµРє',
                      icon: CupertinoIcons.paperclip,
                      onPressed: () async {
                        final files = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const [
                            'jpg',
                            'jpeg',
                            'png',
                            'gif',
                            'webp',
                            'heic',
                            'pdf',
                          ],
                        );
                        if (files.isEmpty) return;
                        final selectedPath = files.single.path;
                        if (selectedPath == null) return;
                        await store.attachReceipt(current.id, selectedPath);
                        final updated = store.moneyTransactions.firstWhere(
                          (x) => x.id == current.id,
                          orElse: () => current,
                        );
                        setModalState(() => current = updated);
                      },
                    ),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    label: 'РћС‚РјРµРЅРёС‚СЊ РѕРїРµСЂР°С†РёСЋ',
                    icon: CupertinoIcons.xmark,
                    onPressed: () async {
                      final ok = await showAppConfirm(
                        context,
                        title: 'РћС‚РјРµРЅРёС‚СЊ РѕРїРµСЂР°С†РёСЋ?',
                        message: 'РЎСѓРјРјР° РІРµСЂРЅС‘С‚СЃСЏ РІ РёСЃС‚РѕСЂРёСЋ РєР°Рє РѕС‚РјРµРЅС‘РЅРЅР°СЏ.',
                        destructive: true,
                        confirmLabel: 'РћС‚РјРµРЅРёС‚СЊ',
                      );
                      if (!ok || !mounted) return;
                      store.voidTransaction(current.id);
                      if (modalContext.mounted) {
                        Navigator.of(modalContext).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final settings = context.watch<SettingsController>();
    final colors = context.colors;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayTx = store.moneyTransactions
        .where((t) => !t.voided && t.createdAt.isAfter(todayStart))
        .toList();
    final todayIncome = todayTx
        .where((t) => t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
    final todayExpense = todayTx
        .where((t) => t.direction == 'out')
        .fold(0, (s, t) => s + t.amountCents);
    final monthStart = DateTime(now.year, now.month, 1);
    final monthTx = store.moneyTransactions
        .where((t) => !t.voided && !t.createdAt.isBefore(monthStart))
        .toList();
    final monthIncome = monthTx
        .where((t) => t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
    final taxRate = settings.taxRate;
    final taxAccountId = settings.taxAccountId;
    final reservedTax = taxRate <= 0
        ? 0
        : (monthIncome * taxRate / 100).round();
    final shift = store.openShift();

    final recurringFiltered = store.recurringPayments.where((p) {
      if (_recurringStatusFilter == 'active') return p.active;
      if (_recurringStatusFilter == 'disabled') return !p.active;
      return true;
    }).toList()..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    final recurringGroups = <DateTime, List<RecurringPayment>>{};
    for (final p in recurringFiltered) {
      final key = DateTime(p.nextDueAt.year, p.nextDueAt.month);
      recurringGroups.putIfAbsent(key, () => []).add(p);
    }
    final recurringMonthKeys = recurringGroups.keys.toList()..sort();

    // debts
    int totalDebt = 0;
    final debtClients = <Map<String, dynamic>>[];
    for (final c in store.clients) {
      final debt = store.clientDebtCents(c.id);
      if (debt > 0) {
        totalDebt += debt;
        debtClients.add({'client': c, 'debt': debt});
      }
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Р”РµРЅСЊРіРё'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _newAccount,
              child: const Icon(
                CupertinoIcons.plus,
                semanticLabel: 'Р”РѕР±Р°РІРёС‚СЊ',
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
                  SectionLabel('РЎРµРіРѕРґРЅСЏ'),
                  AppCard(
                    child: Column(
                      children: [
                        _KV('Р’С‹СЂСѓС‡РєР°', _money(todayIncome)),
                        _KV('Р Р°СЃС…РѕРґС‹', _money(todayExpense)),
                        _KV(
                          'РџСЂРёР±С‹Р»СЊ',
                          _money(todayIncome - todayExpense),
                        ),
                        _KV(
                          'Р’СЃРµРіРѕ РЅР° СЃС‡РµС‚Р°С…',
                          _money(store.totalBalanceCents()),
                        ),
                        _KV(
                          'РџСЂРѕРіРЅРѕР· РґРѕ РєРѕРЅС†Р° РјРµСЃСЏС†Р°',
                          _money(store.forecastCashToEndOfMonth()),
                        ),
                        if (taxRate > 0) ...[
                          _KV(
                            'РќР°Р»РѕРіРѕРІС‹Р№ СЂРµР·РµСЂРІ',
                            _money(reservedTax),
                          ),
                          _KV(
                            'РќР°Р»РѕРіРѕРІС‹Р№ СЂРµР·РµСЂРІ (РїСЂРѕРіРЅРѕР·)',
                            _money(store.forecastTaxReserveToEndOfMonth()),
                          ),
                          _KV(
                            'РЎРІРѕР±РѕРґРЅРѕ РїРѕСЃР»Рµ СЂРµР·РµСЂРІР°',
                            _money(monthIncome - reservedTax),
                          ),
                          if (taxAccountId != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Счёт кармана: ${store.accountById(taxAccountId)?.name ?? 'неизвестный счёт'}',
                                      style: TextStyle(
                                        color: colors.secondaryLabel,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Р‘С‹СЃС‚СЂР°СЏ РїСЂРѕРґР°Р¶Р°',
                          icon: CupertinoIcons.plus,
                          onPressed: _quickSale,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Р Р°СЃС…РѕРґ',
                          icon: CupertinoIcons.minus,
                          onPressed: _addExpense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'РџРµСЂРµРІРѕРґ РјРµР¶РґСѓ СЃС‡РµС‚Р°РјРё',
                    icon: CupertinoIcons.arrow_left_right,
                    onPressed: _transferBetweenAccounts,
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'РРјРїРѕСЂС‚ С‚СЂР°РЅР·Р°РєС†РёР№ (Excel)',
                    icon: CupertinoIcons.doc_on_doc,
                    onPressed: _importTransactionsExcel,
                  ),
                  const SizedBox(height: 16),
                  if (settings.cashShiftEnabled) ...[
                    SectionLabel('РЎРјРµРЅР° РєР°СЃСЃС‹'),
                    AppCard(
                      child: shift == null
                          ? SecondaryButton(
                              label: 'РћС‚РєСЂС‹С‚СЊ СЃРјРµРЅСѓ',
                              icon: CupertinoIcons.play,
                              onPressed: _openShift,
                            )
                          : Column(
                              children: [
                                _KV('РЎС‚Р°С‚СѓСЃ', 'РћС‚РєСЂС‹С‚Р°'),
                                _KV(
                                  'РќР°С‡Р°Р»Рѕ',
                                  DateFormat(
                                    'd MMM, HH:mm',
                                    'ru',
                                  ).format(shift.openedAt),
                                ),
                                _KV(
                                  'РћР¶РёРґР°РµС‚СЃСЏ',
                                  _money(store.expectedForShift(shift)),
                                ),
                                SecondaryButton(
                                  label: 'Р—Р°РєСЂС‹С‚СЊ СЃРјРµРЅСѓ',
                                  icon: CupertinoIcons.stop,
                                  onPressed: _closeShift,
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SectionLabel('РЎС‡РµС‚Р° (${store.accounts.length})'),
                  ...store.accounts.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    a.type,
                                    style: TextStyle(
                                      color: colors.secondaryLabel,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _money(store.balanceCents(a.id)),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  SectionLabel(
                    'Р РµРіСѓР»СЏСЂРЅС‹Рµ РїР»Р°С‚РµР¶Рё (${recurringFiltered.length})',
                  ),
                  const SizedBox(height: 6),
                  SecondaryButton(
                    label: _recurringStatusFilter == 'all'
                        ? '\u0421\u0442\u0430\u0442\u0443\u0441: \u0432\u0441\u0435'
                        : (_recurringStatusFilter == 'active'
                              ? '\u0421\u0442\u0430\u0442\u0443\u0441: \u0430\u043a\u0442\u0438\u0432\u043d\u044b\u0435'
                              : '\u0421\u0442\u0430\u0442\u0443\u0441: \u0432\u044b\u043a\u043b\u044e\u0447\u0435\u043d\u043d\u044b\u0435'),
                    icon: CupertinoIcons.line_horizontal_3_decrease,
                    onPressed: () async {
                      final v = await showCupertinoModalPopup<String>(
                        context: context,
                        builder: (dialogContext) => CupertinoActionSheet(
                          title: const Text(
                            '\u0421\u0442\u0430\u0442\u0443\u0441',
                          ),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop('all'),
                              child: const Text('\u0412\u0441\u0435'),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop('active'),
                              child: const Text(
                                '\u0410\u043a\u0442\u0438\u0432\u043d\u044b\u0435',
                              ),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop('disabled'),
                              child: const Text(
                                '\u0412\u044b\u043a\u043b\u044e\u0447\u0435\u043d\u043d\u044b\u0435',
                              ),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              '\u041e\u0442\u043c\u0435\u043d\u0430',
                            ),
                          ),
                        ),
                      );
                      if (v != null) {
                        setState(() => _recurringStatusFilter = v);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (recurringFiltered.isEmpty)
                    EmptyState(
                      title: 'РќРµС‚ СЂРµРіСѓР»СЏСЂРЅС‹С… РїР»Р°С‚РµР¶РµР№',
                      message: 'Р”РѕР±Р°РІСЊС‚Рµ СЂРµРіСѓР»СЏСЂРЅС‹Рµ СЂР°СЃС…РѕРґС‹ РёР»Рё РїРѕСЃС‚СѓРїР»РµРЅРёСЏ.',
                      art: Icon(
                        CupertinoIcons.repeat,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        children: [
                          for (
                            int gi = 0;
                            gi < recurringMonthKeys.length;
                            gi++
                          ) ...[
                            if (gi > 0) const SizedBox(height: 8),
                            Text(
                              DateFormat(
                                'MMMM yyyy',
                                'ru',
                              ).format(recurringMonthKeys[gi]),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: colors.secondaryLabel,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...recurringGroups[recurringMonthKeys[gi]]!.map(
                              (p) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${p.direction == "in" ? "+" : "-"} ${_money(p.amountCents)} \u00b7 \u043a\u0430\u0436\u0434\u044b\u0435 ${p.intervalDays} \u0434\u043d \u00b7 \u0434\u0430\u0442\u0430 ${p.nextDueAt.day}.${p.nextDueAt.month}.${p.nextDueAt.year}',
                                            style: TextStyle(
                                              color: colors.secondaryLabel,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CupertinoSwitch(
                                      value: p.active,
                                      onChanged: (v) =>
                                          store.updateRecurringPayment(
                                            p.copyWith(active: v),
                                          ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _editRecurringPayment(p),
                                      child: Icon(
                                        CupertinoIcons.pencil,
                                        size: 18,
                                        color: colors.accent,
                                        semanticLabel: '\u0420\u0435\u0434\u0430\u043a\u0442\u0438\u0440\u043e\u0432\u0430\u0442\u044c',
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          store.deleteRecurringPayment(p.id),
                                      child: Icon(
                                        CupertinoIcons.trash,
                                        size: 18,
                                        color: colors.red,
                                        semanticLabel: '\u0423\u0434\u0430\u043b\u0438\u0442\u044c',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Р”РѕР±Р°РІРёС‚СЊ СЂРµРіСѓР»СЏСЂРЅС‹Р№ РїР»Р°С‚С‘Р¶',
                    icon: CupertinoIcons.repeat,
                    onPressed: _addRecurringPayment,
                  ),
                  const SizedBox(height: 4),
                  SecondaryButton(
                    label: 'РџСЂРѕРІРµСЃС‚Рё РїР»Р°РЅРѕРІС‹Рµ',
                    icon: CupertinoIcons.play,
                    onPressed: _runDueRecurring,
                  ),
                  const SizedBox(height: 16),
                  SectionLabel('РљРѕРјР°РЅРґР°'),
                  ..._teamCards(store, colors),
                  const SizedBox(height: 16),
                  SectionLabel(
                    'Р”РѕР»РіРё РєР»РёРµРЅС‚РѕРІ (${_money(totalDebt)})',
                  ),
                  debtClients.isEmpty
                      ? EmptyState(
                          title: 'Р”РѕР»РіРѕРІ РЅРµС‚',
                          message: 'Р’СЃРµ СЂР°СЃС‡С‘С‚С‹ Р·Р°РєСЂС‹С‚С‹.',
                          art: Icon(
                            CupertinoIcons.checkmark_seal,
                            size: 36,
                            color: colors.tertiaryLabel,
                          ),
                        )
                      : AppCard(
                          child: Column(
                            children: debtClients.map((d) {
                              final c = d['client'];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _money(d['debt'] as int),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'РљРѕРјР°РЅРґР° Рё Р·Р°СЂРїР»Р°С‚Р°',
                    icon: CupertinoIcons.person_2,
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const EmployeesScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Р Р°СЃС€РёСЂРµРЅРЅР°СЏ Р°РЅР°Р»РёС‚РёРєР° (P&L)',
                    icon: CupertinoIcons.chart_bar,
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const StatsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_txQuery.isNotEmpty) ...[
                        Expanded(
                          child: Text(
                            'Поиск: $_txQuery',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.secondaryLabel,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() {
                            _txQuery = '';
                            _txSearchController.clear();
                          }),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            semanticLabel: 'Очистить',
                          ),
                        ),
                      ] else
                        const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _showTxSearch,
                        child: const Icon(
                          CupertinoIcons.search,
                          semanticLabel: 'Поиск',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: _directionFilter == 'all'
                              ? 'РќР°РїСЂР°РІР»РµРЅРёРµ: РІСЃРµ'
                              : (_directionFilter == 'in'
                                    ? 'РџСЂРёС…РѕРґС‹'
                                    : 'Р Р°СЃС…РѕРґС‹'),
                          icon: CupertinoIcons.line_horizontal_3_decrease,
                          onPressed: () async {
                            final v = await showCupertinoModalPopup<String>(
                              context: context,
                              builder: (dialogContext) => CupertinoActionSheet(
                                title: const Text('РќР°РїСЂР°РІР»РµРЅРёРµ'),
                                actions: [
                                  CupertinoActionSheetAction(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop('all'),
                                    child: const Text('Р’СЃРµ'),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop('in'),
                                    child: const Text('РџСЂРёС…РѕРґС‹'),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop('out'),
                                    child: const Text('Р Р°СЃС…РѕРґС‹'),
                                  ),
                                ],
                                cancelButton: CupertinoActionSheetAction(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('РћС‚РјРµРЅР°'),
                                ),
                              ),
                            );
                            if (v != null) setState(() => _directionFilter = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SecondaryButton(
                          label: _accountFilter == null
                              ? 'РЎС‡С‘С‚: РІСЃРµ'
                              : (store.accountById(_accountFilter!)?.name ??
                                    'РЎС‡С‘С‚'),
                          icon: CupertinoIcons.money_dollar,
                          onPressed: () async {
                            final v = await showCupertinoModalPopup<String?>(
                              context: context,
                              builder: (dialogContext) => Container(
                                height: 280,
                                color: context.colors.card,
                                child: Column(
                                  children: [
                                    CupertinoButton(
                                      child: const Text('Р’СЃРµ СЃС‡РµС‚Р°'),
                                      onPressed: () =>
                                          Navigator.of(dialogContext)
                                              .pop('__all__'),
                                    ),
                                    Expanded(
                                      child: ListView(
                                        children: [
                                          for (final a in store.accounts.where(
                                            (x) => !x.archived,
                                          ))
                                            CupertinoButton(
                                              onPressed: () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(a.id),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(a.name),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (v == '__all__') {
                              setState(() => _accountFilter = null);
                            } else if (v != null) {
                              setState(() => _accountFilter = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: _formatDate(),
                    icon: CupertinoIcons.calendar,
                    onPressed: _openDateFilter,
                  ),
                  const SizedBox(height: 16),
                  SectionLabel(
                    'Р–СѓСЂРЅР°Р» (${store.moneyTransactions.length})',
                  ),
                  store.moneyTransactions.isEmpty
                      ? EmptyState(
                          title: 'РќРµС‚ РѕРїРµСЂР°С†РёР№',
                          message: 'Р”РѕР±Р°РІСЊС‚Рµ РїСЂРѕРґР°Р¶Сѓ РёР»Рё СЂР°СЃС…РѕРґ.',
                          art: Icon(
                            CupertinoIcons.doc_text,
                            size: 36,
                            color: colors.tertiaryLabel,
                          ),
                        )
                      : Column(
                          children: store.moneyTransactions
                              .where((t) {
                                if (t.voided) return false;
                                if (_directionFilter != 'all' &&
                                    t.direction != _directionFilter) {
                                  return false;
                                }
                                if (_accountFilter != null &&
                                    t.accountId != _accountFilter) {
                                  return false;
                                }
                                if (_dateFrom != null &&
                                    t.createdAt.isBefore(_dateFrom!)) {
                                  return false;
                                }
                                if (_dateTo != null) {
                                  final endOfDay = DateTime(
                                    _dateTo!.year,
                                    _dateTo!.month,
                                    _dateTo!.day + 1,
                                  );
                                  if (t.createdAt.isAfter(endOfDay)) {
                                    return false;
                                  }
                                }
                                final q = _txQuery.trim().toLowerCase();
                                if (q.isNotEmpty) {
                                  final clientId = t.clientId;
                                  final jobId = t.jobId;
                                  final clientName = clientId == null
                                      ? ''
                                      : (store.clientById(clientId)?.name ??
                                            clientId);
                                  final accountName =
                                      store.accountById(t.accountId)?.name ??
                                      t.accountId;
                                  final jobTitle = jobId == null
                                      ? ''
                                      : (store.jobById(jobId)?.title ?? jobId);
                                  final haystack = [
                                    t.category,
                                    if (t.category.trim().isEmpty)
                                      'Р‘РµР· РєР°С‚РµРіРѕСЂРёРё',
                                    t.note ?? '',
                                    t.kind,
                                    clientName,
                                    accountName,
                                    jobTitle,
                                  ].join(' ').toLowerCase();
                                  if (!haystack.contains(q)) {
                                    return false;
                                  }
                                }
                                return true;
                              })
                              .take(50)
                              .map((t) {
                                final acc = store.accountById(t.accountId);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: AppCard(
                                    onTap: () => _showTransactionDetail(t),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.category.isEmpty
                                                    ? t.kind
                                                    : t.category,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                [
                                                  acc?.name ?? '',
                                                  if (t.note != null &&
                                                      t.note!.isNotEmpty)
                                                    t.note!,
                                                  DateFormat(
                                                    'd MMM, HH:mm',
                                                    'ru',
                                                  ).format(t.createdAt),
                                                ].join(' вЂў '),
                                                style: TextStyle(
                                                  color: colors.secondaryLabel,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${t.direction == 'in' ? '+' : '-'}${_money(t.amountCents)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: t.direction == 'in'
                                                ? colors.green
                                                : colors.red,
                                          ),
                                        ),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: () =>
                                              store.voidTransaction(t.id),
                                          child: Icon(
                                            CupertinoIcons.xmark,
                                            size: 14,
                                            color: colors.tertiaryLabel,
                                            semanticLabel: 'РћС‚РјРµРЅРёС‚СЊ',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
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
