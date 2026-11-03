import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../state/masters_store.dart';
import '../../data/models/client.dart';
import '../../data/models/job.dart';
import 'client_detail_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _clientSearchController = TextEditingController();
  String _clientQuery = '';
  String _clientFilter = 'all';
  String? _selectedClientId;

  Future<void> _mergeDuplicates() async {
    final store = context.read<MastersStore>();
    final groups = store.findDuplicateClients();
    if (!mounted) return;
    if (groups.isEmpty) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Дубли не найдены'),
          content: const Text('Похожих клиентов по телефону или имени нет.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ОК'),
            ),
          ],
        ),
      );
      return;
    }

    final group = await showCupertinoModalPopup<List<Client>>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Объединить дубли'),
        message: const Text('Выберите группу клиентов для объединения.'),
        actions: groups
            .map(
              (item) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(dialogContext).pop(item),
                child: Text('${item.first.name} (${item.length})'),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (group == null || !mounted) return;

    final targetId = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Клиент для объединения'),
        message: const Text(
          'В какую карточку перенести заказы, объекты и выплаты?',
        ),
        actions: group
            .map(
              (client) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(dialogContext).pop(client.id),
                child: Text(
                  client.phone.trim().isEmpty
                      ? '${client.name} — без телефона'
                      : '${client.name} — ${client.phone}',
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (targetId == null || !mounted) return;

    final target = store.clientById(targetId);
    if (target == null) return;
    final sources = group.where((c) => c.id != targetId).toList();
    final ok = await showAppConfirm(
      context,
      title: 'Объединить клиентов?',
      message:
          'Заказы, объекты, напоминания и транзакции ${sources.length} дублей будут перенесены в карточку «${target.name}»; дубли скрыты.',
      confirmLabel: 'Объединить',
    );
    if (ok != true || !mounted) return;

    for (final source in sources) {
      await store.mergeClientInto(sourceId: source.id, targetId: target.id);
    }
    if (!mounted) return;
    if (_selectedClientId != null &&
        group.any((c) => c.id == _selectedClientId) &&
        _selectedClientId != target.id) {
      setState(() => _selectedClientId = target.id);
    }
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Готово'),
        content: Text('Клиенты объединены в «${target.name}».'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _showClientActions() async {
    final choice = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Дополнительно'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('filter'),
            child: const Text('Фильтр клиентов'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('search'),
            child: const Text('Поиск'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('merge'),
            child: const Text('Найти дубли'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (choice == 'filter') {
      final v = await showCupertinoModalPopup<String>(
        context: context,
        builder: (dialogContext) => CupertinoActionSheet(
          title: const Text('Фильтр клиентов'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop('all'),
              child: const Text('Все'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop('debt'),
              child: const Text('С долгом'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop('paid'),
              child: const Text('Без долга'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
        ),
      );
      if (v != null) setState(() => _clientFilter = v);
    } else if (choice == 'search') {
      await _showSearch();
    } else if (choice == 'merge') {
      await _mergeDuplicates();
    }
  }

  Future<void> _addClient() async {
    final name = await _promptText(
      'Имя клиента',
      'Иван',
      textCapitalization: TextCapitalization.words,
    );
    if (name == null || name.trim().isEmpty) return;
    final phone = await _promptText('Телефон', '+7...');
    final note = await _promptText('Заметка', '');
    if (!mounted) return;
    final store = context.read<MastersStore>();
    await store.createClient(
      name: name.trim(),
      phone: phone?.trim() ?? '',
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );
  }

  Future<String?> _promptText(
    String title,
    String placeholder, {
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) async {
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
            textCapitalization: textCapitalization,
            autofocus: true,
            decoration: BoxDecoration(
              color: context.colors.card,
              border: Border.all(color: context.colors.separator),
              borderRadius: BorderRadius.circular(8),
            ),
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

  Future<void> _showSearch() async {
    _clientSearchController.text = _clientQuery;
    if (!mounted) return;
    final result = await showCupertinoDialog<String?>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Поиск'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _clientSearchController,
            placeholder: 'Поиск клиентов',
            autofocus: true,
            onSubmitted: (_) =>
                Navigator.of(dialogContext)
                    .pop(_clientSearchController.text.trim()),
            decoration: BoxDecoration(
              color: context.colors.card,
              border: Border.all(color: context.colors.separator),
              borderRadius: BorderRadius.circular(8),
            ),
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
                    .pop(_clientSearchController.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _clientQuery = result);
  }

  Widget _buildList(MastersStore store, AppColors colors, bool wide) {
    var clients = store.clients;
    final q = _clientQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      clients = clients
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.phone.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_clientFilter == 'debt') {
      clients = clients.where((c) => store.clientDebtCents(c.id) > 0).toList();
    } else if (_clientFilter == 'paid') {
      clients = clients.where((c) => store.clientDebtCents(c.id) <= 0).toList();
    }

    if (clients.isEmpty) {
      return EmptyState(
        title: 'Нет клиентов',
        message: 'Нажмите +, чтобы добавить клиента.',
        art: Icon(CupertinoIcons.person, size: 48, color: colors.tertiaryLabel),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final c = clients[index];
        final clientJobs = store.jobsForClient(c.id);
        final jobsCount = clientJobs.length;
        final objectsCount = store.objects
            .where((o) => o.clientId == c.id)
            .length;
        final debt = store.clientDebtCents(c.id);
        final hasUnpaidClosed = clientJobs.any((j) {
          return j.status == JobStatus.closed &&
              j.priceCents - store.paidForJob(j.id) > 0;
        });
        final selected = _selectedClientId == c.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: ValueKey(c.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(CupertinoIcons.delete, color: colors.red),
            ),
            confirmDismiss: (_) => showAppConfirm(
              context,
              title: 'Удалить клиента?',
              message: 'Объекты и заказы клиента тоже удалятся.',
              destructive: true,
              confirmLabel: 'Удалить',
            ),
            onDismissed: (_) => context.read<MastersStore>().deleteClient(c.id),
            child: AppCard(
              onTap: () {
                if (wide) {
                  setState(() => _selectedClientId = c.id);
                } else {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => ClientDetailScreen(clientId: c.id),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  IconBadge(color: colors.accent, icon: CupertinoIcons.person),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            if (c.phone.isNotEmpty) c.phone,
                            '$objectsCount объектов',
                            '$jobsCount заказов',
                          ].join(' • '),
                          style: TextStyle(
                            color: colors.secondaryLabel,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected && wide)
                    Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: colors.accent,
                    ),
                  if (hasUnpaidClosed)
                    Pill(
                      'Не оплачен ${(debt / 100).toStringAsFixed(0)} ₽',
                      color: colors.red,
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
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final isWide = MediaQuery.of(context).size.width >= 720;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Клиенты'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showClientActions,
              child: const Icon(CupertinoIcons.ellipsis_circle, semanticLabel: 'Дополнительно'),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _addClient,
              child: const Icon(CupertinoIcons.plus, semanticLabel: 'Добавить'),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_clientQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Поиск: $_clientQuery',
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
                        _clientQuery = '';
                        _clientSearchController.clear();
                      }),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        semanticLabel: 'Очистить',
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: isWide
                  ? Row(
                      children: [
                        Expanded(child: _buildList(store, colors, true)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _selectedClientId == null
                              ? EmptyState(
                                  title: 'Выберите клиента',
                                  message: 'Слева список клиентов; справа — карточка.',
                                  art: Icon(
                                    CupertinoIcons.person_2,
                                    size: 48,
                                    color: colors.tertiaryLabel,
                                  ),
                                )
                              : ClientDetailScreen(
                                  clientId: _selectedClientId!,
                                ),
                        ),
                      ],
                    )
                  : _buildList(store, colors, false),
            ),
          ],
        ),
      ),
    );
  }
}
