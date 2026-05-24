# v1 MVP: DM + long-polling + text/attach/edit + bot-to-bot

## Context

We're porting `claude-channel-telegram` to Max Messenger. The scaffold
is already in place (initial commit) as a direct fork. This issue
tracks the implementation work to make it functional.

Research report: see `research/max-bot-integration.md` in geniearchi
for full API survey, feature-parity matrix, and rationale for the
forking approach over a unified bus.

## Scope

1. Replace `grammy` (Telegram Bot API) with `@maxhub/max-bot-api`
   across `server.ts`.
2. Long-polling transport (not webhook for v1).
3. Single-user DM pairing, mirroring Telegram's `/start` and allowlist
   flow (`ACCESS.md`).
4. Tools exposed to Claude Code:
   - `reply(chat_id, text, reply_to?, files?)`
   - `edit_message(chat_id, message_id, text)`
   - `download_attachment(file_id)` -> local path
5. Chunking at 4000 chars (Max limit), vs 4096 in Telegram.
6. 24-hour edit window (Max constraint) vs effectively unlimited in
   Telegram — fail gracefully when edit is rejected.
7. Bot-to-bot communication support (see Bot-to-bot section below).

## Non-scope

- Groups / multi-user (v2)
- Webhook transport (v2)
- Reactions tool (Max API does not support)
- Stickers

## Bot-to-bot

The Telegram plugin drops or ignores messages from other bots to
prevent loops. For this plugin we want to explicitly support
bot-to-bot:

- Add config flag `allow_bot_sender: boolean` (default: false).
- When enabled, incoming messages where `from.is_bot === true` are
  forwarded to Claude Code as normal `<channel>` events, with a
  `bot_sender=true` attribute so Claude can reason about the source.
- Add a per-sender allowlist so only specific bots can interact
  (prevent random bots from pinging us): `bot_allowlist: [bot_username]`.
- Self-filter still applies: we never process our own messages.
- Document the loop-safety considerations in ACCESS.md.

## Acceptance criteria

- [ ] `bun install && bun server.ts` starts the server without errors
      given a valid `MAX_BOT_TOKEN` env.
- [ ] `/start` command in DM triggers pairing; allowlist is persisted.
- [ ] Message in DM is forwarded to Claude Code as a `<channel>` tag.
- [ ] `reply` tool sends a message that arrives in the bot DM.
- [ ] `edit_message` succeeds within 24h, fails cleanly after.
- [ ] `download_attachment` fetches a file and returns its local path.
- [ ] A second (allowlisted) bot can send a message, and Claude receives
      it with `bot_sender=true`.
- [ ] A non-allowlisted bot is silently dropped.
- [ ] README updated with Max-specific setup steps.

## Open questions

- Max SDK version and API shape — verify `@maxhub/max-bot-api` against
  the Max docs at `dev.max.ru/docs-api` before starting; if the SDK is
  immature, fall back to raw HTTP against `platform-api.max.ru`.
- Attachment size cap — Max may differ from Telegram's 20MB.
- Whether Max supports "typing" indicator or similar UX signals.

## Implementation notes

- Keep the structural shape of `server.ts` identical to Telegram's.
  Only swap the transport-specific calls. Reuse pairing, allowlist,
  chunking, session state logic unchanged.
- Preserve the MCP tool surface exactly where possible — Claude Code
  should be able to use Max and Telegram interchangeably for the
  common tools.
- Update `skills/access/SKILL.md` and `skills/configure/SKILL.md` to
  replace "Telegram" with "Max" and adjust the BotFather-style setup
  flow to Max's bot creation flow.
