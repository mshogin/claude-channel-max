---
name: configure
description: Set up the Max channel — save the bot token and review access policy. Use when the user pastes a Max bot token, asks to configure Max, asks "how do I set this up" or "who can reach me," or wants to check channel status.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash(ls *)
  - Bash(mkdir *)
  - Bash(chmod *)
---

# /max:configure — Max Channel Setup

Writes the bot token to `~/.claude/channels/max/.env` and orients the user on
access policy. The server reads `.env` once at boot, `access.json` on every
inbound message.

Arguments passed: `$ARGUMENTS`

---

## Dispatch on arguments

### No args — status and guidance

Read both state files and give the user a complete picture:

1. **Token** — check `~/.claude/channels/max/.env` for `MAX_BOT_TOKEN`. Show
   set/not-set; if set, show first 10 chars masked (`f9LHodD0cO...`).

2. **Access** — read `~/.claude/channels/max/access.json` (missing file =
   defaults: empty allowlist). Show:
   - Allowed user_ids: count, list
   - Pending pairings: count, with codes + user_id + age

3. **What next** — concrete next step based on state:
   - No token → *"Run `/max:configure <token>` with the token from Master Bot
     (https://max.ru/masterbot)."*
   - Token set, allowFrom empty → *"DM your bot on Max. It replies with a
     code; approve with `/max:access pair <code>`."*
   - Token set, someone allowed → *"Ready. DM your bot to reach the
     assistant."*

### `<token>` — save it

1. Treat `$ARGUMENTS` as the token (trim whitespace). Master Bot tokens are
   long base64-like strings (~70+ chars).
2. `mkdir -p ~/.claude/channels/max`
3. Read existing `.env` if present; update/add `MAX_BOT_TOKEN=<value>` line,
   preserve other keys. Write back, no quotes around the value.
4. `chmod 600 ~/.claude/channels/max/.env` — the token is a credential.
5. Confirm, then show the no-args status so the user sees where they stand.

### `clear` — remove the token

Delete the `MAX_BOT_TOKEN=` line (or the file if that's the only line).

---

## Implementation notes

- The channels dir might not exist if the server hasn't run yet. Missing file
  = not configured, not an error.
- The server reads `.env` once at boot. Token changes need a session restart
  or `/reload-plugins`. Say so after saving.
- `access.json` is re-read on every inbound message — `/max:access` changes
  take effect immediately, no restart.
- Max API differences vs Telegram:
  - No groups (DM-only v0)
  - No reactions
  - No callback buttons (v0)
  - User IDs are integers (numeric), not strings
  - Message IDs are strings (mid), not numbers
