import 'package:flutter/foundation.dart';

import '../core/sync_client.dart';
import '../data/app_database.dart';
import 'masters_store.dart';
import 'settings_controller.dart';

/// Итог одного прохода синхронизации.
class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.received = 0,
    this.applied = 0,
    this.keptLocal = 0,
    this.skipped = 0,
    this.reset = false,
  });

  final int pushed;
  final int received;
  final int applied;
  final int keptLocal;
  final int skipped;

  /// Сервер прислал полный набор строк (история была обрезана).
  final bool reset;

  bool get hasChanges => applied > 0 || pushed > 0;
}

/// Обмен изменениями с сервером: локальная база остаётся источником правды,
/// сервер хранит историю версий и раздаёт её другим устройствам.
class SyncService extends ChangeNotifier {
  SyncService({
    required this.database,
    required this.settings,
    required this.store,
    SyncClient Function(String)? clientFactory,
  }) : _clientFactory = clientFactory ?? _defaultClient;

  static SyncClient _defaultClient(String baseUrl) => SyncClient(baseUrl: baseUrl);
  final SyncClient Function(String) _clientFactory;

  static const int _pushBatch = 200;
  static const int _pullBatch = 500;
  static const int _maxRounds = 400;

  final AppDatabase database;
  final SettingsController settings;
  final MastersStore store;

  bool _busy = false;
  String? _error;
  String? _message;
  int _pending = 0;

  bool get busy => _busy;
  String? get error => _error;
  String? get message => _message;

  /// Сколько строк ждёт отправки.
  int get pending => _pending;

  bool get signedIn => settings.syncSignedIn;
  bool get hasSpace => settings.syncSpaceId.isNotEmpty;
  bool get ready => signedIn && hasSpace;

  String get email => settings.syncEmail;
  String get spaceName => settings.syncSpaceName;
  String get spaceInvite => settings.syncSpaceInvite;
  String get baseUrl => settings.syncBaseUrl;
  DateTime? get lastAt => settings.syncLastAt;
  bool get autoSync => settings.syncAuto;

  Future<void> refreshPending() async {
    final count = await database.syncOutboxCount();
    if (count == _pending) return;
    _pending = count;
    notifyListeners();
  }

  Future<SyncHealth> checkServer(String baseUrl) async {
    final client = SyncClient(baseUrl: baseUrl);
    try {
      return await client.health();
    } finally {
      client.close();
    }
  }

  Future<SyncAccount> signIn({
    required String email,
    required String password,
  }) async {
    final client = SyncClient(baseUrl: settings.syncBaseUrl);
    try {
      final session = await client.signIn(email: email, password: password);
      await _storeSession(session);
      return session.account;
    } finally {
      client.close();
    }
  }

  Future<SyncAccount> signUp({
    required String email,
    required String password,
    String name = '',
  }) async {
    final client = SyncClient(baseUrl: settings.syncBaseUrl);
    try {
      final session = await client.signUp(
        email: email,
        password: password,
        name: name,
      );
      await _storeSession(session);
      return session.account;
    } finally {
      client.close();
    }
  }

  Future<void> _storeSession(SyncSession session) async {
    await settings.setSyncSession(
      token: session.token,
      email: session.account.email,
      expiresAtSeconds: session.expiresAt,
    );
    await settings.setSyncBaseUrl(settings.syncBaseUrl);
    notifyListeners();
  }

  Future<void> signOut() async {
    final token = settings.syncToken;
    if (token.isNotEmpty) {
      final client = SyncClient(baseUrl: settings.syncBaseUrl);
      try {
        await client.signOut(token);
      } catch (_) {
        // Выходим локально, даже если сервер недоступен.
      } finally {
        client.close();
      }
    }
    await settings.signOutSync();
    await database.clearSyncOutbox();
    _error = null;
    _message = null;
    _pending = 0;
    notifyListeners();
  }

  Future<List<SyncSpace>> spaces() async {
    final client = SyncClient(baseUrl: settings.syncBaseUrl);
    try {
      return await client.spaces(settings.syncToken);
    } finally {
      client.close();
    }
  }

  Future<SyncSpace> createSpace(String name) async {
    final client = SyncClient(baseUrl: settings.syncBaseUrl);
    try {
      final space = await client.createSpace(settings.syncToken, name);
      await _applySpace(space);
      return space;
    } finally {
      client.close();
    }
  }

  Future<SyncSpace> joinSpace(String inviteCode) async {
    final client = SyncClient(baseUrl: settings.syncBaseUrl);
    try {
      final space = await client.joinSpace(
        settings.syncToken,
        inviteCode.trim(),
      );
      await _applySpace(space);
      return space;
    } finally {
      client.close();
    }
  }

  Future<void> _applySpace(SyncSpace space) async {
    await settings.setSyncSpace(
      id: space.id,
      name: space.name,
      inviteCode: space.inviteCode,
    );
    await settings.setSyncLastSeq(0);
    notifyListeners();
  }

