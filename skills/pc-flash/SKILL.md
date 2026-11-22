---
name: pc-flash
description: Быстрое управление ПК через Flash-субагент (оптимально для кликов и навигации)
---

# `/pc-flash` — Быстрое управление Windows через Flash-субагент

Делегируй задачу управления ПК субагенту `desktop-operator` на модели **`flash`**:
1. Если `desktop-operator` ещё не определён в этом диалоге, вызови `define_subagent` (`Name: "desktop-operator"`, `EnableMCPTools: true`, `EnableWriteTools: false`) с инструкцией использовать `windows-desktop` MCP, `batch_actions`, не закрывать окна без просьбы, проверять результат и скрывать оверлей в конце.
2. Запусти `invoke_subagent(TypeName="desktop-operator", Role="Desktop Operator (Flash)", Model="flash", Prompt=...)` с чётким описанием задачи и условием завершения.
3. Дождись ответа субагента и передай краткий честный итог пользователю.
