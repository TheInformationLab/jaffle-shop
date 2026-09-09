# Accepted exceptions

A log of models where a checklist rule in SKILL.md is knowingly not followed, and why. Check this file before flagging a violation — if the model and rule are listed here, note it as an accepted exception in the review output instead of a violation ("Rule 6: not applied — see accepted exception, DE-412").

Do not add an entry yourself just because a rule is hard to satisfy. Only add one when the user explicitly confirms the exception is intentional and tells you to record it. If a rule seems impossible to satisfy but there's no entry here, flag it as a normal violation and say why it's hard — let the user decide whether to fix it or add an exception.

Each entry needs: the model, the rule number, why, and a reference (ticket/PR/person) if one exists. Entries with no reference are still valid — not every exception has a ticket — but should at least name who approved it or when.

## Format

```
### <model_name> — Rule <n>: <short rule name>
- Why: <reason>
- Reference: <ticket/PR link, or "approved by <name>, <date>", or "no reference">
```

## Log

### canvas/top_five_events.sql - Rule leading commas
- Why: demo model which isn't in production
- Reference: Approved by Ollie Clarke, 2026-09-09