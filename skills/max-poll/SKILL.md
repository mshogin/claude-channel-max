---
name: max-poll
description: Poll new messages from Max Messenger bot (workaround for Claude Code channels bug #36503). Reads ~/.claude/channels/max/inbox/pending/, validates sender is in allowFrom, emits compact JSON to Claude. Use with /loop 5s /max-poll for live operation.
allowed-tools:
  - Bash(bash *)
  - Bash(cat *)
  - Bash(ls *)
  - Bash(mv *)
  - Bash(mkdir *)
---

# /max-poll - Max Channel Polling

Reads new messages from `~/.claude/channels/max/inbox/pending/`, double-checks
sender is approved (re-reads `~/.claude/channels/max/access.json`), emits one
compact JSON line per message, moves files to `processed/`.

**Why this exists**: Claude Code v2.1.150 has open bug
[#36503](https://github.com/anthropics/claude-code/issues/36503) where channel
notifications are dropped silently for custom plugins. This skill bypasses
the broken push path with explicit polling.

## Usage

Manual:
```
/max-poll
```

Live operation (poll every 5 seconds):
```
/loop 5s /max-poll
```

See the project README for an alternative live mode using the Monitor tool
(lower latency, no /loop dependency).

## Output format

For each accepted pending message, one line of compact JSON:

```
{"c":<chat_id>,"u":<user_id>,"m":"<message_id>","t":"<text>"}
```

- `c` = chat_id (number)
- `u` = user_id (number)
- `m` = message_id (string, Max `mid`)
- `t` = text content

Trailing summary line:
```
max-poll: kept=N dropped=M
```

If no pending: `max-poll: no new messages.`

## Reply

The Max MCP server is registered in your `~/.claude.json` (user-scope) after
running `claude mcp add max -- bun run <path>/server.ts`. Reply via:

```
mcp__max__reply(chat_id=<c>, text="...")
```

For threading (quote the original message):
```
mcp__max__reply(chat_id=<c>, text="...", reply_to=<m>)
```

## Files

| Path | Purpose |
|------|---------|
| `~/.claude/channels/max/inbox/pending/<ts>-<mid>.json` | New, awaiting forward |
| `~/.claude/channels/max/inbox/processed/<ts>-<mid>.json` | Already shown to Claude |
| `~/.claude/channels/max/inbox/dropped/<ts>-<mid>.json` | Sender not in allowFrom - security audit |

## Notes

- Skill is safe to run when there are no pending - exits with "no new messages"
- Each pending file is JSON: `{ content: "...", meta: { chat_id, message_id, user, user_id, ts, ... } }`
- Script uses `jq` for parsing (no Python)
- Server only writes pending AFTER access check; skill does a 2nd check
- When Anthropic fixes #36503, this skill becomes obsolete (delete it)

## Communication policy (CRITICAL)

When this skill is active in the session (Monitor running OR /max-poll invoked
at least once) the user is NOT at the IDE - they are on their phone via Max.
All two-way communication MUST go through Max, not the IDE.

**Strict rules:**

1. **NEVER call `AskUserQuestion`.** It renders in IDE only - the user won't
   see it. Decide yourself based on context. If you absolutely cannot decide,
   ask via `mcp__max__reply` instead.

2. **All progress reports go to Max.** Use `mcp__max__reply(chat_id=<c>, text=...)`
   with the most recent `c` from a `<channel source="max" ...>` block. End of
   task -> reply. Mid-task milestone -> reply. Blocked -> reply.

3. **Destructive confirmations** (git push, rm -rf, force-merge, drop table,
   restart shared service) - short message to Max: "Ready to do X. Confirm?"
   Wait for the next inbound via the monitor.

4. **IDE output is for logs only.** Anything you write to stdout in the IDE
   is invisible to the user. Don't put answers/decisions there expecting
   them to be seen.

5. **First inbound = bind chat_id.** Treat `c` from the first inbound of the
   session as the active chat for all outbound. Don't switch chats mid-task
   unless an explicit new inbound from a different chat arrives.
