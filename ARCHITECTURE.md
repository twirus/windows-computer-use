# Architecture — Windows Computer Use MCP

## 1. High-Level Overview

```text
Antigravity (MCP Client)
   │  JSON-RPC 2.0 (newline-delimited stdio)
   ▼
src/server.js (Node.js ESM Orchestrator)
   ├──▶ src/desktop_worker.ps1  (Persistent PowerShell + compiled C# Win32/UIA engine)
   └──▶ src/overlay.ps1         (Persistent STA PowerShell + native WPF transparent overlay)
```

Все три процесса работают постоянно, пока активен MCP-сервер:
- **Ноль холодного старта** между вызовами (C# компилируется один раз при старте воркера).
- **Ноль внешних зависимостей** (не нужен Python, `pip`, `npm install` или .NET SDK).
- **Чистое завершение:** при закрытии `stdin`, `SIGINT`, `SIGTERM` или `exit` сервер синхронно завершает оба дочерних `powershell.exe`.

---

## 2. Инструменты MCP (20 штук)

### Зрение и анализ
| Инструмент | Назначение |
|---|---|
| `desktop_state` | Главный инструмент: активное окно, список окон, дерево интерактивных элементов Windows UI Automation (UIA) + скриншот с пронумерованными рамками Set-of-Mark (`[1]`, `[2]`, ...). |
| `get_screenshot` | Чистый скриншот активного или основного монитора (`monitor: "active" \| "primary"`). |
| `zoom_region` | Вырезает область вокруг `(x, y)` (по умолчанию `400×300`), увеличивает в `2.5×` и рисует координатную сетку реальных пикселей. Автоматически обновляет `lastScreenMeta` для точного клика. |
| `list_windows` | Список всех видимых окон с `Handle`, `Pid`, `ProcessName`, `Title`, `X/Y/Width/Height`, `IsForeground`, `IsMinimized`. |

### Действия по UI-элементам и окнам
| Инструмент | Назначение |
|---|---|
| `click_element` | Клик точно в центр элемента `#id` из последнего `desktop_state`. Сам возвращает фокус окну элемента (`WindowHandle`) и блокирует клик по кнопкам `Close`/`Закрыть` без `allowClose: true`. |
| `type_into_element` | Клик в поле `#id`, опционально `Ctrl+A` + `Backspace`, вставка текста через буфер обмена (кириллица/Unicode) + опционально `Enter`. |
| `window_action` | `focus`, `maximize`, `minimize`, `restore`, `move_resize`, `close` (требует `confirmClose: true`). |
| `focus_window` | Быстрый фокус окна по `titleContains`, `processName` или `handle`. |
| `launch_app` | Запуск приложения/файла/URL через `UseShellExecute = true`. |
| `clipboard` | Чтение/запись текста буфера обмена Windows (в STA-потоке). |
| `wait` | Пауза `0..15000` мс. |
| `set_overlay` | Явно показать/скрыть оверлей, обновить текст плашки или сбросить флаг остановки `resetAbort: true`. |

### Низкоуровневый ввод и батчинг
| Инструмент | Назначение |
|---|---|
| `batch_actions` | Пошаговое выполнение серии действий за один ход модели с живым обновлением оверлея, мгновенной проверкой `Ctrl+Alt+X` и опцией `hideOverlayAfter: true`. |
| `mouse_click` | Плавное движение (`SmoothMove`) и клик по координатам (`coordSpace: "image" \| "screen"`). |
| `mouse_move` | Плавное перемещение курсора. |
| `mouse_drag` | Перетаскивание мышью от `(x1, y1)` к `(x2, y2)`. |
| `mouse_path` | Движение по полилинии точек. |
| `mouse_scroll` | Прокрутка колеса; если координаты не заданы, а курсор на другом мониторе — автоматически переносит курсор в центр активного окна. |
| `type_text` | Автоматически выбирает `PasteText` (буфер обмена с восстановлением) для кириллицы/длинных строк и `SendInput` Unicode для короткого ASCII. |
| `key_press` | Хоткеи с выдержкой 14–16 мс между нажатиями; блокирует `Alt+F4`, `Ctrl+W`, `Ctrl+Q` в любом порядке без `allowClose: true`. |

---

## 3. Важные технические решения

- **Мульти-монитор и DPI:** оба PowerShell-процесса вызывают `SetProcessDpiAwarenessContext(-4)` (Per-Monitor DPI Aware V2). `desktop_worker.ps1` определяет монитор активного окна через `Screen.FromHandle(fgHwnd)` и передаёт `originX`, `originY`, `screenWidth`, `screenHeight` в `server.js` и `overlay.ps1`.
- **Безопасный фокус Electron/Discord:** `FocusWindow` использует `SwitchToThisWindow` + `SetForegroundWindow` (без `AttachThreadInput` и лишнего `ShowWindow(SW_SHOW)`), поэтому Electron-приложения не сворачиваются в трей.
- **Потокобезопасный WPF-оверлей:** `overlay.ps1` читает `stdin` в чистом C#-потоке в `ConcurrentQueue<string>`, а WPF `DispatcherTimer` (25 мс) применяет команды в UI-потоке и проверяет `GetAsyncKeyState` на `Ctrl+Alt+X`.
