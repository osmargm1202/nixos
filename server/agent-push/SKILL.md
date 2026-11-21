---
name: agent-push
description: Send a phone notification when the owner must answer a blocking question or a requested agent loop reaches its completion condition.
---

- Before asking a question that blocks progress, run `~/.local/bin/agent-push question "Resumen breve de la pregunta"`. Ask the full question in the current chat and wait if it blocks further work.
- When the requested loop or goal reaches its completion condition, run `~/.local/bin/agent-push done "Resumen breve del resultado"` once and post the full result in the current chat.
- Use short messages in the user's language. Leave credentials and sensitive details in the current chat. If delivery fails, report that in the chat and only retry if you can tell the request did not reach the server.
