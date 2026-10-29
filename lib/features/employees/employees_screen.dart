import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/document_service.dart';
import '../../data/models/employee.dart';
import '../../data/models/recurring_payment.dart';
import '../../state/masters_store.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool _busy = false;

  String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} ₽';

  Future<String?> _prompt(String title, String placeholder, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
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

  Future<void> _newEmployee() async {
    final name = await _prompt('Имя сотрудника', 'Иван');
    if (name == null || name.trim().isEmpty) return;
    final payType = await _pickPayType();
    if (payType == null) return;
    final rateStr = await _prompt('Ставка (₽/ч или за услугу)', '0') ?? '0';
    final percentStr = await _prompt('Процент от выручки', '0') ?? '0';
    final rate = ((double.tryParse(rateStr.replaceAll(',', '.')) ?? 0) * 100).round();
    final percent = double.tryParse(percentStr.replaceAll(',', '.')) ?? 0;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().createEmployee(name: name.trim(), payType: payType, rateCents: rate, percent: percent);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickPayType() async {
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: context.colors.card,
        child: Column(
          children: [
            CupertinoButton(child: const Text('Почасовая'), onPressed: () => Navigator.of(ctx).pop('hourly')),
            CupertinoButton(child: const Text('Сдельная (за услугу)'), onPressed: () => Navigator.of(ctx).pop('piece')),
            CupertinoButton(child: const Text('Процент от выручки'), onPressed: () => Navigator.of(ctx).pop('percent')),
            CupertinoButton(child: const Text('Оклад'), onPressed: () => Navigator.of(ctx).pop('salary')),
            CupertinoButton(child: const Text('Смешанная'), onPressed: () => Navigator.of(ctx).pop('mixed')),
          ],
        ),
      ),
    );
  }

  Future<void> _addTime(String employeeId) async {
    final hoursStr = await _prompt('Часы работы', '8');
    final hours = double.tryParse((hoursStr ?? '').replaceAll(',', '.'));
    if (hours == null || hours <= 0) return;
    final note = await _prompt('Заметка', '');
    if (!mounted) return;
    final now = DateTime.now();
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().addTimeEntry(
        employeeId: employeeId,
        startedAt: now.subtract(Duration(minutes: (hours * 60).round())),
        endedAt: now,
        minutes: (hours * 60).round(),
        note: note,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPayment(String employeeId, String type, String label) async {
    final amountStr = await _prompt(label, '0');
    final amount = ((double.tryParse((amountStr ?? '').replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;
    final note = await _prompt('Заметка', '');
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<MastersStore>().addEmployeePayment(employeeId: employeeId, type: type, amountCents: amount, note: note);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPayroll() async {
    final store = context.read<MastersStore>();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    setState(() => _busy = true);
    try {
      final summary = store.payrollSummary(start, end);
      final rows = summary.map((r) => <String, Object?>{
        'employeeName': (r['employee'] as dynamic)?.name?.toString() ?? 'Сотрудник',
        'earned': r['earned'],
        'bonus': r['bonus'],
        'penalty': r['penalty'],
        'advance': r['advance'],
        'payout': r['payout'],
        'net': r['net'],
      }).toList();
      final bytes = await DocumentService.buildPayrollPdf(title: 'Ведомость: ${DateFormat('MMMM yyyy', 'ru').format(now)}', summary: rows);
      final ok = await DocumentService.savePdf(bytes, 'payroll-${now.year}-${now.month}.pdf');
      if (mounted && ok) await showAppAlert(context, title: 'Готово', message: 'Ведомость сохранена.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeCurrentPayrollPeriod() async {
    final store = context.read<MastersStore>();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    setState(() => _busy = true);
    try {
      final period = await store.createPayrollPeriod(name: 'Месяц ${now.month}/${now.year}', startAt: start, endAt: end);
      await store.closePayrollPeriod(period.id, at: now);
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Период закрыт',
        message: 'Расчётный период ${DateFormat('MMMM yyyy', 'ru').format(now)} закрыт. Для экспорта используйте кнопку PDF.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPayrollPeriod() async {
    final store = context.read<MastersStore>();
    final periods = store.payrollPeriods.take(6).toList();
    if (periods.isEmpty) {
      await _exportPayroll();
      return;
    }
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Выберите расчётный период'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop('current'),
            child: const Text('Текущий месяц'),
          ),
          for (final period in periods)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop(period.id),
              child: Text(period.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Отмена'),
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
    if (!mounted) return;
    if (selected == null) return;
    if (selected == 'current') {
      _exportPayroll();
    } else {
      final period = store.payrollPeriods.firstWhere((p) => p.id == selected, orElse: () => store.payrollPeriods.first);
      await _exportPayrollPeriod(period);
    }
  }

  Future<void> _exportPayrollPeriod(PayrollPeriod period) async {
    final store = context.read<MastersStore>();
    setState(() => _busy = true);
    try {
      final summary = store.payrollSummary(period.startAt, period.endAt);
      final rows = summary.map((r) => <String, Object?>{
            'employeeName': (r['employee'] as dynamic)?.name?.toString() ?? 'Сотрудник',
            'earned': r['earned'],
            'bonus': r['bonus'],
            'penalty': r['penalty'],
            'advance': r['advance'],
            'payout': r['payout'],
            'net': r['net'],
          }).toList();
      final bytes = await DocumentService.buildPayrollPdf(title: 'Ведомость: ${period.name}', summary: rows);
      final suggested = 'payroll-${period.id.substring(0, 6)}.pdf';
      final ok = await DocumentService.savePdf(bytes, suggested);
      if (mounted && ok) await showAppAlert(context, title: 'Готово', message: 'Ведомость сохранена.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _managePayrollPeriods() async {
    final store = context.read<MastersStore>();
    if (store.payrollPeriods.isEmpty) {
      final ok = await showAppConfirm(
        context,
        title: 'Закрыть текущий месяц?',
        message: 'Будет создан и закрыт расчётный период текущего месяца.',
        confirmLabel: 'Закрыть',
      );
      if (!ok) return;
      await _closeCurrentPayrollPeriod();
      return;
    }
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        height: 400,
        color: context.colors.card,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Расчётные периоды', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    for (final period in store.payrollPeriods)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  period.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              if (!period.isClosed)
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () async {
                                    Navigator.of(sheetContext).pop();
                                    await store.closePayrollPeriod(period.id);
                                  },
                                  child: const Icon(CupertinoIcons.lock, size: 18),
                                ),
                              if (period.isClosed)
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () async {
                                    Navigator.of(sheetContext).pop();
                                    await store.reopenPayrollPeriod(period.id);
                                  },
                                  child: const Icon(CupertinoIcons.lock_open, size: 18),
                                ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () async {
                                  Navigator.of(sheetContext).pop();
                                  await _exportPayrollPeriod(period);
                                },
                                child: const Icon(CupertinoIcons.doc_text, size: 18),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () async {
                                  Navigator.of(sheetContext).pop();
                                  await store.deletePayrollPeriod(period.id);
                                },
                                child: Icon(CupertinoIcons.trash, size: 18, color: context.colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              CupertinoButton(
                child: const Text('Готово'),
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Employee e) async {
    if (e.role == 'owner' && e.name == 'Я') {
      await showAppAlert(context, title: 'Нельзя удалить профиль «Я»', message: 'Это исполнитель по умолчанию для заказов.');
      return;
    }
    final ok = await showAppConfirm(context, title: 'Удалить сотрудника?', message: e.name, destructive: true, confirmLabel: 'Удалить');
    if (!ok) return;
    if (!mounted) return;
    await context.read<MastersStore>().deleteEmployee(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Команда'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(padding: EdgeInsets.zero, onPressed: _managePayrollPeriods, child: const Icon(CupertinoIcons.doc_text)),
            CupertinoButton(padding: EdgeInsets.zero, onPressed: _closeCurrentPayrollPeriod, child: const Icon(CupertinoIcons.lock)),
            CupertinoButton(padding: EdgeInsets.zero, onPressed: _newEmployee, child: const Icon(CupertinoIcons.plus)),
          ],
        ),
      ),
      child: _busy
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: store.employees.isEmpty
                  ? EmptyState(
                      title: 'Нет сотрудников',
                      message: 'Добавьте первого сотрудника.',
                      art: Icon(CupertinoIcons.person_2, size: 48, color: colors.tertiaryLabel),
                      actions: [PrimaryButton(label: 'Добавить сотрудника', icon: CupertinoIcons.plus, onPressed: _newEmployee)],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: store.employees.map((e) {
                        final earned = store.earnedCents(e.id);
                        final owed = store.employeeBalanceOwed(e.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    Text(e.payTypeLabel, style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Заработано: ${_money(earned)} • К выплате: ${_money(owed)}',
                                    style: TextStyle(color: owed > 0 ? colors.orange : colors.secondaryLabel, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    SecondaryButton(label: 'Часы', icon: CupertinoIcons.clock, onPressed: () => _addTime(e.id)),
                                    SecondaryButton(label: 'Авансы', icon: CupertinoIcons.money_dollar, onPressed: () => _addPayment(e.id, 'advance', 'Авансы')),
                                    SecondaryButton(label: 'Бонус', icon: CupertinoIcons.plus, onPressed: () => _addPayment(e.id, 'bonus', 'Бонус')),
                                    SecondaryButton(label: 'Штраф', icon: CupertinoIcons.minus, onPressed: () => _addPayment(e.id, 'penalty', 'Штраф')),
                                    SecondaryButton(label: 'Выплата', icon: CupertinoIcons.arrow_right, onPressed: () => _addPayment(e.id, 'payout', 'Выплата')),
                                    SecondaryButton(label: 'Закрыть месяц', icon: CupertinoIcons.lock, onPressed: () => _closeCurrentPayrollPeriod(),),
                                    CupertinoButton(padding: EdgeInsets.zero, onPressed: () => _delete(e), child: Text('Удалить', style: TextStyle(color: colors.red))),
                                    SecondaryButton(label: 'PDF', icon: CupertinoIcons.doc_text, onPressed: _exportPayroll),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
    );
  }
}