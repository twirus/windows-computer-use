# Roadmap — Windows Computer Use for Antigravity

Запланированные улучшения и исправления (`v3.2+`).

## Найденные узкие места и техдолг (закрыто в v3.2.0)

- [x] **Чистые скриншоты без оверлея**: кратковременно скрывать оверлей (`capture_hide` / `capture_restore` с `ack`) перед `CopyFromScreen`.
- [x] **Двойной `MaybeCollectGarbage()` в `desktop_state`**: убран дублирующий инкремент `_heavyCallCount`.
- [x] **Сериализация параллельных вызовов в `server.js`**: добавлена очередь `toolCallQueue` для `tools/call`.
- [x] **Перенос `overlay.log` в `%TEMP%`**: лог пишется в `%TEMP%\windows-desktop-mcp-overlay.log` с лимитом 256 КБ.
- [x] **Мелкие правки `skills/windows-computer-use/SKILL.md`**: обновлена версия и исправлена нумерация.

---

## Приоритет 1 — Скорость и точность (закрыто в v3.2.0)

- [x] **UIA `CacheRequest` вместо поштучных COM-запросов**: забор свойств и паттернов за один cross-process вызов.
- [x] **Опция `returnStateAfter: true` (и `settleMs`) в `batch_actions`**: серия действий + свежий `desktop_state` за один ход модели.
- [x] **Сжатие скриншотов в JPEG по умолчанию (`format: "jpeg" | "png"`, `quality: 82`)**: уменьшение размера в 4–6× (`zoom_region` остаётся в PNG).
- [x] **Состояния UI-элементов в `desktop_state`**: `checked`/`unchecked`, `selected`, `expanded`/`collapsed`, `focused`.

---

## Приоритет 2 — Умные инструменты (частично в v3.2.0, остальное в v3.3)

- [x] **Инструмент `wait_for`**: поллинг внутри C#-воркера по `windowTitleContains`, `processName`, `elementNameContains`.
- [ ] **`wait_for(screenChange: true)`**: ожидание визуального изменения экрана (быстрое сравнение хеша кадра).
- [ ] **Поиск элементов без лимита 80 штук (`find_elements` / `filter` в `desktop_state`)**: поиск по подстроке `Name`/`ControlType` по всему дереву UIA с немедленным присвоением ID.
- [x] **Кроп скриншота активного окна (`scope: "monitor" | "window"`)**: захват `WindowRect` активного окна.
- [x] **Anti-overlap для меток Set-of-Mark**: проверка пересечений бейджей `[1]`, `[2]` со сдвигом перекрывающихся номеров.

---

## Приоритет 3 — Ввод, UX и безопасность (частично в v3.2.0, остальное в v3.3)

- [x] **Модификаторы клика и горизонтальный скролл**: `modifiers: ["ctrl", "shift", "alt"]` в `mouse_click` / `click_element` и `horizontalDelta` (`MOUSEEVENTF_HWHEEL`) в `mouse_scroll`.
- [ ] **Прямой `ValuePattern.SetValue` в `type_into_element`**: вставка текста без затирания пользовательского буфера обмена (картинок/файлов) с fallback на `PasteText`.
- [x] **Улучшения UX оверлея**: `autoHideSeconds = 40` и короткий красный тост «Остановлено пользователем (Ctrl+Alt+X)».
- [x] **Защита от `Win+L`**: блокировка случайной блокировки сеанса Windows без явного флага.
