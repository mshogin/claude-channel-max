#!/bin/bash
# max-poll - read pending Max messages, security-check sender, emit compact
# JSON one-line-per-message to stdout. Claude replies via mcp__max__reply.
set -uo pipefail

CHANNELS_DIR="$HOME/.claude/channels/max"
PENDING_DIR="$CHANNELS_DIR/inbox/pending"
PROCESSED_DIR="$CHANNELS_DIR/inbox/processed"
DROPPED_DIR="$CHANNELS_DIR/inbox/dropped"
ACCESS_FILE="$CHANNELS_DIR/access.json"

mkdir -p "$PENDING_DIR" "$PROCESSED_DIR" "$DROPPED_DIR"

if [ ! -f "$ACCESS_FILE" ]; then
    echo "ERROR: $ACCESS_FILE not found. Bot not paired yet." >&2
    exit 1
fi

# Defense-in-depth: re-read allowFrom from disk.
ALLOWED_JSON=$(jq -c '.allowFrom // []' "$ACCESS_FILE" 2>/dev/null || echo '[]')
ALLOWED_COUNT=$(jq 'length' <<< "$ALLOWED_JSON")

if [ "$ALLOWED_COUNT" -eq 0 ]; then
    echo "ERROR: access.json allowFrom is empty. DM bot first and run /max:access pair." >&2
    exit 1
fi

shopt -s nullglob
FILES=("$PENDING_DIR"/*.json)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo "max-poll: no new messages."
    exit 0
fi

KEPT=0
DROPPED=0
LINES=()
for f in "${FILES[@]}"; do
    USER_ID=$(jq -r '.meta.user_id // empty' "$f" 2>/dev/null)

    if [ -z "$USER_ID" ]; then
        echo "DROP (no user_id): $(basename "$f")" >&2
        mv "$f" "$DROPPED_DIR/"
        DROPPED=$((DROPPED + 1))
        continue
    fi

    if ! jq -e --argjson uid "$USER_ID" '. | map(tostring) | index($uid | tostring)' <<< "$ALLOWED_JSON" >/dev/null; then
        echo "DROP (user_id=$USER_ID NOT in allowFrom): $(basename "$f")" >&2
        mv "$f" "$DROPPED_DIR/"
        DROPPED=$((DROPPED + 1))
        continue
    fi

    # Compact JSON: c=chat_id, u=user_id, m=message_id, t=text
    LINE=$(jq -c '{c: (.meta.chat_id|tonumber? // .meta.chat_id), u: (.meta.user_id|tonumber? // .meta.user_id), m: .meta.message_id, t: .content}' "$f" 2>/dev/null)

    if [ -z "$LINE" ]; then
        echo "DROP (jq parse failed): $(basename "$f")" >&2
        mv "$f" "$DROPPED_DIR/"
        DROPPED=$((DROPPED + 1))
        continue
    fi

    LINES+=("$LINE")
    mv "$f" "$PROCESSED_DIR/"
    KEPT=$((KEPT + 1))
done

if [ $KEPT -gt 0 ]; then
    printf '%s\n' "${LINES[@]}"
fi

echo "max-poll: kept=$KEPT dropped=$DROPPED"