  Future<void> leaveSpace() async {
    final spaceId = settings.syncSpaceId;
    if (spaceId.isEmpty) return;
    final client = SyncClient(baseUrl: settings.syncBaseUrl);
    try {
      await client.leaveSpace(settings.syncToken, spaceId);
    } catch (_) {
      // Локально отключаемся в любом случае.
    } finally {
      client.close();
    }
    await settings.clearSyncSpace();
    await database.clearSyncOutbox();
    _pending = 0;
    notifyListeners();
  }

  Future<void> setAutoSync(bool value) async {
    await settings.setSyncAuto(value);
    notifyListeners();
  }

  /// Обмен изменениями: сначала отправляем своё, затем забираем чужое.
  Future<SyncReport?> syncNow({bool silent = false}) async {
    if (_busy) return null;
    if (!ready) {
      _fail('Сначала войдите и выберите рабочую область.');
      return null;
    }
    final token = settings.syncToken;
    final spaceId = settings.syncSpaceId;
    if (token.isEmpty || spaceId.isEmpty) {
      _fail('Сначала войдите и выберите рабочую область.');
      return null;
    }

    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();

    final client = _clientFactory(settings.syncBaseUrl);
    var pushed = 0;
    var received = 0;
    var applied = 0;
    var keptLocal = 0;
    var skipped = 0;
    var reset = false;

    try {
      final deviceId = settings.syncDeviceId;

      for (var round = 0; round < _maxRounds; round++) {
        final batch = await database.collectSyncBatch(
          deviceId: deviceId,
          limit: _pushBatch,
        );
        if (batch.isEmpty) break;
        if (batch.rows.isEmpty) {
          await database.confirmSyncBatch(batch);
          continue;
        }

        final result = await client.push(
          token: token,
          spaceId: spaceId,
          rows: batch.rows,
        );
        final unresolved = result.conflicts.where((remote) {
          final original = batch.rows.where(
            (local) => local.table == remote.table && local.id == remote.id,
          ).firstOrNull;
          return original == null ||
              original.updatedAt != remote.updatedAt ||
              original.deviceId != remote.deviceId ||
              original.deleted != remote.deleted ||
              !mapEquals(original.data, remote.data);
        });
        if (unresolved.isNotEmpty) {
          throw StateError(
            'Обнаружен конфликт изменений. Локальные изменения сохранены. '
            'Проверьте данные на устройствах перед повторным обменом.',
          );
        }
        await database.confirmSyncBatch(batch);
        pushed += batch.rows.length;
        if (batch.rows.length < _pushBatch) break;
      }

      var since = settings.syncLastSeq;
      var cursor = '';
      final pendingRows = <SyncRow>[];
      var pullComplete = false;
      for (var round = 0; round < _maxRounds; round++) {
        final result = await client.pull(
          token: token,
          spaceId: spaceId,
          since: since,
          limit: _pullBatch,
          cursor: cursor,
        );
        if (result.reset) reset = true;
        received += result.rows.length;

        pendingRows.addAll(result.rows);
        since = result.next;
        cursor = result.cursor;
        if (!result.more) {
          pullComplete = true;
          break;
        }
        if (result.rows.isEmpty) {
          throw StateError('Сервер вернул пустую страницу при незавершённой синхронизации.');
        }
      }
      if (!pullComplete) {
        throw StateError('Не удалось получить все страницы синхронизации.');
      }
      if (pendingRows.isNotEmpty) {
        final outcome = await database.applySyncRows(pendingRows);
        applied += outcome.applied;
        keptLocal += outcome.keptLocal;
        skipped += outcome.skipped;
        if (outcome.skipped > 0) {
          throw StateError('Не удалось применить все данные синхронизации. Повторите обмен.');
        }
      }
      await settings.setSyncLastSeq(since);

      if (applied > 0) {
        await store.load();
      }

      await settings.markSyncedNow();
      final report = SyncReport(
        pushed: pushed,
        received: received,
        applied: applied,
        keptLocal: keptLocal,
        skipped: skipped,
        reset: reset,
      );
      _message = _describe(report);
      _error = null;
      return report;
    } on SyncException catch (error) {
      if (error.isUnauthorized) {
        await settings.signOutSync();
        _error = 'Сессия истекла, войдите снова.';
      } else {
        _error = error.message;
      }
      if (!silent) notifyListeners();
      return null;
    } catch (error) {
      if (applied > 0) await store.load();
      _error = 'Не удалось синхронизироваться: $error';
      return null;
    } finally {
      client.close();
      _busy = false;
      await refreshPending();
      notifyListeners();
    }
  }

  void _fail(String message) {
    _error = message;
    _message = null;
    notifyListeners();
  }

  String _describe(SyncReport report) {
    if (report.pushed == 0 && report.applied == 0) {
      return 'Всё уже синхронизировано.';
    }
    final parts = <String>[];
    if (report.pushed > 0) parts.add('отправлено ${report.pushed}');
    if (report.applied > 0) parts.add('получено ${report.applied}');
    return 'Готово: ${parts.join(', ')}.';
  }

  void clearMessages() {
    if (_error == null && _message == null) return;
    _error = null;
    _message = null;
    notifyListeners();
  }
}
