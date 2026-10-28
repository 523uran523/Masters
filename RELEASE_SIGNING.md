# Подпись релизной сборки Android

По умолчанию релиз собирается debug‑ключом. Для Google Play и обновлений нужен собственный keystore.

## Автоматическое создание (PowerShell)

```powershell
.\scripts\create-release-keystore.ps1
```

Скрипт:
- попросит имя/компанию, организацию, город, штат, страну и пароль;
- создаст `android/upload-keystore.jks`;
- запишет `android/key.properties` для Gradle;
- выводит напоминание сохранить ключ.

После этого:

```bat
flutter build apk --release
# или
flutter build appbundle --release
```

Gradle автоматически использует release-ключ (если `android/key.properties` существует), иначе сборка останется debug-ключом (fallback).

## Ручное создание

```bat
cd android
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Создайте `android/key.properties`:

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```

## Безопасность

- `android/key.properties`, `android/*.jks`, `android/*.keystore` в `.gitignore`.
- Сохраните keystore в двух независимых местах. Потеря ключа делает обновление приложения невозможным.
- Релизный keystore нужно использовать для всех обновлений приложения.
