<img src="assets/icon/icon-1024.png" width="96" alt="">

# AI Usage Bar

A macOS menu bar app showing your **Claude** and **Codex** (ChatGPT plan) usage limits at a glance, using the same data as Claude Code's `/usage` and Codex's `/status`.

- Menu bar: each provider's logo with its current %, turning orange at 70% and red at 90%
- Popover: Claude 5-hour, weekly and Fable weekly; Codex 5-hour and weekly. Each row shows its reset time and pace ("on pace for 140%")
- Notifications at 80% / 95%, and when a maxed-out window resets
- Settings: menu bar metric (5-hour / weekly / highest), per-provider visibility, launch at login

## Requirements
macOS 13+, Xcode command line tools, and a login to Claude Code (`claude`) and/or Codex (`codex login`, ChatGPT mode).

## Install
```sh
./build.sh                          # builds, signs ad-hoc, installs to ~/Applications
open ~/Applications/AIUsageBar.app
```
On first launch, choose **Always Allow** for the "Claude Code-credentials" Keychain prompt.

## How it works
It is read-only. It reads the existing logins (the Keychain item for Claude, `~/.codex/auth.json` for Codex) and calls two **undocumented** endpoints, either of which may change without notice:
- `GET https://api.anthropic.com/api/oauth/usage`
- `GET https://chatgpt.com/backend-api/wham/usage`

Tokens are never refreshed, stored or logged. If a section says "re-authenticate", run `claude` or `codex` once. Response formats are documented in [`docs/`](docs).

Not affiliated with Anthropic or OpenAI. The logos are trademarks of their owners (via [Simple Icons](https://simpleicons.org)).
