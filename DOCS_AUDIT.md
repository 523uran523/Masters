# Documentation audit — Masters

Дата: 2026-10-30

## Выполнено из roadmap и уже есть в коде
- SQLite offline-first, миграции v1→v12
- audit triggers, soft delete, period guards
- sync snapshot merge
- recurring payments, mixed pay types, payroll periods
- supplier/purchase tracking + supplier debt-pay
- P&L slices/stats, cash forecast, period trends
- Today dashboard (активные/к оплате/low stock/recurring/alerts)
- compact 4-tab navigation, dropdowns, bottom sheets
- client/job WhatsApp-Telegram templates
- job attachments v12 + file picker
- quick appointment booking from client
- audit viewer
- auto-update via custom server
- build speed/caching

## Что документация отстаёт / забыто
1. `ARCHITECTURE.md`
   - DB version указана как 11, сейчас 12 (`job_attachments`)
   - нет описания attachments, auto-update service, build speed rules
2. `README.md`
   - описан в основном web-сценарий; нет offline/mobile APK, автообновления, attachments, appointment booking
3. `ROADMAP.md`
   - ROADMAP не отмечает выполненные пункты (P0/P1/P2)
   - needs update after latest increments
4. Release notes
   - `RELEASE_SIGNING.md` есть, но нет краткого release checklist текущей версии `0.2.0+2`
5. Tests/docs hygiene
   - `flutter test` now 14 tests; update baseline counts in handoff docs

## Рекомендованные doc updates
- Bump DB version references 11 → 12
- Добавить sections: attachments, auto-update, audit viewer, appointment quick flow
- Добавить current baseline: analyze 11 info/warnings, tests 14/14 green
- Track roadmap with `[x]` completed items
- Add release checklist: pub get, analyze, test, build split-per-abi + universal, copy APK, server publish
