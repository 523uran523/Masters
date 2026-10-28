# Yandex Disk (OAuth) — напоминание по настройке

## Перед использованием функции нужен один ручной шаг

Чтобы приложение могло загружать/восстанавливать бэкапы в Яндекс Диск,
нужно **зарегистрировать собственное OAuth-приложение** в кабинете Яндекс ID:

https://oauth.yandex.ru/client/new

Это делается один раз на аккаунт пользователя (не проект).

### Поля формы (что обязательно)

1. **Название** — любое, например `Masters`.
2. **Тип приложения** — выбрать **«Веб-сервисы»** (web service).
   Без этого localhost redirect не пройдёт и Яндекс отклонит адрес.
3. **Redirect URI** — добавить оба адреса:
   - `http://localhost:8080/oauth/yandex`
   - `https://oauth.yandex.ru/verification_code`
4. **Доступ к API Яндекс ID** — не критично для Диска (можно оставить по умолчанию).
5. **Доступ к Яндекс Диску** — поставить **чтение и запись**
   (scope `cloud_api:disk.read` и `cloud_api:disk.write`). Только чтение
   ломает `uploadBackup`.
6. «Создать» и на карточке приложения скопировать:
   - **Client ID**
   - **Client secret** (показывается один раз — не терять)

### Как собрать проект с этими данными

```bat
set YANDEX_CLIENT_ID=ваш_client_id
set YANDEX_CLIENT_SECRET=ваш_client_secret
launch_masters.bat --rebuild
```

Или вручную:

```bat
set YANDEX_CLIENT_ID=ваш_client_id
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --dart-define=YANDEX_CLIENT_ID=%YANDEX_CLIENT_ID%
dart run web_server/server.dart 8080
```

Переменные окружения `YANDEX_CLIENT_ID` и `YANDEX_CLIENT_SECRET` подхватываются
`launch_masters.bat` автоматически (если заданы в системе или в начале bat-файла).

### Если в приложении видите «Вход не настроен»

- Это значит, что `YANDEX_CLIENT_ID` не был передан при сборке. Проверьте
  `--dart-define` и пересоберите web.
- Redirect URI должен **точно** совпадать с тем, что указан в приложении
  Яндекса, включая порт (`8080`). Смена порта сервера требует обновления
  redirect URI в кабинете Яндекса и константы `_webRedirect` в
  `lib/core/yandex_oauth.dart`.

### Почему вход делается «через браузер»

Приложение **не хранит и не видит** логин и пароль Яндекса. Пользователь
вводит их только на сайте Яндекса, а сюда возвращаются только токен и
refresh-токен, которые лежат в `shared_preferences`. Секрет приложения на
web подставляет локальный сервер из `YANDEX_CLIENT_SECRET` (заголовок
`Authorization: OAuth ...`), поэтому `client_secret` не попадает в браузер.
