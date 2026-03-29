#!/bin/bash
# Claude Code Warp Notification Installer
# Sends desktop notifications via Warp's OSC 777 when Claude Code completes a task.
#
# Usage: bash install.sh
# Uninstall: bash install.sh --uninstall

set -e

NOTIFY_DIR="$HOME/.claude/notify"
SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$NOTIFY_DIR/send-notification.sh"

# --- Uninstall ---
if [ "$1" = "--uninstall" ]; then
    echo "Removing notification script..."
    rm -rf "$NOTIFY_DIR"
    echo "Note: You may want to remove the Notification/Stop hooks from $SETTINGS manually."
    echo "Done!"
    exit 0
fi

echo "==> Installing Claude Code Warp Notification..."

# --- Check dependencies ---
if ! [ -d "/Applications/Warp.app" ]; then
    echo "Error: Warp.app not found in /Applications"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Run: brew install jq"
    exit 1
fi

mkdir -p "$NOTIFY_DIR"
mkdir -p "$HOME/.claude"

# --- Write hook script ---
cat > "$HOOK_SCRIPT" << 'HOOKSCRIPT'
#!/bin/bash
EVENT_TYPE="${1:-stop}"

# Warp 在前台时不发通知
FRONT_APP=$(lsappinfo info -only name $(lsappinfo front) 2>/dev/null)
if echo "$FRONT_APP" | grep -q '"Warp"'; then
  exit 0
fi

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '
  ((.last_assistant_message // .message // (.notification_data // {}).message) // "Claude Code 任务完成")
  | .[0:200] | gsub("[;\\n\\r]"; " ")')
PROJECT=$(echo "$INPUT" | jq -r --arg h "$HOME" '
  (.cwd // "") | if startswith($h) then "~" + .[$h | length:] else . end')

if [ "$EVENT_TYPE" = "notification" ]; then
  TITLE="Claude Code · 等待确认"
else
  TITLE="Claude Code · 任务完成"
fi
[ -n "$PROJECT" ] && TITLE="$TITLE · $PROJECT"

printf '\033]777;notify;%s;%s\007' "$TITLE" "$MESSAGE" > /dev/tty 2>/dev/null
HOOKSCRIPT
chmod +x "$HOOK_SCRIPT"

# --- Configure hooks in settings.json ---
echo "==> Configuring hooks..."
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

if grep -q "send-notification.sh" "$SETTINGS" 2>/dev/null; then
    echo "    Hooks already configured, skipping."
else
    python3 -c "
import json

with open('$SETTINGS') as f:
    cfg = json.load(f)

hooks = cfg.setdefault('hooks', {})
for event in ['Notification', 'Stop']:
    cmd = 'bash ~/.claude/notify/send-notification.sh ' + event.lower()
    hook_entry = {
        'matcher': '',
        'hooks': [{'type': 'command', 'command': cmd}]
    }
    existing = hooks.get(event, [])
    existing.append(hook_entry)
    hooks[event] = existing

with open('$SETTINGS', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
" 2>/dev/null
    echo "    Added Notification and Stop hooks."
fi

# --- Done ---
echo ""
echo "==> Installation complete!"
echo "    Restart Claude Code for hooks to take effect."
echo ""
echo "    Uninstall: bash install.sh --uninstall"
