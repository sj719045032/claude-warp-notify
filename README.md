# Claude Code Warp Notify

macOS native notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) when running in [Warp](https://www.warp.dev/) terminal.

When Claude Code finishes a task and Warp is **not** in the foreground, you get a notification with:

- **Claude icon** on the notification
- **Project path** in the title
- **Last message** from Claude as the body
- **Click to switch** back to Warp

No notification is sent when Warp is already focused — no interruptions while you're actively working.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sj719045032/claude-warp-notify/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/sj719045032/claude-warp-notify.git
cd claude-warp-notify
bash install.sh
```

After installing, **restart Claude Code** for hooks to take effect. The first notification will ask for macOS notification permission — click **Allow**.

## Requirements

- macOS
- [Warp](https://www.warp.dev/) terminal
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3 (pre-installed on macOS)

## How it works

The installer:

1. Compiles a lightweight native macOS app (`ClaudeNotify.app`) that sends notifications via `UserNotifications` framework
2. Creates a hook script that extracts the project path and last message from Claude Code's hook JSON
3. Registers `Notification` and `Stop` hooks in `~/.claude/settings.json`

The notification icon uses Claude.app's icon if installed, otherwise falls back to Warp's icon.

## Uninstall

```bash
bash ~/.claude/notify/install.sh --uninstall
```

Then remove the `Notification` and `Stop` hook entries from `~/.claude/settings.json`.

## License

MIT
