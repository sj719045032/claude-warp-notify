#!/bin/bash
# Claude Code Warp Notification Installer
# Sends macOS notifications when Claude Code completes a task and Warp is not in focus.
# Click the notification to switch back to Warp.
#
# Usage: bash install.sh
# Uninstall: bash install.sh --uninstall

set -e

NOTIFY_DIR="$HOME/.claude/notify"
APP_DIR="$NOTIFY_DIR/ClaudeNotify.app"
SETTINGS="$HOME/.claude/settings.json"

# --- Uninstall ---
if [ "$1" = "--uninstall" ]; then
    echo "Removing notification app..."
    rm -rf "$APP_DIR"
    rm -f "$NOTIFY_DIR/send-notification.sh"
    rm -f "$NOTIFY_DIR/ClaudeNotify.swift"
    echo "Note: You may want to remove the Notification/Stop hooks from $SETTINGS manually."
    echo "Done!"
    exit 0
fi

echo "==> Installing Claude Code Warp Notification..."

# --- Check dependencies ---
if ! command -v swiftc &>/dev/null; then
    echo "Error: Xcode Command Line Tools required. Run: xcode-select --install"
    exit 1
fi

if ! [ -d "/Applications/Warp.app" ]; then
    echo "Error: Warp.app not found in /Applications"
    exit 1
fi

mkdir -p "$NOTIFY_DIR"
mkdir -p "$HOME/.claude"

# Save install script for later uninstall
SELF_SCRIPT="$(cat "$0" 2>/dev/null || curl -fsSL https://raw.githubusercontent.com/sj719045032/claude-warp-notify/main/install.sh 2>/dev/null)"
if [ -n "$SELF_SCRIPT" ]; then
    echo "$SELF_SCRIPT" > "$NOTIFY_DIR/install.sh"
    chmod +x "$NOTIFY_DIR/install.sh"
fi

# --- Write Swift source ---
cat > "$NOTIFY_DIR/ClaudeNotify.swift" << 'SWIFT'
import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let message: String
    let titleText: String

    init(message: String, titleText: String) {
        self.message = message
        self.titleText = titleText
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                self.sendNotification()
            } else {
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
        }
    }

    func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = titleText
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-a", "Warp"])
        completionHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

if CommandLine.arguments.count <= 1 {
    Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-a", "Warp"])
    exit(0)
}
let msg = CommandLine.arguments[1]
let ttl = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Claude Code"
let delegate = AppDelegate(message: msg, titleText: ttl)
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
SWIFT

# --- Build app bundle ---
echo "==> Building app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Write Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.claude-code.notify</string>
    <key>CFBundleName</key>
    <string>Claude Code</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeNotify</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

# Use Warp icon for the notification app
cp "/Applications/Warp.app/Contents/Resources/Warp.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Compile
swiftc -o "$APP_DIR/Contents/MacOS/ClaudeNotify" "$NOTIFY_DIR/ClaudeNotify.swift" \
    -framework Cocoa -framework UserNotifications 2>&1

# Register and sign
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$APP_DIR"
codesign --force --sign - "$APP_DIR" 2>/dev/null

echo "==> App built at $APP_DIR"

# --- Write hook script ---
cat > "$NOTIFY_DIR/send-notification.sh" << 'HOOKSCRIPT'
#!/bin/bash
FRONT_APP=$(lsappinfo info -only name $(lsappinfo front) 2>/dev/null)
if echo "$FRONT_APP" | grep -q '"Warp"'; then
    exit 0
fi
INPUT=$(cat)
eval "$(echo "$INPUT" | python3 -c "
import sys, json, shlex, os
d = json.load(sys.stdin)
msg = d.get('last_assistant_message') or d.get('message') or d.get('notification_data',{}).get('message') or 'Claude Code 任务完成'
if len(msg) > 200: msg = msg[:200] + '…'
cwd = d.get('cwd', '')
home = os.path.expanduser('~')
if cwd.startswith(home): cwd = '~' + cwd[len(home):]
print(f'MESSAGE={shlex.quote(msg)}')
print(f'PROJECT={shlex.quote(cwd)}')
" 2>/dev/null)"
TITLE="Claude Code"
[ -n "$PROJECT" ] && TITLE="Claude Code · $PROJECT"
pkill -f ClaudeNotify 2>/dev/null
open ~/.claude/notify/ClaudeNotify.app --args "$MESSAGE" "$TITLE"
HOOKSCRIPT
chmod +x "$NOTIFY_DIR/send-notification.sh"

# --- Configure hooks in settings.json ---
echo "==> Configuring hooks..."
mkdir -p "$(dirname "$SETTINGS")"
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

HOOK_CMD="bash ~/.claude/notify/send-notification.sh"

# Check if hooks already configured
if grep -q "send-notification.sh" "$SETTINGS" 2>/dev/null; then
    echo "    Hooks already configured, skipping."
else
    python3 -c "
import json

with open('$SETTINGS') as f:
    cfg = json.load(f)

hook_entry = {
    'matcher': '',
    'hooks': [{'type': 'command', 'command': '$HOOK_CMD'}]
}

hooks = cfg.setdefault('hooks', {})
for event in ['Notification', 'Stop']:
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
echo "    First notification will ask for macOS notification permission — click Allow."
echo ""
echo "    Uninstall: bash $NOTIFY_DIR/install.sh --uninstall"
