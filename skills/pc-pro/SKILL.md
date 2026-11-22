---
name: pc-pro
description: Сложное управление ПК через Pro-субагент (игры, мелкий интерфейс, сложная логика)
---

# `/pc-pro` — Умное управление Windows через Pro-субагент

Делегируй задачу управления ПК субагенту `desktop-operator` на модели **`pro`**:
1. Если `desktop-operator` ещё не определён в этом диалоге, вызови `define_subagent` (`Name: "desktop-operator"`, `EnableMCPTools: true`, `EnableWriteTools: false`) с инструкцией использовать `windows-desktop` MCP, `desktop_state`, `batch_actions`, не закрывать окна без просьбы, проверять результат и скрывать оверлей в конце.
2. Запусти `invoke_subagent(TypeName="desktop-operator", Role="Desktop Operator (Pro)", Model="pro", Prompt=...)` с чётким описанием задачи и условием завершения.
3. Дождись ответа субагента и передай краткий честный итог пользователю.
