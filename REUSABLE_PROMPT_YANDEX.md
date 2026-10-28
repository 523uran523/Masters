# Reusable prompt: add browser-based Yandex Disk backup to a Flutter app

Этот промпт можно копировать в другой чат с исходным проектом.

---

## PROMPT (copy-paste)

You are continuing development of a Flutter app `[APP NAME]`. Working directory:
`[WORKING DIR PATH]`. Local-first app: SQLite baseline, Cupertino UI, runs
on Android (primary) and optionally Windows/Web. Existing state: `[brief
description: modules, DB schema version, packages]`. Keep changes compatible
with repo `[GITHUB REPO]`.

Task: replace the existing Yandex Disk integration (login+password / WebDAV)
with **browser-based OAuth**, so the app never stores or sees the user's
Yandex password. Sync format — JSON (one full database snapshot). CSV exists
as optional human export only and is not part of sync.

### Constraints

- English file/path names only.
- Work only inside the project folder.
- Do not break Android/desktop builds while adding Web support.
- Do not expose `client_secret` in browser bundles: keep it in the local server
  via env var; mobile can fall back to the embedded value.
- Keep `client_id` configurable through `--dart-define` (default empty).
- Prefer surgical edits to already-working code.
- Run `flutter analyze --no-pub` and `flutter test` after changes.

### Architecture to implement

1. `lib/core/yandex_oauth.dart` (conditional imports forbidden — pure Dart):
   - `clientId` from `String.fromEnvironment('YANDEX_CLIENT_ID', defaultValue: '')`
   - `clientSecret` from `String.fromEnvironment('YANDEX_CLIENT_SECRET', ...)`
   - `redirectUri`: web `http://localhost:8080/oauth/yandex`, native
     `https://oauth.yandex.ru/verification_code`
   - PKCE (`Random.secure`, SHA-256 → base64Url) in `buildAuthorizeUri()`
   - store `code_verifier` & `state` in `shared_preferences`
   - `exchangeCode(code)` → POST to token endpoint; on web proxy through
     `/api/oauth/token`; append `client_secret` only on native
     (web server injects it from `YANDEX_CLIENT_SECRET` env var)
   - `refresh(refreshToken)`
   - `verifyState(state)`

2. `lib/core/yandex_disk_service.dart` — REST API instead of WebDAV:
   - base `$_api` = web `_override ? '$apiBase/api/disk' : ...` /
     native `https://cloud-api.yandex.net/v1/disk`
   - folder `disk:/<APP>/`, file `$folder/masters-backup-latest.json`
   - `testConnection(token)` → GET root
   - `ensureFolder(token)`
   - `getBackupMeta(token)` → GET `/resources?path=&fields=modified,size`
   - `uploadBackup(token, data)` → GET upload href → PUT bytes
   - `downloadBackup(token)` → GET download href → GET href
   - network failures return `null`/`false`, no exceptions escape

3. `lib/core/api_config.dart` — `YANDEX_API_BASE` override; on web defaults to
   `''` (same origin), in dev set `http://localhost:8081`.

4. `lib/core/web_url.dart` + platform stub — `replaceUrl(url)` using
   `history.replaceState` on web, no-op on others.

5. `lib/state/settings_controller.dart`:
   - remove stored login/password keys; on `load()` delete legacy keys
   - store `yandex_access_token`, `yandex_refresh_token`,
     `yandex_token_expires_at`, `yandex_last_cloud_modified_at`,
     `yandex_auto_backup`
   - `setYandexTokens`, `disconnectYandex`, `ensureYandexToken` (auto-refresh
     if expiring within 60 seconds), `setYandexLastCloudModified`

6. `lib/main.dart`: pick `databaseFactory` by platform; call
   `_completeYandexLoginIfNeeded(settings)` after load — parse `Uri.base`,
   exchange code, clear the code from the URL. If `yandexAutoBackup &&
   yandexConnected`, upload snapshot in background. No `print` of password.

7. `lib/features/settings/settings_screen.dart`:
   - Replace login/password fields with "Войти через Яндекс" button.
   - Web: `_self` window name for in-place redirect; on return the page reopens
     with status "Подключено".
   - Android/desktop: open external browser with redirect
     `https://oauth.yandex.ru/verification_code`, show a code input field +
     "Подтвердить код".
   - Show auto-backup switch, upload/restore/sync buttons, disconnect.
   - No startup prompt that pushes data without user confirmation.

8. `web_server/server.dart` (+ `web_server/api_proxy.dart` for reuse):
   - Append `/api/oauth/token`, `/api/disk/*`, `/api/upload`, `/api/fetch`
     routing.
   - Inject `YANDEX_CLIENT_SECRET` from env into the token request body/body
     server-side so it never reaches the browser.
   - CORS headers on proxies, but target host must be in `yandex.ru /
     yandex.net / yandex.com`.
   - Optional `proxy_server.dart` on port 8081 for `flutter run` dev mode.
   - For production, same-origin relative requests.

9. `web/index.html`: keep the sqlite3.wasm loader patch (`env.memory` import
   + shims) unless the chosen wasm version matches the Dart package exactly.

### Web database prerequisites

- Do not blindly run `dart run sqflite_common_ffi_web:setup`; it may fetch a
  wasm build that mismatches the installed `sqlite3` Dart package.
- Verify with node: imports should be only `dart:*` (+ `env:memory`), exports
  must include `sqlite3_initialize`; otherwise replace with the matching GitHub
  release (`sqlite3-<version>/sqlite3.wasm`).
- Prefer `databaseFactoryFfiWebNoWebWorker` for the project size.
- Skip `PRAGMA foreign_keys = ON` on web (it throws during open).
- Watch for `Random().nextInt(1 << 32)` overflow on web (use two 30-bit values).

### Sync policy

- Transport format: **JSON** (`backupData()` snapshot, DB schema version
  checked in `restoreFromBackup`). Do NOT use CSV for sync — it is lossy.
- CSV stays only as a human-facing "export to Excel" button (optional).
- Snapshot is LWW ("whoever uploads last wins"). Track last cloud modified
  time to decide whether to push or pull; pull without confirm only if the
  user explicitly chose sync, and show "разные версии" warning.

### Deliverables to leave behind

- `flutter analyze --no-pub` clean beyond pre-existing info (14 print infos
  from the server OK).
- `flutter test` passes.
- Updated `WEB_HANDOFF.md` listing changes and remaining tasks.
- `YANDEX_OAUTH_SETUP.md` with the registration steps from the text above.
- `scripts/` (`dev_web.bat`, `dev_android.bat`, `build_all.bat`) and
  `DEV_WORKFLOW.md` for parallel phone+web development.
- `.github/workflows/ci.yml` for analyze/test/build web/APK.

### Do not

- Store the Yandex password or `client_secret` in the browser.
- Replace `web/sqlite3.wasm` blindly on every build.
- Make startup auto-pull overwrite local data without a confirmation dialog.
