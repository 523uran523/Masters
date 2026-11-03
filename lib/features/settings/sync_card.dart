import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/sync_client.dart';
import '../../state/settings_controller.dart';
import '../../state/sync_service.dart';

/// Карточка синхронизации: сервер, аккаунт, рабочая область, обмен данными.
class SyncCard extends StatefulWidget {
  const SyncCard({super.key});

  @override
  State<SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<SyncCard> {
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _spaceController = TextEditingController();
  final _inviteController = TextEditingController();

  bool _initialized = false;
  bool _busy = false;
  String _status = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final settings = context.read<SettingsController>();
    _urlController.text = settings.syncBaseUrl;
    _emailController.text = settings.syncEmail;
    _spaceController.text = 'Моя мастерская';
    final sync = context.read<SyncService>();
    sync.refreshPending();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _spaceController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final message = await action();
      if (!mounted) return;
      setState(() => _status = message ?? '');
    } on SyncException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveUrl(SettingsController settings) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await settings.setSyncBaseUrl(url);
    _urlController.text = settings.syncBaseUrl;
  }

  Future<String?> _checkServer() async {
    final settings = context.read<SettingsController>();
    final sync = context.read<SyncService>();
    await _saveUrl(settings);
    final health = await sync.checkServer(settings.syncBaseUrl);
    return 'Сервер отвечает: ${health.service} ${health.api}, '
        'пользователей ${health.users}, пространств ${health.spaces}.';
  }

  Future<String?> _signIn() async {
    final settings = context.read<SettingsController>();
    final sync = context.read<SyncService>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      return 'Введите почту и пароль.';
    }
    await _saveUrl(settings);
    final account = await sync.signIn(email: email, password: password);
    _passwordController.clear();
    await sync.refreshPending();
    return 'Вошли как ${account.email.isEmpty ? email : account.email}.';
  }

  Future<String?> _signUp() async {
    final settings = context.read<SettingsController>();
    final sync = context.read<SyncService>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      return 'Введите почту и пароль.';
    }
    await _saveUrl(settings);
    final account = await sync.signUp(
      email: email,
      password: password,
      name: _nameController.text.trim(),
    );
    _passwordController.clear();
    await sync.refreshPending();
    return 'Аккаунт создан: ${account.email.isEmpty ? email : account.email}.';
  }

  Future<String?> _createSpace() async {
    final sync = context.read<SyncService>();
    final name = _spaceController.text.trim();
    if (name.isEmpty) return 'Введите название мастерской.';
    final space = await sync.createSpace(name);
    return 'Пространство «${space.name}» создано.';
  }

  Future<String?> _joinSpace() async {
    final sync = context.read<SyncService>();
    final code = _inviteController.text.trim();
    if (code.isEmpty) return 'Введите код приглашения.';
    final space = await sync.joinSpace(code);
    _inviteController.clear();
    return 'Присоединились к «${space.name}».';
  }

  Future<String?> _syncNow() async {
    final sync = context.read<SyncService>();
    final report = await sync.syncNow();
    if (report == null) return sync.error ?? 'Синхронизация не выполнена.';
    return sync.message;
  }

  Future<String?> _leaveSpace() async {
    final sync = context.read<SyncService>();
    final confirmed = await showAppConfirm(
      context,
      title: 'Выйти из пространства?',
      message:
          'Данные останутся на телефоне, но обмен с другими устройствами '
          'прекратится.',
      confirmLabel: 'Выйти',
      destructive: true,
    );
    if (!confirmed) return null;
    await sync.leaveSpace();
    return 'Вы вышли из пространства.';
  }

  Future<String?> _signOut() async {
    final sync = context.read<SyncService>();
    final confirmed = await showAppConfirm(
      context,
      title: 'Выйти из аккаунта?',
      message: 'Локальные данные не пострадают.',
      confirmLabel: 'Выйти',
      destructive: true,
    );
    if (!confirmed) return null;
    await sync.signOut();
    return 'Вы вышли из аккаунта.';
  }

  Future<void> _copyInvite(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _status = 'Код скопирован.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsController>();
    final sync = context.watch<SyncService>();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.cloud, size: 20, color: colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Синхронизация',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(sync),
                      style: TextStyle(
                        color: colors.tertiaryLabel,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(
                sync.ready ? 'Включена' : 'Не настроена',
                color: sync.ready ? colors.green : colors.tertiaryLabel,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!sync.signedIn) ..._buildSignedOut(settings, sync, colors),
          if (sync.signedIn && !sync.hasSpace)
            ..._buildSpaceChoice(sync, colors),
          if (sync.ready) ..._buildReady(sync, colors),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _status,
              style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 10),
            const Center(child: CupertinoActivityIndicator()),
          ],
        ],
      ),
    );
  }

  String _subtitle(SyncService sync) {
    if (!sync.signedIn) return 'Данные на телефоне, обмен — через сервер';
    if (!sync.hasSpace) return sync.email;
    return '${sync.spaceName} · ${sync.email}';
  }

  List<Widget> _buildSignedOut(
    SettingsController settings,
    SyncService sync,
    AppColors colors,
  ) {
    return [
      _field(
        controller: _urlController,
        placeholder: 'Адрес сервера',
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 8),
      _field(
        controller: _emailController,
        placeholder: 'Почта',
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 8),
      _field(
        controller: _passwordController,
        placeholder: 'Пароль',
        obscure: true,
      ),
      const SizedBox(height: 8),
      _field(controller: _nameController, placeholder: 'Имя (необязательно)'),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Проверить сервер',
              icon: CupertinoIcons.bolt,
              onPressed: _busy ? null : () => _run(_checkServer),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Войти',
              icon: CupertinoIcons.arrow_right_to_line,
              onPressed: _busy ? null : () => _run(_signIn),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SecondaryButton(
              label: 'Создать',
              icon: CupertinoIcons.person_add,
              onPressed: _busy ? null : () => _run(_signUp),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Нужен свой сервер Masters Sync. Один раз поднимите его на ПК или '
        'телефоне — дальше он хранит только историю изменений.',
        style: TextStyle(color: colors.tertiaryLabel, fontSize: 11.5),
      ),
    ];
  }

  List<Widget> _buildSpaceChoice(SyncService sync, AppColors colors) {
    return [
      Text(
        'Выберите мастерскую: создайте свою или присоединитесь по коду.',
        style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
      ),
      const SizedBox(height: 10),
      _field(controller: _spaceController, placeholder: 'Название мастерской'),
      const SizedBox(height: 8),
      SecondaryButton(
        label: 'Создать пространство',
        icon: CupertinoIcons.add,
        onPressed: _busy ? null : () => _run(_createSpace),
      ),
      const SizedBox(height: 12),
      _field(controller: _inviteController, placeholder: 'Код приглашения'),
      const SizedBox(height: 8),
      SecondaryButton(
        label: 'Присоединиться',
        icon: CupertinoIcons.arrow_right_arrow_left,
        onPressed: _busy ? null : () => _run(_joinSpace),
      ),
      const SizedBox(height: 12),
      SecondaryButton(
        label: 'Выйти из аккаунта',
        icon: CupertinoIcons.square_arrow_right,
        onPressed: _busy ? null : () => _run(_signOut),
      ),
    ];
  }

  List<Widget> _buildReady(SyncService sync, AppColors colors) {
    final last = sync.lastAt;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Код приглашения',
                    style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
                  ),
                ),
                if (sync.spaceInvite.isNotEmpty)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => _copyInvite(sync.spaceInvite),
                    child: Text(
                      sync.spaceInvite,
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ожидает отправки: ${sync.pending} · '
              'Последняя синхронизация: ${_when(last)}',
              style: TextStyle(color: colors.tertiaryLabel, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          const Expanded(child: Text('Синхронизировать автоматически')),
          CupertinoSwitch(
            value: sync.autoSync,
            onChanged: (value) async {
              await sync.setAutoSync(value);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      SecondaryButton(
        label: _busy ? 'Обмен...' : 'Синхронизировать сейчас',
        icon: CupertinoIcons.arrow_2_circlepath,
        onPressed: _busy ? null : () => _run(_syncNow),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Сменить пространство',
              icon: CupertinoIcons.arrow_left_right,
              onPressed: _busy ? null : () => _run(_leaveSpace),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SecondaryButton(
              label: 'Выйти',
              icon: CupertinoIcons.square_arrow_right,
              onPressed: _busy ? null : () => _run(_signOut),
            ),
          ),
        ],
      ),
    ];
  }

  String _when(DateTime? at) {
    if (at == null) return 'ещё не было';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    final day = at.day.toString().padLeft(2, '0');
    final month = at.month.toString().padLeft(2, '0');
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  Widget _field({
    required TextEditingController controller,
    required String placeholder,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscure,
      keyboardType: keyboardType,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border.all(color: context.colors.separator),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
