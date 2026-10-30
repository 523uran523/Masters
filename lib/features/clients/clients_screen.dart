import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../state/masters_store.dart';
import 'client_detail_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addClient() async {
    final name = await _promptText('Имя клиента', 'Иван');
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
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    var clients = store.clients;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      clients = clients
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q))
          .toList();
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Клиенты'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _searchVisible = !_searchVisible),
              child: Icon(_searchVisible ? CupertinoIcons.xmark : CupertinoIcons.search),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _addClient,
              child: const Icon(CupertinoIcons.plus),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_searchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: CupertinoTextField(
                  controller: _searchController,
                  placeholder: 'Поиск',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            Expanded(
              child: clients.isEmpty
                  ? EmptyState(
                      title: 'Нет клиентов',
                      message: 'Нажмите +, чтобы добавить клиента.',
                      art: Icon(CupertinoIcons.person, size: 48, color: colors.tertiaryLabel),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
                      itemCount: clients.length,
                      itemBuilder: (context, index) {
                        final c = clients[index];
                        final jobsCount = store.jobsForClient(c.id).length;
                        final objectsCount = store.objects.where((o) => o.clientId == c.id).length;
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
                              onTap: () => Navigator.of(context).push(
                                CupertinoPageRoute(
                                    builder: (_) => ClientDetailScreen(clientId: c.id)),
                              ),
                              child: Row(
                                children: [
                                  IconBadge(
                                      color: colors.accent, icon: CupertinoIcons.person),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                          [
                                            if (c.phone.isNotEmpty) c.phone,
                                            '$objectsCount объектов',
                                            '$jobsCount заказов',
                                          ].join(' • '),
                                          style: TextStyle(
                                              color: colors.secondaryLabel, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(CupertinoIcons.chevron_forward,
                                      size: 16, color: colors.tertiaryLabel),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}