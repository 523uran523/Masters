# Testing policy — Masters

По договорённости (2026-10-30):
- `flutter analyze` и `flutter test` не запускаются по умолчанию после каждой задачи.
- Проверки запускаются только по явному запросу пользователя.
- Для обычных инкрементов достаточно точечной сборки/коммита, если она явно нужна.
- Перед релизом выполняются полные проверки: `flutter pub get`, `flutter analyze --no-pub`, `flutter test`, `flutter build apk --release --split-per-abi` и `flutter build apk --release`.
