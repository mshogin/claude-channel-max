# claude-channel-max

Connect a [Max Messenger](https://max.ru) bot to [Claude Code](https://code.claude.com)
via the `channels` mechanism. v0.1.0 — minimal MVP (DM-only, single-user).

Mirrors the architecture of the official `claude-channel-telegram` plugin
with a Max-specific transport (`@maxhub/max-bot-api`).

## Status

v0.1.0 — minimal MVP. Implements:

- Bot polling via `@maxhub/max-bot-api` (long-polling, single-instance lock)
- Pairing flow with codes (DM-only)
- Inbound: `message_created` → MCP `notifications/claude/channel`
- Outbound tools: `reply`, `edit_message`, `download_attachment`
- Skills: `/max:access`, `/max:configure`

## Scope (v0)

- DM-only pairing (single-user)
- Long-polling (no webhooks)
- Text messages + attachments (URL-based)

## Non-scope (v0)

- Groups / multi-user (Max API supports groups, not yet wired)
- Reactions (not supported by Max API)
- Inline keyboards / callback buttons (not wired in v0)
- Stickers (not supported by Max API)

## Install

### Prerequisites

- [Bun](https://bun.sh) (`brew install oven-sh/bun/bun` or `curl -fsSL https://bun.sh/install | bash`)
- A Max bot token from [@MasterBot](https://max.ru/masterbot)
- Claude Code v2.1.80+ (channels capability)

### Add the marketplace

```bash
claude plugin marketplace add mshogin/claude-channel-max
```

### Install the plugin

```bash
claude plugin install max@claude-channel-max
```

### Configure the token

```bash
claude /max:configure <your-bot-token>
```

This writes the token to `~/.claude/channels/max/.env`.

### Run Claude with the channel enabled

```bash
claude --channels plugin:max@claude-channel-max
```

### First message — pairing

DM your bot in Max. The bot will reply with a pairing code:

```
Pairing required — run in Claude Code:

/max:access pair <code>
```

Run that command in your Claude session. The next DM you send the bot will
reach Claude as a `<channel source="max" ...>` block, and Claude can reply
back via the `reply` tool.

## State and configuration

| Path | Purpose |
|------|---------|
| `~/.claude/channels/max/.env` | `MAX_BOT_TOKEN=<token>` (chmod 600) |
| `~/.claude/channels/max/access.json` | `{ allowFrom: [user_id], pending: {...} }` |
| `~/.claude/channels/max/server.log` | Diagnostic log (rotate manually) |
| `~/.claude/channels/max/inbox/` | Downloaded attachments |
| `~/.claude/channels/max/bot.pid` | Single-instance lock |

`access.json` is re-read on every inbound message; `.env` is read once at
boot.

## Tools exposed to Claude

| Tool | Description |
|------|-------------|
| `reply` | Send a text message to a chat. Optional `reply_to` (mid) for threading. |
| `edit_message` | Edit a message the bot previously sent (good for progress updates). |
| `download_attachment` | Fetch an attachment URL into the local inbox. |

All chat IDs are passed as strings (the inbound `<channel>` block carries them
as `chat_id="<int>"`). Message IDs are Max's `mid` strings.

## Architecture differences vs `claude-channel-telegram`

- **Library**: `@maxhub/max-bot-api` (vs `grammy`)
- **Update type**: `message_created` (vs `message:text` and friends)
- **Send API**: `bot.api.sendMessageToChat(chatId, text, extra)` (vs `bot.api.sendMessage`)
- **Message IDs**: strings (mid) (vs numbers)
- **Attachments**: `body.attachments[].payload.url` — direct HTTP fetch (vs `getFile()` + `https://api.telegram.org/file/...`)
- **No reactions**: Max API doesn't support them
- **No callback buttons**: v0 scope

## Attribution

Derivative of `claude-channel-telegram` (Apache-2.0). See `NOTICE`.

## License

Apache-2.0. See `LICENSE`.
