#!/bin/bash
# Claude Code notification hook.
# Generates a short topic via Haiku (cached per session), falls back to first message.
# Clicking the notification activates your terminal app.
# To make sticky: System Settings > Notifications > terminal-notifier > Alerts

# Guard against recursive hook calls
if [ -n "$CLAUDE_NOTIFY_RUNNING" ]; then
  exit 0
fi
export CLAUDE_NOTIFY_RUNNING=1

# Resolve plugin root (directory containing this script)
PLUGIN_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Load defaults, then user overrides
source "$PLUGIN_ROOT/config.defaults.sh"
if [ -f "$HOME/.claude/notify-config.sh" ]; then
  source "$HOME/.claude/notify-config.sh"
fi

# Auto-detect terminal app bundle ID if not set
if [ -z "$NOTIFY_TERMINAL_APP" ]; then
  case "${TERM_PROGRAM:-}" in
    ghostty)      NOTIFY_TERMINAL_APP="com.mitchellh.ghostty" ;;
    iTerm.app)    NOTIFY_TERMINAL_APP="com.googlecode.iterm2" ;;
    Apple_Terminal) NOTIFY_TERMINAL_APP="com.apple.Terminal" ;;
    WezTerm)      NOTIFY_TERMINAL_APP="com.github.wez.wezterm" ;;
    vscode)       NOTIFY_TERMINAL_APP="com.microsoft.VSCode" ;;
    Alacritty)    NOTIFY_TERMINAL_APP="org.alacritty" ;;
    tmux)         NOTIFY_TERMINAL_APP="com.mitchellh.ghostty" ;; # common default
    *)            NOTIFY_TERMINAL_APP="com.apple.Terminal" ;;
  esac
fi

# Check for terminal-notifier
if ! command -v terminal-notifier &>/dev/null; then
  echo "notify plugin: terminal-notifier not found. Install with: brew install terminal-notifier" >&2
  exit 1
fi

# Parse hook input from stdin
INPUT=$(cat)

MESSAGE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','Needs your attention'))" 2>/dev/null)
TYPE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('notification_type',d.get('hook_event_name','')))" 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)

MESSAGE="${MESSAGE:-Needs your attention}"

# Cache directory for generated topics
CACHE_DIR="$HOME/.claude/.topic-cache"
mkdir -p "$CACHE_DIR"

TOPIC=""

# Check cache first
if [ -n "$SESSION_ID" ] && [ -f "$CACHE_DIR/$SESSION_ID" ]; then
  TOPIC=$(cat "$CACHE_DIR/$SESSION_ID")
fi

# Generate topic if not cached and enabled
if [ -z "$TOPIC" ] && [ "$NOTIFY_TOPIC_ENABLED" = "true" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # Extract first user message
  FIRST_MSG=$(python3 -c "
import json
with open('$TRANSCRIPT') as f:
    for line in f:
        d = json.loads(line)
        if d.get('type') == 'user':
            msg = d.get('message', {})
            content = msg.get('content', '') if isinstance(msg, dict) else str(msg)
            if isinstance(content, str):
                text = content.strip()
            elif isinstance(content, list):
                text = next((b['text'] for b in content if isinstance(b, dict) and b.get('type') == 'text'), '')
            else:
                text = ''
            print(text[:200])
            break
" 2>/dev/null)

  if [ -n "$FIRST_MSG" ]; then
    # Try to generate a short topic with Haiku via claude CLI
    TOPIC=$(echo "$FIRST_MSG" | env -u CLAUDECODE CLAUDE_NOTIFY_RUNNING=1 claude -p --model "$NOTIFY_TOPIC_MODEL" "Summarize the following user message in 5 words or fewer as a short topic title. Output ONLY the title, nothing else." 2>/dev/null | head -1)

    # Fall back to truncated first message
    if [ -z "$TOPIC" ]; then
      TOPIC="${FIRST_MSG:0:60}"
    fi

    # Cache the topic
    if [ -n "$SESSION_ID" ] && [ -n "$TOPIC" ]; then
      echo "$TOPIC" > "$CACHE_DIR/$SESSION_ID"
    fi
  fi
fi

# Event type as part of title
case "$TYPE" in
  permission_prompt) TITLE="Claude Code — Permission" ;;
  idle_prompt)       TITLE="Claude Code — Input" ;;
  auth_success)      TITLE="Claude Code — Auth" ;;
  Stop)              TITLE="Claude Code — Done" ;;
  *)                 TITLE="Claude Code" ;;
esac

ARGS=(-title "$TITLE" -message "$MESSAGE" -sound "$NOTIFY_SOUND" -activate "$NOTIFY_TERMINAL_APP" -group "$NOTIFY_GROUP")

if [ -n "$TOPIC" ]; then
  ARGS+=(-subtitle "$TOPIC")
fi

terminal-notifier "${ARGS[@]}"
