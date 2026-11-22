# Changelog

## v3.3.0 (2026-11-23)
- **Глубокий поиск элементов (`find_elements` + `desktop_state(filter)`):**
  - Добавлен 22-й инструмент `find_elements(query, controlType, maxResults)` — поиск по всему дереву UI Automation без ограничения в 80 элементов с автоматическим присвоением ID для `click_element` и `type_into_element`.
  - В `desktop_state` добавлен опциональный параметр `filter` для фильтрации элементов по имени/значению.
- **Визуальное ожидание (`wait_for(screenChange: true)`):**
  - В `wait_for` добавлена детекция визуального изменения экрана по быстрому уменьшенному отпечатку кадра (32×18) — полезно для игр, Canvas и анимаций загрузки без UIA-событий.
- **Прямой ввод без буфера обмена (`type_into_element(directValue: true)`):**
  - Поддержка прямой установки значения через `ValuePattern.SetValue` (не затрагивает картинки и файлы в буфере обмена Windows) с автоматическим fallback на вставку через буфер обмена, если контрол не поддерживает `ValuePattern`.

## v3.2.0 (2026-11-23)
- **Ускорение и качество зрения:**
  - `desktop_state` переведён на UIA `CacheRequest` (сбор `Name`, `ControlType`, `BoundingRectangle`, `IsOffscreen`, `IsEnabled`, `HasKeyboardFocus` и UIA-паттернов за один cross-process вызов вместо 5–6 отдельных).
  - Добавлено сжатие скриншотов в JPEG по умолчанию (`format: "jpeg" | "png"`, `quality: 82`) для ускорения передачи и работы Vision-моделей (`zoom_region` остаётся в PNG для максимальной чёткости).
  - Чистые скриншоты без оверлея: `overlay.ps1` поддерживает быстрый `capture_hide` (с подтверждением `ack`) и `capture_restore`, чтобы рамка и верхняя плашка `StatusPill` не попадали на скриншоты.
  - Добавлен кроп активного окна (`scope: "monitor" | "window"`) в `desktop_state` и `get_screenshot`.
  - Добавлен алгоритм anti-overlap для меток Set-of-Mark (`[1]`, `[2]`, ...) — бейджи больше не перекрывают друг друга в плотных тулбарах.
  - Убран двойной вызов `MaybeCollectGarbage()` внутри одного `desktop_state`.
- **Умные действия и новые возможности:**
  - В `desktop_state` теперь возвращаются состояния UI-элементов (`[checked]`, `[unchecked]`, `[selected]`, `[expanded]`, `[collapsed]`, `[focused]`).
  - Добавлен новый инструмент `wait_for` (21-й инструмент): умное ожидание появления окна или UI-элемента в C#-воркере вместо слепых пауз `wait`.
  - В `batch_actions` добавлена опция `returnStateAfter: true` (и `settleMs`) — выполнение серии действий и получение свежего `desktop_state` за один ход модели.
  - В `click_element` и `mouse_click` добавлена поддержка модификаторов `modifiers: ["ctrl", "shift", "alt"]`.
  - В `mouse_scroll` добавлена горизонтальная прокрутка `horizontalDelta` (`MOUSEEVENTF_HWHEEL`).
- **Надёжность, безопасность и UX:**
  - В `server.js` добавлена очередь сериализации `tools/call` для защиты от гонок при параллельных вызовах.
  - В `key_press` и `batch_actions` добавлена защита от случайной блокировки ПК (`Win+L`).
  - `overlay.log` перенесён из `src/` в `%TEMP%\windows-desktop-mcp-overlay.log` с ограничением размера.
  - Автоскрытие оверлея увеличено до 40 сек (для долгих размышлений Pro-моделей), а при нажатии `Ctrl+Alt+X` показывается короткий красный тост «Остановлено пользователем».
  - Обновлён скилл `windows-computer-use` (версия v3.2, исправлена нумерация).

