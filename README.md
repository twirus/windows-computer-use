# Windows Computer Use for Antigravity

[![Release](https://img.shields.io/github/v/release/twirus/windows-computer-use?style=flat-square)](https://github.com/twirus/windows-computer-use/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/twirus/windows-computer-use/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/twirus/windows-computer-use/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](./LICENSE)

Полноценный MCP-сервер для управления Windows из **Antigravity** в стиле Claude Computer Use — с нативным Windows UI Automation, разметкой Set-of-Mark, зумом мелких областей, поддержкой нескольких мониторов и минималистичным WPF-оверлеем.

> **Ноль внешних зависимостей:** не требует Python, `pip`, `npm install` или .NET SDK — только встроенный Windows PowerShell 5.1 и Node.js 18+.

---

## Установка за 1 минуту

### Требования
- **Windows 10 / 11**
- **[Node.js 18+ LTS](https://nodejs.org/)**
- **Antigravity**

### Быстрая установка (рекомендуется)
1. Скачайте последний `windows-computer-use-antigravity.zip` со страницы **[Releases](https://github.com/twirus/windows-computer-use/releases/latest)**.
2. Распакуйте архив и запустите **`install.bat`** (двойным кликом).
3. Перезапустите **Antigravity**.
4. При первом вызове инструмента `windows-desktop` выберите **Always allow** и используйте команды `/pc`, `/pc-flash` или `/pc-pro` в чате.

> Для удаления достаточно запустить **`uninstall.bat`** из того же архива.

---

## Возможности

- **Windows UI Automation + Set-of-Mark (`desktop_state`)** — читает нативное дерево кнопок, полей, вкладок и панели задач, рисует пронумерованные рамки `[1]`, `[2]`, ... на скриншоте для агента.
- **Точные действия по элементам (`click_element`, `type_into_element`)** — авто-возврат фокуса нужному окну перед кликом и 100% надёжная вставка кириллицы/Unicode через буфер обмена с восстановлением.
- **Приближение мелких объектов (`zoom_region`)** — 2.5× зум области с координатной сеткой реальных пикселей для игр, Canvas и мелких иконок.
- **Быстрые серии действий (`batch_actions`)** — выполнение цепочек из 10–30 действий за один ход модели с живым обновлением оверлея на каждом шаге.
- **Полноценный мульти-монитор** — автоматически работает на мониторе активного окна (включая отрицательные координаты `X < 0`) с учётом разного DPI.
- **Минималистичный WPF-оверлей (`overlay.ps1`)**:
  - тонкая тёплая рамка `2.5px` по периметру активного монитора;
  - компактная верхняя плашка с подробным статусом текущего действия;
  - тонкое кольцо-ореол и плавающий бейдж рядом с реальным курсором Windows (без наложения второй стрелки) + волны при кликах;
  - полностью кликабельный насквозь (`WS_EX_TRANSPARENT | WS_EX_NOACTIVATE`);
  - экстренная остановка **`Ctrl+Alt+X`** (мгновенно прерывает даже середину `batch_actions`).
- **Защита от случайного закрытия приложений** — `Alt+F4`, `Ctrl+W`, `Ctrl+Q` (в любом порядке клавиш) и клики по кнопке `Закрыть`/`Close` заблокированы без явного флага подтверждения.
- **Команды в чате Antigravity:**
  - `/pc` — управление ПК напрямую в этом чате (без субагента, по умолчанию)
  - `/pc-flash` — быстрое управление через Flash-субагент
  - `/pc-pro` — сложное управление через Pro-субагент

---

## Структура проекта

```text
windows-computer-use/
├── src/
│   ├── server.js            # MCP-сервер (JSON-RPC 2.0, 20 инструментов, оркестратор)
│   ├── desktop_worker.ps1   # Воркер на C#/PowerShell (UIA, SoM, Zoom, SendInput, Clipboard)
│   └── overlay.ps1          # WPF-оверлей (рамка, плашка статуса, бейдж курсора, ripple)
├── skills/                  # Скиллы Antigravity (/pc, /pc-flash, /pc-pro, playbook)
├── installer/               # Автоустановщик/удалялка в 1 клик (install.bat / uninstall.bat)
├── scripts/                 # Скрипты сборки релизного ZIP и синхронизации скиллов
├── tests/                   # Автотесты MCP-протокола, защит и завершения процессов
├── .github/workflows/       # GitHub Actions (CI на Windows + автопубликация релизов)
├── ARCHITECTURE.md          # Подробная техническая документация
├── CHANGELOG.md             # История изменений
├── ROADMAP.md               # План будущих улучшений
└── GEMINI.md                # Инструкции для AI-агента при работе над этим проектом
```

---

## Разработка и автопубликация обновлений

```powershell
# Проверка синтаксиса server.js
npm run check

# Запуск автотестов (MCP протокол, защиты от закрытия, батчи, чистый exit без зомби)
npm test

# Синхронизация скиллов из skills/ в ~/.gemini/config/skills/
npm run sync-skills

# Сборка чистого ZIP-архива для распространения (dist/windows-computer-use-antigravity.zip)
npm run build
```

### Как выпустить обновление
При пуше в ветку `main` с обновлённой версией `version` в `package.json`:
1. GitHub Actions автоматически прогоняет `npm run check` и `npm test` на `windows-latest`.
2. Если тега `v<version>` ещё нет, автоматически собирает `windows-computer-use-antigravity.zip`, создаёт тег и публикует новый **GitHub Release** с прикреплённым архивом.

> **Важно:** после локальной правки файлов в `src/` перезапустите MCP-сервер `windows-desktop` (или Antigravity), чтобы подхватились изменения.

---

## Документация

- [ARCHITECTURE.md](./ARCHITECTURE.md) — подробная архитектура, список всех 20 инструментов и подводные камни Win32/WPF/Electron.
- [CHANGELOG.md](./CHANGELOG.md) — история версий.
- [ROADMAP.md](./ROADMAP.md) — запланированные улучшения.
- [GEMINI.md](./GEMINI.md) — правила разработки для AI-агента.
