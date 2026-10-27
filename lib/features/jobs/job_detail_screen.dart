import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/job.dart';
import 'job_form_screen.dart';
import 'cost_calculator_screen.dart';
import '../../state/masters_store.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  DateTime? _timerStart;
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timerStart = DateTime.now();
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timerStart != null) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_timerStart!).inSeconds;
        });
      }
    });
    setState(() {});
  }

  Future<void> _stopTimer(MastersStore store) async {
    _timer?.cancel();
    final start = _timerStart;
    if (start != null) {
      final minutes = DateTime.now().difference(start).inMinutes;
      if (minutes > 0 || _elapsedSeconds >= 30) {
        await store.addSession(
          jobId: widget.jobId,
          startedAt: start,
          endedAt: DateTime.now(),
          minutes: minutes < 1 && _elapsedSeconds >= 30 ? 1 : minutes,
        );
      }
    }
    _timerStart = null;
    _elapsedSeconds = 0;
    setState(() {});
  }

  Future<void> _addStage(MastersStore store) async {
    final title = await _promptText('Новый этап', 'Например: Замер');
    if (title == null || title.trim().isEmpty) return;
    await store.addStage(widget.jobId, title.trim());
  }

  Future<void> _addMaterial(MastersStore store) async {
    final name = await _promptText('Материал', 'Например: Кабель 3x2.5');
    if (name == null || name.trim().isEmpty) return;
    final qtyStr = await _promptText('Количество', '1');
    final qty = double.tryParse((qtyStr ?? '1').replaceAll(',', '.')) ?? 1;
    final unit = await _promptText('Единица', 'м') ?? 'шт';
    final priceStr = await _promptText('Цена за единицу (₽)', '0');
    final priceCents = ((double.tryParse((priceStr ?? '0').replaceAll(',', '.')) ?? 0) * 100).round();
    await store.addMaterial(
      jobId: widget.jobId,
      name: name.trim(),
      quantity: qty <= 0 ? 1 : qty,
      unit: unit.trim().isEmpty ? 'шт' : unit.trim(),
      priceCents: priceCents,
    );
  }

  Future<void> _acceptPayment(MastersStore store, Job job) async {
    final remaining = job.priceCents - store.paidForJob(job.id);
    final amountStr = await _promptText(
        'Сумма оплаты', remaining > 0 ? (remaining / 100).toStringAsFixed(0) : '0');
    final amount = ((double.tryParse((amountStr ?? '0').replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;
    final accountId = await _pickAccount(store);
    if (accountId == null) return;
    await store.addTransaction(
      accountId: accountId,
      kind: 'payment',
      direction: 'in',
      amountCents: amount,
      category: 'Оплата заказа',
      note: job.title,
      clientId: job.clientId,
      jobId: job.id,
    );
  }

  Future<String?> _pickAccount(MastersStore store) async {
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

  Future<void> _addSessionManual(MastersStore store) async {
    final minStr = await _promptText('Время (минуты)', '60');
    final minutes = int.tryParse((minStr ?? '').trim()) ?? 0;
    if (minutes <= 0) return;
    final note = await _promptText('Заметка (необязательно)', '');
    await store.addSession(
      jobId: widget.jobId,
      startedAt: DateTime.now().subtract(Duration(minutes: minutes)),
      endedAt: DateTime.now(),
      minutes: minutes,
      note: note,
    );
  }

  Future<String?> _promptText(String title, String placeholder) async {
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    final store = context.watch<MastersStore>();
    final job = store.jobById(widget.jobId);
    if (job == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Заказ')),
        child: const Center(child: Text('Не найден')),
      );
    }
    final client = store.clientById(job.clientId);
    final obj = store.objectById(job.objectId);
    final stages = store.stagesForJob(job.id);
    final materials = store.materialsForJob(job.id);
    final sessions = store.sessionsForJob(job.id);
    final totalMin = store.totalMinutesForJob(job.id);
    final materialTotal = store.totalMaterialCents(job.id);
    final totalCost = job.costCents + materialTotal;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(job.title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => JobFormScreen(jobId: job.id)),
          ),
          child: const Icon(CupertinoIcons.pencil),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // client / object
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client?.name ?? 'Без клиента',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                  if (client?.phone.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(client!.phone,
                          style: TextStyle(color: colors.secondaryLabel, fontSize: 13)),
                    ),
                  if (obj != null) ...[
                    const SizedBox(height: 6),
                    Text(obj.title,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (obj.address.isNotEmpty)
                      Text(obj.address,
                          style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                  ],
                  if (job.note != null) ...[
                    const SizedBox(height: 8),
                    Text(job.note!,
                        style: TextStyle(color: colors.secondaryLabel, fontSize: 14)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Статус'),
            AppCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: JobStatus.values.map((s) {
                  final selected = job.status == s;
                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    onPressed: selected ? null : () => store.setJobStatus(job.id, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? colors.accent : colors.cardElevated,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: selected ? const Color(0xFFFFFFFF) : colors.label,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Суммы'),
            AppCard(
              child: Column(
                children: [
                  _KV('Цена', '${(job.priceCents / 100).toStringAsFixed(0)} ₽'),
                  _KV('Расход (введённый)', '${(job.costCents / 100).toStringAsFixed(0)} ₽'),
                  _KV('Материалы', '${(materialTotal / 100).toStringAsFixed(0)} ₽'),
                  _KV('Итого расход', '${(totalCost / 100).toStringAsFixed(0)} ₽'),
                  _KV('Маржа', '${((job.priceCents - totalCost) / 100).toStringAsFixed(0)} ₽'),
                  _KV('Время', formatMinutes(totalMin)),
                  if (job.dueDate != null)
                    _KV('Срок', formatFullDate(job.dueDate!)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Калькулятор цены',
              icon: CupertinoIcons.money_dollar,
              onPressed: () async {
                final result = await Navigator.of(context).push<Map<String, int>>(
                  CupertinoPageRoute(
                    builder: (_) => CostCalculatorScreen(initialMaterialsCents: materialTotal),
                  ),
                );
                if (result == null || !mounted) return;
                await store.updateJob(job.copyWith(
                  priceCents: result['priceCents'] as int,
                  costCents: result['costCents'] as int,
                ));
              },
            ),
            const SizedBox(height: 16),
            SectionLabel('Этапы (${stages.where((s) => s.done).length}/${stages.length})'),
            AppCard(
              child: Column(
                children: [
                  ...stages.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CupertinoCheckbox(
                              value: s.done,
                              onChanged: (_) => store.toggleStage(s.id),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.title,
                                style: TextStyle(
                                  color: s.done ? colors.secondaryLabel : colors.label,
                                  decoration: s.done ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => store.deleteStage(s.id),
                              child: Icon(CupertinoIcons.xmark,
                                  size: 14, color: colors.tertiaryLabel),
                            ),
                          ],
                        ),
                      )),
                  SecondaryButton(
                    label: 'Добавить этап',
                    icon: CupertinoIcons.plus,
                    onPressed: () => _addStage(store),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Материалы (${materials.length})'),
            AppCard(
              child: Column(
                children: [
                  ...materials.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                            Text(
                              '${m.quantity.toStringAsFixed(m.quantity % 1 == 0 ? 0 : 2)} ${m.unit} × ${(m.priceCents / 100).toStringAsFixed(0)}',
                              style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Text('${(m.totalCents / 100).toStringAsFixed(0)} ₽',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => store.deleteMaterial(m.id),
                              child: Icon(CupertinoIcons.xmark,
                                  size: 14, color: colors.tertiaryLabel),
                            ),
                          ],
                        ),
                      )),
                  SecondaryButton(
                    label: 'Добавить материал',
                    icon: CupertinoIcons.plus,
                    onPressed: () => _addMaterial(store),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Учёт времени'),
            AppCard(
              child: Column(
                children: [
                  if (_timerStart != null) ...[
                    Text(
                      _formatElapsed(_elapsedSeconds),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: 'Остановить',
                      icon: CupertinoIcons.stop,
                      onPressed: () => _stopTimer(store),
                    ),
                  ] else ...[
                    PrimaryButton(
                      label: 'Начать работу',
                      icon: CupertinoIcons.play,
                      onPressed: _startTimer,
                    ),
                  ],
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Добавить сессию вручную',
                    icon: CupertinoIcons.plus,
                    onPressed: () => _addSessionManual(store),
                  ),
                  if (sessions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...sessions.map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${DateFormat('d MMM', 'ru').format(s.startedAt)} • ${formatMinutes(s.minutes)}',
                                  style: TextStyle(color: colors.label),
                                ),
                              ),
                              if (s.note != null && s.note!.isNotEmpty)
                                Text(s.note!,
                                    style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => store.deleteSession(s.id),
                                child: Icon(CupertinoIcons.xmark,
                                    size: 14, color: colors.tertiaryLabel),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (store.paidForJob(job.id) > 0 || job.priceCents > 0) ...[
              SectionLabel('Оплата'),
              AppCard(
                child: Column(
                  children: [
                    _KV('Оплачено', '${(store.paidForJob(job.id) / 100).toStringAsFixed(0)} ₽'),
                    _KV('Остаток', '${((job.priceCents - store.paidForJob(job.id)) / 100).toStringAsFixed(0)} ₽'),
                    SecondaryButton(
                      label: 'Принять оплату',
                      icon: CupertinoIcons.money_dollar,
                      onPressed: () => _acceptPayment(store, job),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SectionLabel('Действия'),
            AppCard(
              child: Column(
                children: [
                  _ActionTile(
                    icon: job.archived ? CupertinoIcons.tray_full : CupertinoIcons.archivebox,
                    label: job.archived ? 'Восстановить' : 'В архив',
                    onTap: () => store.setArchived(job.id, !job.archived),
                  ),
                  Hairline(indent: 0),
                  _ActionTile(
                    icon: CupertinoIcons.delete,
                    label: 'Удалить заказ',
                    destructive: true,
                    onTap: () async {
                      final ok = await showAppConfirm(context,
                          title: 'Удалить заказ?',
                          message: 'Этапы, материалы и время тоже удалятся.',
                          destructive: true,
                          confirmLabel: 'Удалить');
                      if (!ok) return;
                      await store.deleteJob(job.id);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final h = m ~/ 60;
    final mm = m % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${mm.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _KV extends StatelessWidget {
  const _KV(this.keyLabel, this.value);
  final String keyLabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(keyLabel, style: TextStyle(color: colors.secondaryLabel)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? colors.red : colors.accent;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: destructive ? colors.red : colors.label, fontSize: 16)),
          const Spacer(),
          Icon(CupertinoIcons.chevron_forward,
              size: 16, color: colors.tertiaryLabel),
        ],
      ),
    );
  }
}