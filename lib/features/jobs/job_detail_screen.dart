import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/document_service.dart';

import 'package:open_filex/open_filex.dart';

import '../../core/deep_link_service.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/job.dart';
import '../../data/models/job_attachment.dart';
import 'job_form_screen.dart';
import 'cost_calculator_screen.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';

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
  List<JobAttachment> _attachments = const [];
  bool _busyAttachment = false;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    if (!mounted) return;
    final store = context.read<MastersStore>();
    final list = await store.attachmentsForJob(widget.jobId);
    if (mounted) setState(() => _attachments = list);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _createDocument(MastersStore store, Job job) async {
    final type = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 220,
        color: context.colors.card,
        child: Column(
          children: [
            CupertinoButton(
              child: const Text('╨Ъ╨▓╨╕╤В╨░╨╜╤Ж╨╕╤П'),
              onPressed: () => Navigator.of(ctx).pop('╨Ъ╨▓╨╕╤В╨░╨╜╤Ж╨╕╤П'),
            ),
            CupertinoButton(
              child: const Text('╨Р╨║╤В ╨▓╤Л╨┐╨╛╨╗╨╜╨╡╨╜╨╜╤Л╤Е ╤А╨░╨▒╨╛╤В'),
              onPressed: () =>
                  Navigator.of(ctx)
                      .pop('╨Р╨║╤В ╨▓╤Л╨┐╨╛╨╗╨╜╨╡╨╜╨╜╤Л╤Е ╤А╨░╨▒╨╛╤В'),
            ),
            CupertinoButton(
              child: const Text('╨б╤З╤С╤В'),
              onPressed: () => Navigator.of(ctx).pop('╨б╤З╤С╤В'),
            ),
          ],
        ),
      ),
    );
    if (type == null) return;
    final bytes = await DocumentService.buildJobPdf(
      store: store,
      job: job,
      type: type,
    );
    final name =
        'document-${job.id.substring(0, 6)}-${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ok = await DocumentService.savePdf(bytes, name);
    if (mounted && ok) {
      await showAppAlert(
        context,
        title: '╨У╨╛╤В╨╛╨▓╨╛',
        message: '╨Ф╨╛╨║╤Г╨╝╨╡╨╜╤В ╤Б╨╛╤Е╤А╨░╨╜╤С╨╜.',
      );
    }
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

  Future<void> _addAttachment() async {
    final files = await FilePicker.pickFiles();
    if (files == null || files.isEmpty || files.single.path == null) return;
    final store = context.read<MastersStore>();
    setState(() => _busyAttachment = true);
    try {
      await store.addJobAttachment(
        jobId: widget.jobId,
        sourcePath: files.single.path!,
      );
      await _loadAttachments();
    } finally {
      if (mounted) setState(() => _busyAttachment = false);
    }
  }

  Future<void> _removeAttachment(JobAttachment a) async {
    final ok = await showAppConfirm(
      context,
      title: '╨г╨┤╨░╨╗╨╕╤В╤М ╨▓╨╗╨╛╨╢╨╡╨╜╨╕╨╡?',
      message: a.fileName,
      destructive: true,
      confirmLabel: '╨г╨┤╨░╨╗╨╕╤В╤М',
    );
    if (!ok) return;
    await context.read<MastersStore>().deleteJobAttachment(a.id);
    await _loadAttachments();
  }

  Future<void> _addStage(MastersStore store) async {
    final title = await _promptText(
      '╨Э╨╛╨▓╤Л╨╣ ╤Н╤В╨░╨┐',
      '╨Э╨░╨┐╤А╨╕╨╝╨╡╤А: ╨Ч╨░╨╝╨╡╤А',
    );
    if (title == null || title.trim().isEmpty) return;
    await store.addStage(widget.jobId, title.trim());
  }

  Future<void> _addMaterial(MastersStore store) async {
    final name = await _promptText(
      '╨Ь╨░╤В╨╡╤А╨╕╨░╨╗',
      '╨Э╨░╨┐╤А╨╕╨╝╨╡╤А: ╨Ъ╨░╨▒╨╡╨╗╤М 3x2.5',
    );
    if (name == null || name.trim().isEmpty) return;
    final qtyStr = await _promptText('╨Ъ╨╛╨╗╨╕╤З╨╡╤Б╤В╨▓╨╛', '1');
    final qty = double.tryParse((qtyStr ?? '1').replaceAll(',', '.')) ?? 1;
    final unit = await _promptText('╨Х╨┤╨╕╨╜╨╕╤Ж╨░', '╨╝') ?? '╤И╤В';
    final priceStr = await _promptText(
      '╨ж╨╡╨╜╨░ ╨╖╨░ ╨╡╨┤╨╕╨╜╨╕╤Ж╤Г (тВ╜)',
      '0',
    );
    final priceCents =
        ((double.tryParse((priceStr ?? '0').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    await store.addMaterial(
      jobId: widget.jobId,
      name: name.trim(),
      quantity: qty <= 0 ? 1 : qty,
      unit: unit.trim().isEmpty ? '╤И╤В' : unit.trim(),
      priceCents: priceCents,
    );
  }

  Future<void> _acceptPayment(MastersStore store, Job job) async {
    final remaining = job.priceCents - store.paidForJob(job.id);
    final amountStr = await _promptText(
      '╨б╤Г╨╝╨╝╨░ ╨╛╨┐╨╗╨░╤В╤Л',
      remaining > 0 ? (remaining / 100).toStringAsFixed(0) : '0',
    );
    final amount =
        ((double.tryParse((amountStr ?? '0').replaceAll(',', '.')) ?? 0) * 100)
            .round();
    if (amount <= 0) return;
    if (amount > remaining) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'РћС€РёР±РєР°',
          message:
              'РЎСѓРјРјР° РЅРµ РјРѕР¶РµС‚ РїСЂРµРІС‹С€Р°С‚СЊ РѕСЃС‚Р°С‚РѕРє.',
        );
      }
      return;
    }
    final accountId = await _pickAccount(store);
    if (accountId == null) return;
    try {
      await store.addTransaction(
        accountId: accountId,
        kind: 'payment',
        direction: 'in',
        amountCents: amount,
        category: '╨Ю╨┐╨╗╨░╤В╨░ ╨╖╨░╨║╨░╨╖╨░',
        note: job.title,
        clientId: job.clientId,
        jobId: job.id,
      );
    } catch (e) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'РћС€РёР±РєР°',
          message: e.toString(),
        );
      }
    }
  }

  Future<void> _closeJob(MastersStore store, Job job) async {
    try {
      var current = store.jobById(job.id) ?? job;
      final remaining = (current.priceCents - store.paidForJob(current.id)) < 0
          ? 0
          : current.priceCents - store.paidForJob(current.id);

      if (current.priceCents <= 0 || remaining <= 0) {
        if (current.status != JobStatus.done) {
          await store.setJobStatus(current.id, JobStatus.done);
          current =
              store.jobById(current.id) ??
              current.copyWith(status: JobStatus.done);
        }
        await store.setJobStatus(current.id, JobStatus.closed);
        return;
      }

      final choice = await showCupertinoDialog<String?>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Р—Р°РєСЂС‹С‚СЊ Р·Р°РєР°Р·?'),
          content: Text(
            'РћСЃС‚Р°С‚РѕРє Рє РѕРїР»Р°С‚Рµ: ${(remaining / 100).toStringAsFixed(0)} в‚Ѕ',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop('accept'),
              child: const Text(
                'РџСЂРёРЅСЏС‚СЊ РѕСЃС‚Р°С‚РѕРє Рё Р·Р°РєСЂС‹С‚СЊ',
              ),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop('debt'),
              child: const Text('Р—Р°РєСЂС‹С‚СЊ СЃ РґРѕР»РіРѕРј'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('РћС‚РјРµРЅР°'),
            ),
          ],
        ),
      );

      if (choice == null || !mounted) return;

      if (choice == 'accept') {
        final accountId = await _pickAccount(store);
        if (accountId == null || !mounted) return;
        final amountStr = await _promptText(
          'РЎСѓРјРјР° РѕРїР»Р°С‚С‹',
          (remaining / 100).toStringAsFixed(0),
        );
        if (amountStr == null || !mounted) return;
        final amount =
            ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100)
                .round();
        if (amount <= 0 || amount > remaining) {
          await showAppAlert(
            context,
            title: 'РќРµРІРµСЂРЅР°СЏ СЃСѓРјРјР°',
            message:
                'РЎСѓРјРјР° РґРѕР»Р¶РЅР° Р±С‹С‚СЊ РѕС‚ 1 РґРѕ ${(remaining / 100).toStringAsFixed(0)} в‚Ѕ.',
          );
          return;
        }
        try {
          await store.addTransaction(
            accountId: accountId,
            kind: 'payment',
            direction: 'in',
            amountCents: amount,
            category: 'РћРїР»Р°С‚Р° Р·Р°РєР°Р·Р°',
            note: current.title,
            clientId: current.clientId,
            jobId: current.id,
          );
        } catch (e) {
          if (mounted) {
            await showAppAlert(
              context,
              title: 'РћС€РёР±РєР° РѕРїР»Р°С‚С‹',
              message: e.toString(),
            );
          }
          return;
        }
        if (!mounted) return;
        if (store.paidForJob(current.id) >= current.priceCents) {
          if (current.status != JobStatus.done) {
            await store.setJobStatus(current.id, JobStatus.done);
          }
          await store.setJobStatus(current.id, JobStatus.closed);
        } else {
          await showAppAlert(
            context,
            title: 'РћРїР»Р°С‚Р° РїСЂРёРЅСЏС‚Р°',
            message: 'РћСЃС‚Р°С‚РѕРє РЅРµ РїРѕРіР°С€РµРЅ РїРѕР»РЅРѕСЃС‚СЊСЋ. Р—Р°РєР°Р· РѕСЃС‚Р°С‘С‚СЃСЏ РЅРµРѕРїР»Р°С‡РµРЅРЅС‹Рј.',
          );
        }
        return;
      }

      if (choice == 'debt') {
        if (current.status != JobStatus.done) {
          await store.setJobStatus(current.id, JobStatus.done);
        }
        await store.setJobStatus(current.id, JobStatus.closed);
        if (!mounted) return;
        await showAppAlert(
          context,
          title: 'Р’РЅРёРјР°РЅРёРµ',
          message:
              'Р—Р°РєР°Р· Р·Р°РєСЂС‹С‚ СЃ РґРѕР»РіРѕРј. РќРµРѕРїР»Р°С‡РµРЅРЅС‹Р№ РѕСЃС‚Р°С‚РѕРє: ${(remaining / 100).toStringAsFixed(0)} в‚Ѕ.',
        );
      }
    } catch (e) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'РћС€РёР±РєР°',
          message: e.toString(),
        );
      }
    }
  }

  Future<void> _sendMessage(MastersStore store, Job job) async {
    final client = store.clientById(job.clientId);
    if (client == null || client.phone.isEmpty) {
      await showAppAlert(
        context,
        title: '╨Э╨╡╤В ╤В╨╡╨╗╨╡╤Д╨╛╨╜╨░',
        message: '╨Ф╨╛╨▒╨░╨▓╤М╤В╨╡ ╤В╨╡╨╗╨╡╤Д╨╛╨╜ ╨║╨╗╨╕╨╡╨╜╤В╨░ ╨┤╨╗╤П ╤Б╨╛╨╛╨▒╤Й╨╡╨╜╨╕╤П.',
      );
      return;
    }
    final template = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: Text(client.name),
        message: const Text('╨Т╤Л╨▒╨╡╤А╨╕╤В╨╡ ╤И╨░╨▒╨╗╨╛╨╜ ╨╕ ╨║╨░╨╜╨░╨╗'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('ready'),
            child: const Text('╨Ч╨░╨║╨░╨╖ ╨│╨╛╤В╨╛╨▓'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('pickup'),
            child: const Text('╨Ь╨╛╨╢╨╜╨╛ ╨╖╨░╨▒╤А╨░╤В╤М'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('progress'),
            child: const Text('╨Ч╨░╨║╨░╨╖ ╨▓ ╤А╨░╨▒╨╛╤В╨╡'),
          ),
          if (store.paidForJob(job.id) < job.priceCents)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop('pay'),
              child: const Text('╨Э╨░╨┐╨╛╨╝╨╕╨╜╨░╨╜╨╕╨╡ ╨╛╨▒ ╨╛╨┐╨╗╨░╤В╨╡'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('whatsapp'),
            child: const Text('╨Э╨░╨┐╨╕╤Б╨░╤В╤М ╨▓ WhatsApp'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('telegram'),
            child: const Text('╨Э╨░╨┐╨╕╤Б╨░╤В╤М ╨▓ Telegram'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('╨Ю╤В╨╝╨╡╨╜╨░'),
        ),
      ),
    );
    if (template == null || !context.mounted) return;
    final debt = job.priceCents - store.paidForJob(job.id);
    final text = switch (template) {
      'ready' =>
        '╨Ч╨┤╤А╨░╨▓╤Б╤В╨▓╤Г╨╣╤В╨╡, ${client.name}! ╨Т╨░╤И ╨╖╨░╨║╨░╨╖ "${job.title}" ╨│╨╛╤В╨╛╨▓ ╨║ ╨▓╤Л╨┤╨░╤З╨╡.',
      'pickup' =>
        '╨Ч╨┤╤А╨░╨▓╤Б╤В╨▓╤Г╨╣╤В╨╡, ${client.name}! ╨Т╤Л ╨╝╨╛╨╢╨╡╤В╨╡ ╨╖╨░╨▒╤А╨░╤В╤М ╤А╨░╨▒╨╛╤В╤Г "${job.title}".',
      'progress' =>
        '╨Ч╨┤╤А╨░╨▓╤Б╤В╨▓╤Г╨╣╤В╨╡, ${client.name}! ╨а╨░╨▒╨╛╤В╨░ "${job.title}" ╨▓ ╨┐╤А╨╛╤Ж╨╡╤Б╤Б╨╡.',
      'pay' =>
        '╨Ч╨┤╤А╨░╨▓╤Б╤В╨▓╤Г╨╣╤В╨╡, ${client.name}! ╨Ю╤Б╤В╨░╨╗╨╛╤Б╤М ╨╛╨┐╨╗╨░╤В╨╕╤В╤М ${(debt / 100).toStringAsFixed(0)} тВ╜ ╨┐╨╛ ╨╖╨░╨║╨░╨╖╤Г "${job.title}".',
      'whatsapp' =>
        '╨Ч╨┤╤А╨░╨▓╤Б╤В╨▓╤Г╨╣╤В╨╡, ${client.name}! ╨Я╨╛ ╨╖╨░╨║╨░╨╖╤Г "${job.title}".',
      'telegram' =>
        '╨Ч╨┤╤А╨░╨▓╤Б╤В╨▓╤Г╨╣╤В╨╡, ${client.name}! ╨Я╨╛ ╨╖╨░╨║╨░╨╖╤Г "${job.title}".',
      _ => '',
    };
    if (template == 'whatsapp') {
      await DeepLinkService.openWhatsApp(phone: client.phone, text: text);
      return;
    }
    if (template == 'telegram') {
      await DeepLinkService.openTelegram(text: text);
    }
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
                CupertinoButton(
                  child: const Text('╨Ю╤В╨╝╨╡╨╜╨░'),
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

  Future<void> _addSessionManual(MastersStore store) async {
    final minStr = await _promptText('╨Т╤А╨╡╨╝╤П (╨╝╨╕╨╜╤Г╤В╤Л)', '60');
    final minutes = int.tryParse((minStr ?? '').trim()) ?? 0;
    if (minutes <= 0) return;
    final note = await _promptText(
      '╨Ч╨░╨╝╨╡╤В╨║╨░ (╨╜╨╡╨╛╨▒╤П╨╖╨░╤В╨╡╨╗╤М╨╜╨╛)',
      '',
    );
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
            child: const Text('╨Ю╤В╨╝╨╡╨╜╨░'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dc).pop(controller.text.trim()),
            child: const Text('╨Ю╨Ъ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final store = context.watch<MastersStore>();
    final settings = context.watch<SettingsController>();
    final job = store.jobById(widget.jobId);
    if (job == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('╨Ч╨░╨║╨░╨╖')),
        child: const Center(child: Text('╨Э╨╡ ╨╜╨░╨╣╨┤╨╡╨╜')),
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
          child: const Icon(
            CupertinoIcons.pencil,
            semanticLabel: '╨а╨╡╨┤╨░╨║╤В╨╕╤А╨╛╨▓╨░╤В╤М',
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          children: [
            // client / object
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client?.name ?? '╨С╨╡╨╖ ╨║╨╗╨╕╨╡╨╜╤В╨░',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  if (client?.phone.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        client!.phone,
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (obj != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      obj.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (obj.address.isNotEmpty)
                      Text(
                        obj.address,
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                  ],
                  if (job.note != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      job.note!,
                      style: TextStyle(
                        color: colors.secondaryLabel,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (settings.jobTagsEnabled &&
                      job.tags != null &&
                      job.tags!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '╨в╨╡╨│╨╕: ${job.tags}',
                      style: TextStyle(color: colors.accent, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('╨б╤В╨░╤В╤Г╤Б'),
            AppCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: JobStatus.values.map((s) {
                  final selected = job.status == s;
                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    onPressed: selected
                        ? null
                        : s == JobStatus.closed
                        ? () => _closeJob(store, job)
                        : () => store.setJobStatus(job.id, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? colors.accent : colors.cardElevated,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFFFFFFF)
                              : colors.label,
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
            SectionLabel('╨б╤Г╨╝╨╝╤Л'),
            AppCard(
              child: Column(
                children: [
                  _KV(
                    '╨ж╨╡╨╜╨░',
                    '${(job.priceCents / 100).toStringAsFixed(0)} тВ╜',
                  ),
                  _KV(
                    '╨а╨░╤Б╤Е╨╛╨┤ (╨▓╨▓╨╡╨┤╤С╨╜╨╜╤Л╨╣)',
                    '${(job.costCents / 100).toStringAsFixed(0)} тВ╜',
                  ),
                  _KV(
                    '╨Ь╨░╤В╨╡╤А╨╕╨░╨╗╤Л',
                    '${(materialTotal / 100).toStringAsFixed(0)} тВ╜',
                  ),
                  _KV(
                    '╨Ш╤В╨╛╨│╨╛ ╤А╨░╤Б╤Е╨╛╨┤',
                    '${(totalCost / 100).toStringAsFixed(0)} тВ╜',
                  ),
                  _KV(
                    '╨Ь╨░╤А╨╢╨░',
                    '${((job.priceCents - totalCost) / 100).toStringAsFixed(0)} тВ╜',
                  ),
                  _KV('╨Т╤А╨╡╨╝╤П', formatMinutes(totalMin)),
                  if (job.dueDate != null)
                    _KV('╨б╤А╨╛╨║', formatFullDate(job.dueDate!)),
                  if (job.assigneeId != null)
                    _KV(
                      '╨Ш╤Б╨┐╨╛╨╗╨╜╨╕╤В╨╡╨╗╤М',
                      store.employeeById(job.assigneeId!)?.name ?? 'тАФ',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: '╨Ъ╨░╨╗╤М╨║╤Г╨╗╤П╤В╨╛╤А ╤Ж╨╡╨╜╤Л',
              icon: CupertinoIcons.money_dollar,
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<Map<String, int>>(
                      CupertinoPageRoute(
                        builder: (_) => CostCalculatorScreen(
                          initialMaterialsCents: materialTotal,
                        ),
                      ),
                    );
                if (result == null || !mounted) return;
                await store.updateJob(
                  job.copyWith(
                    priceCents: result['priceCents'] as int,
                    costCents: result['costCents'] as int,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            SectionLabel(
              '╨н╤В╨░╨┐╤Л (${stages.where((s) => s.done).length}/${stages.length})',
            ),
            AppCard(
              child: Column(
                children: [
                  ...stages.map(
                    (s) => Padding(
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
                                color: s.done
                                    ? colors.secondaryLabel
                                    : colors.label,
                                decoration: s.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => store.deleteStage(s.id),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 14,
                              color: colors.tertiaryLabel,
                              semanticLabel: '╨г╨┤╨░╨╗╨╕╤В╤М',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SecondaryButton(
                    label: '╨Ф╨╛╨▒╨░╨▓╨╕╤В╤М ╤Н╤В╨░╨┐',
                    icon: CupertinoIcons.plus,
                    onPressed: () => _addStage(store),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('╨Ь╨░╤В╨╡╤А╨╕╨░╨╗╤Л (${materials.length})'),
            AppCard(
              child: Column(
                children: [
                  ...materials.map(
                    (m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${m.quantity.toStringAsFixed(m.quantity % 1 == 0 ? 0 : 2)} ${m.unit} ├Ч ${(m.priceCents / 100).toStringAsFixed(0)}',
                            style: TextStyle(
                              color: colors.secondaryLabel,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(m.totalCents / 100).toStringAsFixed(0)} тВ╜',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => store.deleteMaterial(m.id),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 14,
                              color: colors.tertiaryLabel,
                              semanticLabel: '╨г╨┤╨░╨╗╨╕╤В╤М',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SecondaryButton(
                    label: '╨Ф╨╛╨▒╨░╨▓╨╕╤В╤М ╨╝╨░╤В╨╡╤А╨╕╨░╨╗',
                    icon: CupertinoIcons.plus,
                    onPressed: () => _addMaterial(store),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('╨г╤З╤С╤В ╨▓╤А╨╡╨╝╨╡╨╜╨╕'),
            AppCard(
              child: Column(
                children: [
                  if (_timerStart != null) ...[
                    Text(
                      _formatElapsed(_elapsedSeconds),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: '╨Ю╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М',
                      icon: CupertinoIcons.stop,
                      onPressed: () => _stopTimer(store),
                    ),
                  ] else ...[
                    PrimaryButton(
                      label: '╨Э╨░╤З╨░╤В╤М ╤А╨░╨▒╨╛╤В╤Г',
                      icon: CupertinoIcons.play,
                      onPressed: _startTimer,
                    ),
                  ],
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: '╨Ф╨╛╨▒╨░╨▓╨╕╤В╤М ╤Б╨╡╤Б╤Б╨╕╤О ╨▓╤А╤Г╤З╨╜╤Г╤О',
                    icon: CupertinoIcons.plus,
                    onPressed: () => _addSessionManual(store),
                  ),
                  if (sessions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...sessions.map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${DateFormat('d MMM', 'ru').format(s.startedAt)} тАв ${formatMinutes(s.minutes)}',
                                style: TextStyle(color: colors.label),
                              ),
                            ),
                            if (s.note != null && s.note!.isNotEmpty)
                              Text(
                                s.note!,
                                style: TextStyle(
                                  color: colors.secondaryLabel,
                                  fontSize: 12,
                                ),
                              ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => store.deleteSession(s.id),
                              child: Icon(
                                CupertinoIcons.xmark,
                                size: 14,
                                color: colors.tertiaryLabel,
                                semanticLabel: '╨г╨┤╨░╨╗╨╕╤В╤М',
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
            const SizedBox(height: 16),
            if (store.paidForJob(job.id) > 0 || job.priceCents > 0) ...[
              SectionLabel('╨Ю╨┐╨╗╨░╤В╨░'),
              AppCard(
                child: Column(
                  children: [
                    _KV(
                      '╨Ю╨┐╨╗╨░╤З╨╡╨╜╨╛',
                      '${(store.paidForJob(job.id) / 100).toStringAsFixed(0)} тВ╜',
                    ),
                    _KV(
                      '╨Ю╤Б╤В╨░╤В╨╛╨║',
                      '${((job.priceCents - store.paidForJob(job.id)) / 100).toStringAsFixed(0)} тВ╜',
                    ),
                    SecondaryButton(
                      label: '╨Я╤А╨╕╨╜╤П╤В╤М ╨╛╨┐╨╗╨░╤В╤Г',
                      icon: CupertinoIcons.money_dollar,
                      onPressed: () => _acceptPayment(store, job),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SectionLabel('╨Т╨╗╨╛╨╢╨╡╨╜╨╕╤П (${_attachments.length})'),
            AppCard(
              child: Column(
                children: [
                  if (_attachments.isEmpty)
                    EmptyState(
                      title: '╨Э╨╡╤В ╨▓╨╗╨╛╨╢╨╡╨╜╨╕╨╣',
                      message: '╨Ф╨╛╨▒╨░╨▓╤М╤В╨╡ ╤Д╨╛╤В╨╛, ╤Б╨╝╨╡╤В╤Г ╨╕╨╗╨╕ ╨┤╨╛╨║╤Г╨╝╨╡╨╜╤В.',
                    ),
                  ..._attachments.map(
                    (a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.doc,
                            color: context.colors.secondaryLabel,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a.fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => OpenFilex.open(a.filePath),
                            child: const Icon(
                              CupertinoIcons.eye,
                              size: 18,
                              semanticLabel: '╨Ю╤В╨║╤А╤Л╤В╤М',
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _removeAttachment(a),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 16,
                              color: context.colors.tertiaryLabel,
                              semanticLabel: '╨г╨┤╨░╨╗╨╕╤В╤М',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SecondaryButton(
                    label: _busyAttachment
                        ? '╨Ф╨╛╨▒╨░╨▓╨╗╨╡╨╜╨╕╨╡...'
                        : '╨Ф╨╛╨▒╨░╨▓╨╕╤В╤М ╤Д╨░╨╣╨╗',
                    icon: CupertinoIcons.plus,
                    onPressed: _busyAttachment ? () {} : _addAttachment,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('╨Ф╨╡╨╣╤Б╤В╨▓╨╕╤П'),
            AppCard(
              child: Column(
                children: [
                  _ActionTile(
                    icon: job.archived
                        ? CupertinoIcons.tray_full
                        : CupertinoIcons.archivebox,
                    label: job.archived
                        ? '╨Т╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М'
                        : '╨Т ╨░╤А╤Е╨╕╨▓',
                    onTap: () => store.setArchived(job.id, !job.archived),
                  ),
                  Hairline(indent: 0),
                  SecondaryButton(
                    label: '╨б╨╛╨╖╨┤╨░╤В╤М ╨┤╨╛╨║╤Г╨╝╨╡╨╜╤В (PDF)',
                    icon: CupertinoIcons.doc_text,
                    onPressed: () => _createDocument(store, job),
                  ),
                  Hairline(indent: 0),
                  SecondaryButton(
                    label: '╨Э╨░╨┐╨╕╤Б╨░╤В╤М ╨║╨╗╨╕╨╡╨╜╤В╤Г',
                    icon: CupertinoIcons.chat_bubble,
                    onPressed: () => _sendMessage(store, job),
                  ),
                  Hairline(indent: 0),
                  _ActionTile(
                    icon: CupertinoIcons.delete,
                    label: '╨г╨┤╨░╨╗╨╕╤В╤М ╨╖╨░╨║╨░╨╖',
                    destructive: true,
                    onTap: () async {
                      final ok = await showAppConfirm(
                        context,
                        title: '╨г╨┤╨░╨╗╨╕╤В╤М ╨╖╨░╨║╨░╨╖?',
                        message: '╨н╤В╨░╨┐╤Л, ╨╝╨░╤В╨╡╤А╨╕╨░╨╗╤Л ╨╕ ╨▓╤А╨╡╨╝╤П ╤В╨╛╨╢╨╡ ╤Г╨┤╨░╨╗╤П╤В╤Б╤П.',
                        destructive: true,
                        confirmLabel: '╨г╨┤╨░╨╗╨╕╤В╤М',
                      );
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
          Text(
            label,
            style: TextStyle(
              color: destructive ? colors.red : colors.label,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: colors.tertiaryLabel,
          ),
        ],
      ),
    );
  }
}
