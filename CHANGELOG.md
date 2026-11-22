# Changelog

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
