import '../state/masters_store.dart';
import '../state/settings_controller.dart';
import 'yandex_backup_meta.dart';
import 'yandex_disk_service.dart';

class YandexSyncResult {
  const YandexSyncResult._(this.type, this.message);

  static const uploaded =
      YandexSyncResult._('uploaded', 'Бэкап загружен на Яндекс Диск.');
  static const restored =
      YandexSyncResult._('restored', 'Данные восстановлены из Яндекс Диска.');
  static const failed =
      YandexSyncResult._('failed', 'Синхронизация не выполнена.');
  static const notConnected =
      YandexSyncResult._('notConnected', 'Нет подключения к Яндексу.');

  final String type;
  final String message;
}

class YandexSyncService {
  static Future<YandexSyncResult> sync(
    MastersStore store,
    SettingsController settings,
  ) async {
    final token = await settings.ensureYandexToken();
    if (token == null) return YandexSyncResult.notConnected;

    try {
      final remote = await getBackupMeta(token);
      if (remote == null) {
        final ok = await YandexDiskService.uploadBackup(token, store.backupData());
        if (!ok) return YandexSyncResult.failed;
        await settings.setYandexLastCloudModified(null);
        return YandexSyncResult.uploaded;
      }

      final last = settings.yandexLastCloudModified;
      if (last == null || remote.modified.isAfter(last)) {
        final data = await YandexDiskService.downloadBackup(token);
        if (data == null) return YandexSyncResult.failed;
        await store.restoreFromBackup(data);
        await settings.setYandexLastCloudModified(remote.modified);
        return YandexSyncResult.restored;
      }

      final ok = await YandexDiskService.uploadBackup(token, store.backupData());
      if (!ok) return YandexSyncResult.failed;
      await settings.setYandexLastCloudModified(remote.modified);
      return YandexSyncResult.uploaded;
    } catch (_) {
      return YandexSyncResult.failed;
    }
  }
}
