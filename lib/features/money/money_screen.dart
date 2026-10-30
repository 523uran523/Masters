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

  String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} ₽';

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
                  child: const Text('Отмена'),
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
                  child: const Text('Отмена'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                CupertinoButton(
                  child: const Text('Готово'),
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
        title: const Text('Период'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('from'),
            child: const Text('С даты'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('to'),
            child: const Text('По дату'),
          ),
          if (_dateFrom != null || _dateTo != null)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop('clear'),
              child: const Text('Очистить'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('all'),
            child: const Text('Все'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена'),
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
      return '${f.format(_dateFrom!)} — ${f.format(_dateTo!)}';
    }
    if (_dateFrom != null) {
      return 'С ${f.format(_dateFrom!)}';
    }
    if (_dateTo != null) {
      return 'По ${f.format(_dateTo!)}';
    }
    return 'Период: все';
  }

  Future<void> _quickSale() async => _quickTransactionSheet(isIncome: true);

  Future<void> _addExpense() async => _quickTransactionSheet(isIncome: false);

  Future<void> _quickTransactionSheet({required bool isIncome}) async {
    final store = context.read<MastersStore>();
    if (store.accounts.isEmpty) {
      await showAppAlert(
        context,
        title: 'Нет счёта',
        message: 'Сначала создайте счёт в разделе Деньги.',
      );
      return;
    }
    final accountId = await _pickAccount();
    if (accountId == null || !mounted) return;
    final amountController = TextEditingController();
    final categoryController = TextEditingController(
      text: isIncome ? 'Продажа' : 'Расход',
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
                isIncome ? 'Быстрая продажа' : 'Быстрый расход',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: amountController,
                placeholder: 'Сумма 0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: categoryController,
                placeholder: 'Категория',
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: noteController,
                placeholder: 'Комментарий',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                label: isIncome ? 'Провести приход' : 'Провести расход',
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
                      ? (isIncome ? 'Продажа' : 'Расход')
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
        title: 'Перевод',
        message: 'Нужно минимум 2 счёта.',
      );
      return;
    }
    final amountStr = await _prompt('Сумма перевода', '0');
    if (amountStr == null) return;
    final amount =
        ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;

    final fromId = await _pickAccountExcluding(null);
    if (fromId == null || !mounted) return;
    final toId = await _pickAccountExcluding(fromId);
    if (toId == null || !mounted) return;
    final note = await _prompt('Комментарий', '');

    setState(() => _busy = true);
    try {
      await store.transferBetweenAccounts(fromId, toId, amount, note: note);
    } catch (e) {
      if (mounted) {
        await showAppAlert(context, title: 'Ошибка', message: e.toString());
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
                  child: const Text('Отмена'),
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
        title: count > 0 ? 'Импорт завершён' : 'Импорт',
        message: count > 0 ? 'Добавлено транзакций: $count.' : 'Не удалось добавить записи. Проверьте шаблон Excel (колонка amount обязательна).',
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
        title: 'Нет счёта',
        message: 'Сначала создайте счёт в разделе Деньги.',
      );
      return;
    }
    final interval = await showCupertinoModalPopup<int>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Как часто платёж'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(7),
            child: const Text('Каждую неделю'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(14),
            child: const Text('Раз в 2 недели'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(30),
            child: const Text('Ежемесячно'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(90),
            child: const Text('Раз в квартал'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(-1),
            child: const Text('Свой интервал'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (interval == null || !mounted) return;
    int step = interval == -1 ? 30 : interval;
    if (interval == -1) {
      final custom = await _prompt('Интервал, дней', '30');
      final parsed = int.tryParse((custom ?? '').trim());
      if (parsed == null || parsed <= 0 || !mounted) return;
      step = parsed;
    }
    final direction = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Тип регулярного платежа'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('in'),
            child: const Text('Плановый приход'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('out'),
            child: const Text('Плановый расход'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (direction == null || !mounted) return;
    final name = await _prompt('Название платежа', 'Аренда');
    if (name == null || name.trim().isEmpty || !mounted) return;
    final amountStr = await _prompt('Сумма', '0');
    if (amountStr == null || !mounted) return;
    final amount =
        ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;
    final category = await _prompt('Категория', 'Регулярно') ?? 'Регулярно';
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

  Future<void> _runDueRecurring() async {
    final store = context.read<MastersStore>();
    setState(() => _busy = true);
    try {
      final count = await store.runDueRecurringPayments();
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Готово',
          message: 'Проведено плановых платежей: $count',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newAccount() async {
    final name = await _prompt('Название счёта', 'Карта');
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
          title: 'Нет сотрудников',
          message: 'Добавьте сотрудника, чтобы видеть начисления и выплаты.',
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
                    'Начислено',
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'К выплате ${_money(store.employeeBalanceOwed(e.id))}',
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
              child: const Text('Наличные'),
              onPressed: () => Navigator.of(ctx).pop('cash'),
            ),
            CupertinoButton(
              child: const Text('Карта'),
              onPressed: () => Navigator.of(ctx).pop('card'),
            ),
            CupertinoButton(
              child: const Text('Банк'),
              onPressed: () => Navigator.of(ctx).pop('bank'),
            ),
            CupertinoButton(
              child: const Text('Кошелёк'),
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
        title: 'Смена уже открыта',
        message: 'Сначала закройте текущую смену.',
      );
      return;
    }
    final accountId = await _pickAccount();
    if (accountId == null) return;
    final openingStr = await _prompt('Начальная сумма в кассе', '0');
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
        title: 'Нет открытой смены',
        message: 'Откройте смену для учёта.',
      );
      return;
    }
    final closingStr = await _prompt('Фактическая сумма при закрытии', '0');
    final closing =
        ((double.tryParse((closingStr ?? '0').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    final expected = store.expectedForShift(shift);
    final disc = closing - expected;
    if (!mounted) return;
    final ok = await showAppConfirm(
      context,
      title: 'Закрыть смену?',
      message:
          'Ожидается: ${_money(expected)}. Факт: ${_money(closing)}. Расхождение: ${_money(disc)}.',
      confirmLabel: 'Закрыть',
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
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dc).pop(controller.text.trim()),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
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
                  _KV('Счёт', currentAcc?.name ?? '—'),
                  _KV(
                    'Сумма',
                    '${current.direction == 'in' ? '+' : '-'}${_money(current.amountCents)}',
                  ),
                  _KV('Тип', current.kind),
                  _KV(
                    'Дата',
                    DateFormat(
                      'd MMM yyyy, HH:mm',
                      'ru',
                    ).format(current.createdAt),
                  ),
                  if (current.note != null && current.note!.isNotEmpty)
                    _KV('Комментарий', current.note!),
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
                            label: 'Открыть чек',
                            icon: CupertinoIcons.doc,
                            onPressed: () async {
                              await OpenFilex.open(current.receiptPath!);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Удалить чек',
                            icon: CupertinoIcons.trash,
                            onPressed: () async {
                              final ok = await showAppConfirm(
                                context,
                                title: 'Удалить чек?',
                                message: 'Файл останется на устройстве.',
                                destructive: true,
                                confirmLabel: 'Удалить',
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
                      label: 'Прикрепить чек',
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
                    label: 'Отменить операцию',
                    icon: CupertinoIcons.xmark,
                    onPressed: () async {
                      final ok = await showAppConfirm(
                        context,
                        title: 'Отменить операцию?',
                        message: 'Сумма вернётся в историю как отменённая.',
                        destructive: true,
                        confirmLabel: 'Отменить',
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
    final taxRate = settings.taxRate;
    final shift = store.openShift();

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
        middle: const Text('Деньги'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _newAccount,
              child: const Icon(CupertinoIcons.plus, semanticLabel: 'Добавить'),
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
                  SectionLabel('Сегодня'),
                  AppCard(
                    child: Column(
                      children: [
                        _KV('Выручка', _money(todayIncome)),
                        _KV('Расходы', _money(todayExpense)),
                        _KV('Прибыль', _money(todayIncome - todayExpense)),
                        _KV(
                          'Всего на счетах',
                          _money(store.totalBalanceCents()),
                        ),
                        _KV(
                          'Прогноз до конца месяца',
                          _money(store.forecastCashToEndOfMonth()),
                        ),
                        if (taxRate > 0) ...[
                          _KV('Налоговый резерв', _money(store.forecastTaxReserveToEndOfMonth())),
                          _KV(
                            'Налоговый резерв (прогноз)',
                            _money(store.forecastTaxReserveToEndOfMonth()),
                          ),
                          _KV(
                            'Свободно после резерва',
                            _money(store.totalBalanceCents() - store.forecastTaxReserveToEndOfMonth()),
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
                          label: 'Быстрая продажа',
                          icon: CupertinoIcons.plus,
                          onPressed: _quickSale,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Расход',
                          icon: CupertinoIcons.minus,
                          onPressed: _addExpense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Перевод между счетами',
                    icon: CupertinoIcons.arrow_left_right,
                    onPressed: _transferBetweenAccounts,
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Импорт транзакций (Excel)',
                    icon: CupertinoIcons.doc_on_doc,
                    onPressed: _importTransactionsExcel,
                  ),
                  const SizedBox(height: 16),
                  SectionLabel('Смена кассы'),
                  AppCard(
                    child: shift == null
                        ? SecondaryButton(
                            label: 'Открыть смену',
                            icon: CupertinoIcons.play,
                            onPressed: _openShift,
                          )
                        : Column(
                            children: [
                              _KV('Статус', 'Открыта'),
                              _KV(
                                'Начало',
                                DateFormat(
                                  'd MMM, HH:mm',
                                  'ru',
                                ).format(shift.openedAt),
                              ),
                              _KV(
                                'Ожидается',
                                _money(store.expectedForShift(shift)),
                              ),
                              SecondaryButton(
                                label: 'Закрыть смену',
                                icon: CupertinoIcons.stop,
                                onPressed: _closeShift,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  SectionLabel('Счета (${store.accounts.length})'),
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
                    'Регулярные платежи (${store.recurringPayments.length})',
                  ),
                  if (store.recurringPayments.isEmpty)
                    EmptyState(
                      title: 'Нет регулярных платежей',
                      message: 'Добавьте регулярные расходы или поступления.',
                      art: Icon(
                        CupertinoIcons.repeat,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        children: store.recurringPayments.map((p) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
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
                                        '${p.direction == "in" ? "+" : "-"} ${_money(p.amountCents)} · каждые ${p.intervalDays} дн · дата ${p.nextDueAt.day}.${p.nextDueAt.month}.${p.nextDueAt.year}',
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
                                  onPressed: () =>
                                      store.deleteRecurringPayment(p.id),
                                  child: Icon(
                                    CupertinoIcons.trash,
                                    size: 18,
                                    color: colors.red,
                                    semanticLabel: 'Удалить',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Добавить регулярный платёж',
                    icon: CupertinoIcons.repeat,
                    onPressed: _addRecurringPayment,
                  ),
                  const SizedBox(height: 4),
                  SecondaryButton(
                    label: 'Провести плановые',
                    icon: CupertinoIcons.play,
                    onPressed: _runDueRecurring,
                  ),
                  const SizedBox(height: 16),
                  SectionLabel('Команда'),
                  ..._teamCards(store, colors),
                  const SizedBox(height: 16),
                  SectionLabel('Долги клиентов (${_money(totalDebt)})'),
                  debtClients.isEmpty
                      ? EmptyState(
                          title: 'Долгов нет',
                          message: 'Все расчёты закрыты.',
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
                    label: 'Команда и зарплата',
                    icon: CupertinoIcons.person_2,
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const EmployeesScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Расширенная аналитика (P&L)',
                    icon: CupertinoIcons.chart_bar,
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const StatsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _txSearchController,
                    placeholder: 'Поиск по категории/комментарию',
                    onChanged: (v) => setState(() => _txQuery = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: _directionFilter == 'all'
                              ? 'Направление: все'
                              : (_directionFilter == 'in'
                                    ? 'Приходы'
                                    : 'Расходы'),
                          icon: CupertinoIcons.line_horizontal_3_decrease,
                          onPressed: () async {
                            final v = await showCupertinoModalPopup<String>(
                              context: context,
                              builder: (dialogContext) => CupertinoActionSheet(
                                title: const Text('Направление'),
                                actions: [
                                  CupertinoActionSheetAction(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop('all'),
                                    child: const Text('Все'),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop('in'),
                                    child: const Text('Приходы'),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop('out'),
                                    child: const Text('Расходы'),
                                  ),
                                ],
                                cancelButton: CupertinoActionSheetAction(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('Отмена'),
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
                              ? 'Счёт: все'
                              : (store.accountById(_accountFilter!)?.name ??
                                    'Счёт'),
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
                                      child: const Text('Все счета'),
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
                  SectionLabel('Журнал (${store.moneyTransactions.length})'),
                  store.moneyTransactions.isEmpty
                      ? EmptyState(
                          title: 'Нет операций',
                          message: 'Добавьте продажу или расход.',
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
                                if (q.isNotEmpty &&
                                    !(t.category.toLowerCase().contains(q) ||
                                        (t.note ?? '').toLowerCase().contains(
                                          q,
                                        ))) {
                                  return false;
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
                                                ].join(' • '),
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
                                            semanticLabel: 'Отменить',
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