## v3.1.1 (2026-11-23)
- Исправлена деградация скорости при длительной работе (15–20+ минут):
  - В `overlay.ps1` устранена утечка WPF-объектов `Ellipse` и animation clocks на каждом клике (PowerShell-замыкание в `Add_Completed` видело `$ellipse = $null` и никогда не удаляло волны из `$effectsCanvas`); теперь ripple-эффекты очищаются таймером с лимитом одновременных волн и при скрытии оверлея, а фоновые breathing-анимации останавливаются при скрытии.
  - В `overlay.ps1` убраны лишние `Apply-WindowDipBounds` / `SetWindowLong` / `SetWindowPos` на каждом статусе/клике — окно переставляется только при показе или смене монитора.
  - В `desktop_worker.ps1` добавлено освобождение `Process`-хендлов (`using`) и периодическая сборка мусора (`GC.Collect` + `GC.WaitForPendingFinalizers`) для освобождения UIA COM-прокси и LOH-буферов скриншотов.
- Исправлено смещение/появление меток клика и курсора в случайных местах:
  - В `overlay.ps1` добавлен сброс `BeginAnimation(..., $null)` и `FillBehavior.Stop` для `CursorTag` (ранее `HoldEnd`-анимация блокировала `Canvas.SetLeft`/`SetTop` после повторного показа).
  - Перевод физических координат в WPF DIP переведён на точный `$effectsCanvas.PointFromScreen(...)` с проверкой монитора в `Spawn-Ripple`.
- Установщик (`installer/install.ps1`, `installer/uninstall.ps1`) и документация (`GEMINI.md`, `ARCHITECTURE.md`) обновлены для поддержки актуального глобального пути Antigravity `~/.gemini/config/mcp_config.json` (с синхронизацией legacy `~/.gemini/antigravity/mcp_config.json`).

## v3.1.0 (2026-11-22)
- Вынесен в полноценный проект с документацией, автотестами (`npm test`), скриптом синхронизации скиллов (`npm run sync-skills`) и сборщиком релизного ZIP (`npm run build`).
- Добавлен инструмент `zoom_region` (приближение мелких областей 2.5× с координатной сеткой и авто-маппингом кликов).
- Добавлен набор слэш-команд `/pc` (прямой режим по умолчанию), `/pc-flash`, `/pc-pro`.
- Аудит и багфиксы:
  - Синхронное завершение дочерних `powershell.exe` при `stdin.end`, `SIGINT`, `SIGTERM`, `exit` (нет зомби-процессов).
  - Множественная проверка опасных хоткеев закрытия (`f4+alt`, `w+ctrl`, `control+q` и т.д.).
  - Исправлен расчёт координатной сетки `zoom_region` на левых мониторах (`X < 0`).
  - Увеличена задержка восстановления буфера обмена в `PasteText` до 95 мс для Electron/Chrome.
  - Точное позиционирование оверлея через `SetWindowPos` при разном DPI мониторов.
  - Ограничение `sleep` в `batch_actions` до 15 сек и отображение статуса `mouse_drag`.

## v3.0.0 (2026-11-22)
- Полная переработка на Windows UI Automation + Set-of-Mark (`desktop_state`, `click_element`, `type_into_element`).
- Новый минималистичный WPF-оверлей (`overlay.ps1`) в стиле Claude Computer Use (рамка `2.5px`, компактная верхняя плашка, ореол и бейдж у реального курсора, ripple-волны, экстренный стоп `Ctrl+Alt+X`).
- Полноценный мульти-монитор (захват активного монитора, отрицательные координаты `X < 0`, авто-перенос курсора при `scroll`).
- Безопасный `FocusWindow` через `SwitchToThisWindow` (устранён баг со сворачиванием Discord/Electron в трей).
- Надёжный `SendKeyCombo` с выдержкой 14–16 мс между нажатиями клавиш.
- Пошаговое выполнение `batch_actions` с живым обновлением оверлея и мгновенной остановкой по `Ctrl+Alt+X`.
