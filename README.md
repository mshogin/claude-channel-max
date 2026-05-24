# claude-channel-max

MCP server that connects a [Max Messenger](https://max.ru) bot to
[Claude Code](https://code.claude.com), so you can DM your assistant from your
phone and get replies back in the same chat.

Derivative of Anthropic's `claude-channel-telegram` plugin with a Max-specific
transport (`@maxhub/max-bot-api`).

## Status

Alpha, MVP. What works:

- Bot polling via `@maxhub/max-bot-api` (long-polling, single-instance lock)
- Pairing flow with 5-char codes (DM-only, single user)
- Inbound `message_created` delivered as:
  - MCP `notifications/claude/channel` (intended path)
  - File drop in `~/.claude/channels/max/inbox/pending/` (workaround, see below)
- Outbound tools: `reply`, `edit_message`, `download_attachment`

Out of scope for v0: groups, reactions (not supported by Max API), callback
buttons, stickers.

## Claude Code 2.1.150 notification bug - workaround

Claude Code 2.1.150 has open bug #36503: channel notifications from custom
MCP servers are dropped silently. To stay usable, this server writes every
inbound message twice:

1. MCP notification (the intended Claude Code channel path).
2. A JSON file under `~/.claude/channels/max/inbox/pending/`.

The companion poller skill `/max-poll` (shipped in `skills/max-poll/`) reads
the pending directory and surfaces messages to the session. When upstream
fixes the bug, the pending-file path can be turned off; the MCP notification
path already works on its own. See "Workaround skill /max-poll" below.

## Prerequisites

- [Bun](https://bun.sh): `brew install oven-sh/bun/bun` or
  `curl -fsSL https://bun.sh/install | bash`
- A Max bot token from [@MasterBot](https://max.ru/masterbot)
- Claude Code 2.1+

## Install

### Option A — clone and register as an MCP server (recommended for now)

```bash
git clone https://github.com/mshogin/claude-channel-max ~/projects/claude-channel-max
cd ~/projects/claude-channel-max && bun install
claude mcp add max -- bun run ~/projects/claude-channel-max/server.ts
```

This wires `server.ts` into Claude Code as an MCP server named `max`. The
three tools (`reply`, `edit_message`, `download_attachment`) become available
in any session.

### Option B — install as a plugin (with skills)

The earlier plugin layout (with `/max:configure` and `/max:access` slash
commands) is being reworked. TODO: republish as a Claude Code plugin with a
proper `marketplace.json`. For now use Option A and edit `access.json`
manually for first pairing (see below).

## Workaround skill /max-poll

A thin skill that reads `~/.claude/channels/max/inbox/pending/` (where
`server.ts` writes every inbound message), re-validates the sender against
`access.json`, emits one compact JSON line per accepted message, and moves
the file to `processed/`. This is the explicit poll path that compensates
for bug #36503 - until upstream fixes notifications, this is how messages
actually reach the session.

What it produces, one line per inbound:

```
{"c":<chat_id>,"u":<user_id>,"m":"<message_id>","t":"<text>"}
```

Install (from this repo):

```bash
mkdir -p ~/.claude/skills
cp -r skills/max-poll ~/.claude/skills/
```

Or symlink so updates from `git pull` propagate:

```bash
mkdir -p ~/.claude/skills
ln -s "$PWD/skills/max-poll" ~/.claude/skills/max-poll
```

After install the skill lives at `~/.claude/skills/max-poll/`. Invoke
manually:

```
/max-poll
```

For continuous operation see "Live operation via Monitor" below.

## Configure the bot token

```bash
mkdir -p ~/.claude/channels/max
echo "MAX_BOT_TOKEN=<your-token>" > ~/.claude/channels/max/.env
chmod 600 ~/.claude/channels/max/.env
```

The token is read once at boot. After changing it, restart the MCP server
(reopen Claude or run `/reload-plugins`).

## First pairing

1. DM your bot in Max. The bot replies with a 5-char pairing code and drops
   the message.
2. In your Claude session, add your numeric `user_id` to the allowlist. If
   you installed via Option A (no skill), edit `~/.claude/channels/max/access.json`
   by hand:

   ```json
   {
     "allowFrom": [123456789],
     "pending": {}
   }
   ```

   Your `user_id` is the value the bot recorded in `pending.<code>.user_id`
   before it was dropped — it shows up in `server.log` at the `paired`
   line, or inside `access.json` under `pending`.
3. DM the bot again. The message now reaches Claude.

If you have the plugin installed (Option B), run `/max:access pair <code>`
in the Claude session instead of editing JSON.

## State files

| Path | Purpose |
|------|---------|
| `~/.claude/channels/max/.env` | `MAX_BOT_TOKEN=<token>` (chmod 600) |
| `~/.claude/channels/max/access.json` | `{ allowFrom: [...], pending: {...} }` |
| `~/.claude/channels/max/server.log` | Diagnostic log (rotate manually) |
| `~/.claude/channels/max/inbox/pending/` | Inbound messages waiting for the session (workaround for #36503) |
| `~/.claude/channels/max/inbox/processed/` | Messages already delivered to a session |
| `~/.claude/channels/max/inbox/dropped/` | Messages dropped by access policy |
| `~/.claude/channels/max/bot.pid` | Single-instance lock |

`access.json` is re-read on every inbound message; `.env` is read once at
boot.

## Tools exposed to Claude

| Tool | Description |
|------|-------------|
| `reply` | Send a text message to a chat. Optional `reply_to` (mid) for threading. Long replies are auto-split (4000-char chunks). |
| `edit_message` | Edit a message the bot previously sent. Useful for progress updates since Max has no reactions. |
| `download_attachment` | Fetch an attachment URL into the local inbox and return a path the assistant can `Read`. |

Chat IDs are strings (passed through from the inbound `<channel>` block).
Message IDs are Max `mid` strings.

## Architecture differences vs claude-channel-telegram

- Library: `@maxhub/max-bot-api` instead of `grammy`.
- Update type: `message_created` instead of `message:text`.
- Send API: `bot.api.sendMessageToChat(chatId, text, extra)` instead of
  `bot.api.sendMessage`.
- Message IDs are strings (mid), not numbers.
- Attachments: `body.attachments[].payload.url` is a direct HTTP URL — no
  separate `getFile()` round-trip.
- No reactions (Max API does not support them).
- No callback buttons (out of v0 scope).

## Attribution

Derivative of `claude-channel-telegram` (Apache-2.0). See `NOTICE`.

## Running Claude Code with auto-permissions

The phone-driven workflow assumes the bot can act without waiting for the
user to click "Allow" on every Bash/Edit/Write. Launch Claude Code with
permission prompts disabled:

```bash
claude --dangerously-skip-permissions
```

Equivalent long form:

```bash
claude --permission-mode bypassPermissions
```

To make it permanent, set in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

Note: only use this in sessions you trust. It disables every confirmation
prompt for tool execution (Bash, Edit, Write, etc.). If you are processing
inbound messages from Max, the session is effectively driven by a remote
input - keep `allowFrom` tight.

## Live operation via Monitor

To get near-real-time messages without manually invoking `/max-poll`, run a
background loop inside the Claude session that emits one stdout line per
new inbound. The Monitor tool turns each stdout line into a notification,
so idle ticks cost zero tokens.

Option 1 (recommended) - background poll loop in the session:

Ask Claude to run the following as a background bash command (with the
Monitor tool watching the stream):

```bash
while true; do
  bash ~/.claude/skills/max-poll/scripts/max-poll.sh 2>/dev/null \
    | grep --line-buffered '^{"c":'
  sleep 10
done
```

Each JSON line surfaces as a notification; the `max-poll: ...` summary
lines are filtered out so quiet ticks produce no output (and no tokens).

Option 2 - `/loop`-based polling:

```
/loop 60s /max-poll
```

Simple but higher latency (minimum 60 seconds for cron-backed loops).

Option 3 - external cron writing to a file Claude tails:

Overkill for personal use; only worth it if you want a poller to outlive
the Claude session.

## License

Apache-2.0. See `LICENSE`.
