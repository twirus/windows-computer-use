# Roadmap — Windows Computer Use for Antigravity

Запланированные улучшения и исправления для следующих версий (`v3.2+`).

## Найденные узкие места и техдолг (v3.1.1)

- [ ] **Чистые скриншоты без оверлея**: кратковременно скрывать/обнулять `Opacity` оверлея перед `CopyFromScreen` (в `desktop_state`, `get_screenshot`, `zoom_region`), чтобы верхняя плашка `StatusPill` и рамка не попадали на скриншот и не перекрывали вкладки браузера.
- [ ] **Двойной `MaybeCollectGarbage()` в `desktop_state`**: убрать лишний инкремент `_heavyCallCount` (сейчас вызывается и в `CaptureScreenshot`, и в `GetDesktopState`).
- [ ] **Сериализация параллельных вызовов в `server.js`**: добавить очередь выполнения для `tools/call`, чтобы параллельные запросы не вызывали гонку состояния в `lastScreenMeta` и командах оверлея.
- [ ] **Перенос `overlay.log` в `%TEMP%`**: писать лог ошибок оверлея в `%TEMP%\windows-desktop-mcp-overlay.log` вместо папки `src/` с ограничением размера.
- [ ] **Мелкие правки `skills/windows-computer-use/SKILL.md`**: обновить версию (`v3.0` → актуальная) и исправить дублирующуюся нумерацию пункта `6.`.

---

## Приоритет 1 — Скорость и точность (v3.2)

- [ ] **UIA `CacheRequest` вместо поштучных COM-запросов**: забирать `Name`, `ControlType`, `BoundingRectangle`, `IsOffscreen`, `IsEnabled`, `ValuePattern`, `TogglePattern`, `SelectionItemPattern` за один cross-process вызов (ускорение `desktop_state` в 3–5× на Chrome/Electron/VS Code).
- [ ] **Опция `returnStateAfter: true` (и `settleMs`) в `batch_actions`**: выполнять серию действий и сразу возвращать свежий `desktop_state` за один ход модели.
- [ ] **Сжатие скриншотов в JPEG по умолчанию (`format: "jpeg" | "png"`, `quality: 82`)**: уменьшение размера скриншота в 4–6× для ускорения передачи и работы Vision-моделей (для `zoom_region` оставить PNG).
- [ ] **Состояния UI-элементов в `desktop_state`**: возвращать `checked`/`unchecked` (`TogglePattern`), `selected` (`SelectionItemPattern`), `expanded`/`collapsed` (`ExpandCollapsePattern`), `focused` (`HasKeyboardFocus`).

---

## Приоритет 2 — Умные инструменты (v3.3)

- [ ] **Инструмент `wait_for`**: поллинг внутри C#-воркера (каждые 150–200 мс) по условиям `windowTitleContains`, `processName`, `elementNameContains` или `screenChange: true` вместо слепых пауз `wait`.
- [ ] **Поиск элементов без лимита 80 штук (`find_elements` / `filter` в `desktop_state`)**: поиск по подстроке `Name`/`ControlType` по всему дереву UIA с немедленным присвоением ID.
- [ ] **Кроп скриншота активного окна (`scope: "monitor" | "window"`)**: захват только `WindowRect` активного окна для максимальной четкости текста в компактных окнах и диалогах.
- [ ] **Anti-overlap для меток Set-of-Mark**: проверка пересечений бейджей `[1]`, `[2]` в `CaptureScreenshot` со сдвигом перекрывающихся номеров в плотных тулбарах.

---

## Приоритет 3 — Ввод, UX и безопасность (v3.4)

- [ ] **Модификаторы клика и горизонтальный скролл**: `modifiers: ["ctrl", "shift", "alt"]` в `mouse_click` / `click_element` и `horizontalDelta` (`MOUSEEVENTF_HWHEEL`) в `mouse_scroll`.
- [ ] **Прямой `ValuePattern.SetValue` в `type_into_element`**: вставка текста без затирания пользовательского буфера обмена (картинок/файлов) с fallback на `PasteText`.
- [ ] **Улучшения UX оверлея**: увеличить `autoHideSeconds` до 35–45 сек (для долгих размышлений Pro-моделей) и показывать короткий (1–1.5 сек) красный тост «Остановлено пользователем» при нажатии `Ctrl+Alt+X`.
- [ ] **Защита от `Win+L`**: блокировать случайную блокировку сеанса Windows без явного флага.
