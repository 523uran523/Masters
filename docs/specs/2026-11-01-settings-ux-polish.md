# ТЗ: Полировка UX настроек — компактные группы, цветные иконки, статус-чип (settings-ux-polish)

Статус: **выдано** (senior)
Дата: 02.11.2026
Пользователь: «раздел настроек сделать более юзабельным и ярким» + «Группировать toggles». Полировка, без добавления search/вкладок/анимаций.

## Цель
В `lib/features/settings/settings_screen.dart` (1500+ строк, 4 группы, ~12 отдельных `AppCard` на одну-строку-только) сделать экран compact, vibrant и читаемым:
- Группировать все `{Row: label + Switch/Checkbox}` в ОДНУ карточку-список с разделителями (`Hairline`).
- Цветной значок у заголовка каждой секции + hue-акцент per-секции.
- Верхняя строка-чип: «Конфигурация: N из M возможностей включено» (на 4 группы).
- Пресеты (Соло/Команда/Клиенты) — 3 цветные карточки-кнопки с иконкой.
- Налоговые профили: флаг-эмодзи страны + подсветка активного профиля.
- Визуальные улучшения без изменения логики.

## Что входит (перечень конкретных правок)

### А. `_settingsGroup` — встроенный заголовок-секция
Сигнатура: `_settingsGroup(String key, String title, {IconData icon, Color? accent, required List<Widget> children})`.
В заголовке: `Icon(icon, size 20, color: accent ?? colors.accent)` + `Text(title, 16, w600)` в Row с цветным chevron (colored by accent).

Цвета по секциям:
- `features` (Общие возможности) → `colors.accent` (синий/primary) + `CupertinoIcons.settings_solid` (или checkmark_square)
- `orders` (Заказы) → `colors.orange` + `CupertinoIcons.doc_text` 
- `money` (Деньги) → `colors.green` + `CupertinoIcons.money_dollar_circle`
- `app` (Приложение) → `colors.tertiaryLabel` (нейтральный) + `CupertinoIcons.gear_solid`

### Б. Группировать toggles — 4 AppCard-списка вместо N одиночных

**features (Общие возможности):** одна `AppCard` со строками:
- Теги в заказах (Switch)
- Калькулятор цен (Switch)
- Сотрудники и зарплата (Switch)
- Канбан-колонки (чекбоксы-строки)
- Тег-карточки (как сейчас, Wrap)
Разделители `Hairline` между строками.

**orders (Заказы):** `_TermsCard` + ` hour rate ` Row + кнопка «Изменить ставку».

**money (Деньги):** налоговый блок (профили) + кассовая смена + счета-карман.

**app (Приложение):** тема, вкладки, напоминание, биометрия, PIN, обновления.

Канбан-колонки — из 4-х одиночных `AppCard` превращаются в одна карточка с текст-меткой в одной строке (label + checkbox, 44px height).

### В. Color badges / icons
- Каждая switch-строка — 32px иконка цветом секции на переднем крае + label + trailing Switch/X.
- Налоговые профили — country flag (эмодзи: RU→🇷🇺, KZ→🇰🇿, US→🇺🇸, default→🌐) + rate pill; активный — цветная заливка с accent, неактивный — дефолтный фон.

### Г. Status chip сверху
В верхней части экрана (перед первой группой) — свободный ховер «Конфигурация» с 3 пресетами в цветных карточках-кнопках (Соло 🎨/синий, Команда 👥/зелёный, Клиенты 🤝/оранжевый) и под nim — строка «Включено: N возможностей из M» (عدد switches). Тап на пресет применяет конаиг.

### Д. Визуальный polish
- Кнопки `SecondaryButton` в цветных секциях заимеют цвет `accent` (если API позволяет — что есть).
- Открытие/закрытие группы с анимацией (AnimatedSize/Fade). Если не ломает layout — добавить.
- Padding consistency: 16px вокруг групп, 12px между карточками.
- Выпадающие/rowse с `minTouchTarget = 44`.

## Не входит
- Без новых зависимостей; без изменения логики SETTINGS (только UI).
- Не трогать settings_controller (кроме readings getters), business logic, БД, unified booking, money.
- Не ломать тесты (`flutter test` = 101/101 после — проверить).
- windows/flutter/generated_* не трогать.

## Критерии приёмки
- Визуально компактнее (меньше вертикального скролла), каждая секция узнаваема по иконке-цвету, status chip и 3 цветных пресета.
- `flutter analyze --no-pub` 0 ошибок, 101/101 тестов зелёные.
- Коммит(ы) по слою + push (pull --rebase БЕЗ autostash, при чистом дереве setTimeout).
- Отчёт до 25 строк: что сделано, какие файлы, analyze/test, хеши.

## Риски
- § animated (AnimatedSize) может ломать существующие layout — тогда пропустить, AnimatedCrossFade как альтернатива.
- Тест test/settings_work_mode_test и test/settings_tax_profiles_test могут зависеть от порядка widgets — то их тестов не ломать (не менять тексты/keys; только добавлять иконки/обёртки).
- Проверить, что `_settingsGroup` signature обновление не сломит тесты (там только public Widget's build).