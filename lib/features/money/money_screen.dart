import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../employees/employees_screen.dart';
import '../stats/stats_screen.dart';
import '../../state/masters_store.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  bool _busy = false;

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
                CupertinoButton(child: const Text('Отмена'), onPressed: () => Navigator.of(ctx).pop()),
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

  Future<void> _quickSale() async {
    final amountStr = await _prompt('Сумма продажи', '0');
    if (amountStr == null) return;
    final amount = ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;
    final accountId = await _pickAccount();
    if (accountId == null) return;
    final category = await _prompt('Категория', 'Продажа') ?? 'Продажа';
    final note = await _prompt('Заметка', '');
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().addTransaction(
        accountId: accountId,
        kind: 'sale',
        direction: 'in',
        amountCents: amount,
        category: category,
        note: note,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addExpense() async {
    final amountStr = await _prompt('Сумма расхода', '0');
    if (amountStr == null) return;
    final amount = ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;
    final accountId = await _pickAccount();
    if (accountId == null) return;
    final category = await _prompt('Категория', 'Расход') ?? 'Расход';
    final note = await _prompt('Заметка', '');
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().addTransaction(
        accountId: accountId,
        kind: 'expense',
        direction: 'out',
        amountCents: amount,
        category: category,
        note: note,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transferBetweenAccounts() async {
    final store = context.read<MastersStore>();
    final accounts = store.accounts.where((a) => !a.archived).toList();
    if (accounts.length < 2) {
      if (!mounted) return;
      await showAppAlert(context,
          title: 'Перевод', message: 'Нужно минимум 2 счёта.');
      return;
    }
    final amountStr = await _prompt('Сумма перевода', '0');
    if (amountStr == null) return;
    final amount = ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100).round();
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
                    onPressed: () => Navigator.of(ctx).pop()),
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
      final count = await context.read<MastersStore>().importTransactionsFromExcel();
      if (!mounted) return;
      await showAppAlert(
        context,
        title: count > 0 ? 'Импорт завершён' : 'Импорт',
        message: count > 0
            ? 'Добавлено транзакций: $count.'
            : 'Не удалось добавить записи. Проверьте шаблон Excel (колонка amount обязательна).',
      );
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
    await context.read<MastersStore>().createAccount(name: name.trim(), type: type);
  }

  List<Widget> _teamCards(MastersStore store, AppColors colors) {
    if (store.employees.isEmpty) {
      return [
        EmptyState(
          title: 'Нет сотрудников',
          message: 'Добавьте сотрудника, чтобы видеть начисления и выплаты.',
          art: Icon(CupertinoIcons.person_2, size: 36, color: colors.tertiaryLabel),
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
                  Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(_money(store.earnedCents(e.id)), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Начислено', style: TextStyle(color: colors.secondaryLabel, fontSize: 11)),
                  Text('К выплате ${_money(store.employeeBalanceOwed(e.id))}',
                      style: TextStyle(color: colors.secondaryLabel, fontSize: 11)),
                ],
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final earned = store.earnedCents(e.id);
                  final factor = earned <= 0 ? 0.0 : earned / maxEarned;
                  final paid = store.paymentsForEmployee(e.id).where((p) => p.type == 'advance' || p.type == 'payout' || p.type == 'bonus').fold<int>(0, (s, p) => s + p.amountCents);
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
                            color: colors.tertiaryLabel.withOpacity(0.18),
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
                            width: (constraints.maxWidth * factor.clamp(0.0, 1.0)) * paidFactor.clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              color: colors.accent.withOpacity(0.45),
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
            CupertinoButton(child: const Text('Наличные'), onPressed: () => Navigator.of(ctx).pop('cash')),
            CupertinoButton(child: const Text('Карта'), onPressed: () => Navigator.of(ctx).pop('card')),
            CupertinoButton(child: const Text('Банк'), onPressed: () => Navigator.of(ctx).pop('bank')),
            CupertinoButton(child: const Text('Кошелёк'), onPressed: () => Navigator.of(ctx).pop('wallet')),
          ],
        ),
      ),
    );
  }

  Future<void> _openShift() async {
    final store = context.read<MastersStore>();
    if (store.openShift() != null) {
      await showAppAlert(context, title: 'Смена уже открыта', message: 'Сначала закройте текущую смену.');
      return;
    }
    final accountId = await _pickAccount();
    if (accountId == null) return;
    final openingStr = await _prompt('Начальная сумма в кассе', '0');
    final opening = ((double.tryParse((openingStr ?? '0').replaceAll(',', '.')) ?? 0) * 100).round();
    await store.openCashShift(accountId: accountId, openingCents: opening);
  }

  Future<void> _closeShift() async {
    final store = context.read<MastersStore>();
    final shift = store.openShift();
    if (shift == null) {
      await showAppAlert(context, title: 'Нет открытой смены', message: 'Откройте смену для учёта.');
      return;
    }
    final closingStr = await _prompt('Фактическая сумма при закрытии', '0');
    final closing = ((double.tryParse((closingStr ?? '0').replaceAll(',', '.')) ?? 0) * 100).round();
    final expected = store.expectedForShift(shift);
    final disc = closing - expected;
    if (!mounted) return;
    final ok = await showAppConfirm(
      context,
      title: 'Закрыть смену?',
      message: 'Ожидается: ${_money(expected)}. Факт: ${_money(closing)}. Расхождение: ${_money(disc)}.',
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
          CupertinoDialogAction(onPressed: () => Navigator.of(dc).pop(), child: const Text('Отмена')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.of(dc).pop(controller.text.trim()), child: const Text('ОК')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayTx = store.moneyTransactions.where((t) => !t.voided && t.createdAt.isAfter(todayStart)).toList();
    final todayIncome = todayTx.where((t) => t.direction == 'in').fold(0, (s, t) => s + t.amountCents);
    final todayExpense = todayTx.where((t) => t.direction == 'out').fold(0, (s, t) => s + t.amountCents);
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
            CupertinoButton(padding: EdgeInsets.zero, onPressed: _newAccount, child: const Icon(CupertinoIcons.plus)),
          ],
        ),
      ),
      child: _busy
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  SectionLabel('Сегодня'),
                  AppCard(
                    child: Column(
                      children: [
                        _KV('Выручка', _money(todayIncome)),
                        _KV('Расходы', _money(todayExpense)),
                        _KV('Прибыль', _money(todayIncome - todayExpense)),
                        _KV('Всего на счетах', _money(store.totalBalanceCents())),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: SecondaryButton(label: 'Быстрая продажа', icon: CupertinoIcons.plus, onPressed: _quickSale)),
                      const SizedBox(width: 8),
                      Expanded(child: SecondaryButton(label: 'Расход', icon: CupertinoIcons.minus, onPressed: _addExpense)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(label: 'Перевод между счетами', icon: CupertinoIcons.arrow_left_right, onPressed: _transferBetweenAccounts),
                  const SizedBox(height: 8),
                  SecondaryButton(label: 'Импорт транзакций (Excel)', icon: CupertinoIcons.doc_on_doc, onPressed: _importTransactionsExcel),
                  const SizedBox(height: 16),
                  SectionLabel('Смена кассы'),
                  AppCard(
                    child: shift == null
                        ? SecondaryButton(label: 'Открыть смену', icon: CupertinoIcons.play, onPressed: _openShift)
                        : Column(
                            children: [
                              _KV('Статус', 'Открыта'),
                              _KV('Начало', DateFormat('d MMM, HH:mm', 'ru').format(shift.openedAt)),
                              _KV('Ожидается', _money(store.expectedForShift(shift))),
                              SecondaryButton(label: 'Закрыть смену', icon: CupertinoIcons.stop, onPressed: _closeShift),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  SectionLabel('Счета (${store.accounts.length})'),
                  ...store.accounts.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(a.type, style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text(_money(store.balanceCents(a.id)), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  SectionLabel('Команда'),
                  ..._teamCards(store, colors),
                  const SizedBox(height: 16),
                  SectionLabel('Долги клиентов (${_money(totalDebt)})'),
                  debtClients.isEmpty
                      ? EmptyState(
                          title: 'Долгов нет',
                          message: 'Все расчёты закрыты.',
                          art: Icon(CupertinoIcons.checkmark_seal, size: 36, color: colors.tertiaryLabel),
                        )
                      : AppCard(
                          child: Column(
                            children: debtClients.map((d) {
                              final c = d['client'];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    Text(_money(d['debt'] as int), style: const TextStyle(fontWeight: FontWeight.w600)),
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
                      CupertinoPageRoute(builder: (_) => const EmployeesScreen()),
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
                  SectionLabel('Журнал (${store.moneyTransactions.length})'),
                  store.moneyTransactions.isEmpty
                      ? EmptyState(
                          title: 'Нет операций',
                          message: 'Добавьте продажу или расход.',
                          art: Icon(CupertinoIcons.doc_text, size: 36, color: colors.tertiaryLabel),
                        )
                      : Column(
                          children: store.moneyTransactions.take(50).map((t) {
                            final acc = store.accountById(t.accountId);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(t.category.isEmpty ? t.kind : t.category,
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text(
                                            [
                                              acc?.name ?? '',
                                              if (t.note != null && t.note!.isNotEmpty) t.note!,
                                              DateFormat('d MMM, HH:mm', 'ru').format(t.createdAt),
                                            ].join(' • '),
                                            style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${t.direction == 'in' ? '+' : '-'}${_money(t.amountCents)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: t.direction == 'in' ? colors.green : colors.red,
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => store.voidTransaction(t.id),
                                      child: Icon(CupertinoIcons.xmark, size: 14, color: colors.tertiaryLabel),
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