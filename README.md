# Claude Code Warp Notify

Desktop notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) when running in [Warp](https://www.warp.dev/) terminal, powered by Warp's native [OSC 777](https://docs.warp.dev/features/notifications#custom-notification-hooks-osc-9--osc-777) support.

When Claude Code finishes a task and Warp is **not** in the foreground, you get a notification with:

- **Event type** in the title (task complete / waiting for input)
- **Project path** in the title
- **Last message** from Claude as the body
- **Click to focus** Warp window

No notification when Warp is already focused — no interruptions while you're actively working.

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

After installing, **restart Claude Code** for hooks to take effect.

## Requirements

- macOS / Linux / Windows (where Warp supports notifications)
- [Warp](https://www.warp.dev/) terminal
- [jq](https://jqlang.github.io/jq/) (macOS: `brew install jq` or pre-installed on newer versions)

## How it works

The installer:

1. Creates a hook script (`~/.claude/notify/send-notification.sh`) that extracts message and project path from Claude Code's hook JSON via `jq`
2. Sends a desktop notification using Warp's OSC 777 escape sequence (`\033]777;notify;<title>;<body>\007`)
3. Registers `Notification` and `Stop` hooks in `~/.claude/settings.json`

No compilation, no signing, no extra apps — just a single shell script.

## Uninstall

```bash
bash install.sh --uninstall
```

Then remove the `Notification` and `Stop` hook entries from `~/.claude/settings.json`.

## License

MIT
