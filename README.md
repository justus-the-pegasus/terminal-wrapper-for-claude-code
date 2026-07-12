# Terminal Wrapper for Claude Code

A lightweight macOS app that opens a project folder and launches [Claude Code](https://docs.claude.com/claude-code) in an embedded terminal — no separate terminal app required.

## Download

[⬇️ Download the latest .dmg](https://github.com/justus-the-pegasus/terminal-wrapper-for-claude-code/releases/latest/download/Terminal.Wrapper.for.Claude.Code.dmg)

Open the `.dmg`, drag the app into `Applications`, then launch it. Since the app isn't notarized by Apple, macOS will show an "unidentified developer" warning the first time — right-click the app and choose **Open** to bypass it.

## What it does

- On launch, prompts you to choose a project folder.
- Opens an embedded terminal in that folder and runs `claude`.
- If Claude Code isn't installed yet, it asks for permission and installs it automatically using Anthropic's official installer, then launches `claude` — which walks you through signing in to your Claude account.

## Building from source

```bash
swift build -c release
```

Requires macOS 13+ and Swift 5.9+.
