---
name: register-event-id
description: Use when the user asks to add an event ID. Reserves the next free ID in the correct severity range and updates the registry.
---

Reserve the next free ID in the `1xxx` info / `2xxx` warn / `3xxx` error range, update the Event ID registry table in `CLAUDE.md`, and emit a `Write-EventLogEntry` snippet the caller can paste into the relevant function with the new ID, level, and message template filled in.
