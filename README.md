# opencode-go-usage-macos-app

A macOS menu-bar app that shows your [OpenCode Go](https://opencode.ai/docs/go) plan usage at a glance — the three rolling budgets (5-hour / weekly / monthly) as percentages with reset countdowns, refreshed on a timer.

<p align="center"><em>Menu-bar label modes: 3-segment gauge or compact "Go" text.</em></p>

## Why

OpenCode Go gives you three usage windows — rolling, weekly, and monthly. The only official way to see them is the web console at `opencode.ai/auth`, which requires opening a browser and refreshing. This app puts their usage in your menu bar so you always know how close you are to throttling.

OpenCode does not expose a public API for usage. This app works by scraping the server-rendered Go dashboard HTML using your authenticated session cookie, then parsing the inlined SolidStart `lite.subscription.get` payload.

## What it shows

- **Menu bar**: 3-segment gauge (green/orange/red by threshold) or the text `Go` — toggle in Settings.
- **Dropdown**: three rows — Rolling (5h), Weekly, and Monthly — each with `%`, a progress bar, and a humanized reset countdown (e.g. `resets in 2h 45m` / `3d 18h` / `14d 15h`).
- **Header**: workspace region(s) and a "using Zen balance" indicator when the fallback-to-balance toggle is on.
- **Footer**: Refresh now · Settings… · Quit.

## Requirements

- macOS 13.0+ (uses `MenuBarExtra`, `SMAppService`)
- Xcode 15+ with the macOS 13 SDK (built on macOS 26 SDK; should deploy down to 13)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation (the `.xcodeproj` is gitignored)

## Build

```sh
# from the project root
make gen          # xcodegen generate  → creates GoUsage.xcodeproj
make run          # build (Debug) + launch
```

To produce a Release build and install it to `/Applications`:

```sh
xcodebuild -project GoUsage.xcodeproj -scheme GoUsage \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build build
cp -R build/Build/Products/Release/GoUsage.app /Applications/
open /Applications/GoUsage.app
```

The project follows the [swift-ios](https://github.com/brettsmith212) nix-config workflow: `project.yml` → `xcodegen` → `xcodebuild`, with every build piped through `xcode-build-server parse -av` so sourcekit-lsp stays warm in Neovim. See the `Makefile` for all targets (`gen`, `build`, `run`, `test`, `refresh-lsp`, `logs`, `clean`).

## First-run setup

The app needs two things from your logged-in `opencode.ai` session:

1. **Workspace ID** — the `wrk_…` string in the URL when you're on your Go page:
   ```
   https://opencode.ai/workspace/wrk_01XXXXXXXXXXXX/go
                                          └──────┬──────┘
                                            workspace ID
   ```
2. **`auth` cookie** — the long-lived (≈1 year) session cookie on `opencode.ai`:
   - Open the Go page in your browser, open DevTools → **Application/Storage** → **Cookies** → `opencode.ai`
   - Find the row named `auth` (host-only on `opencode.ai` — not the 24h `authorization` cookie on `auth.opencode.ai`)
   - Copy its **Value** (starts with `Fe26.2**…`)

In the app: click the menu-bar icon → **Settings…** → paste both → **Save & Fetch Now**.

The cookie is stored in the macOS **Keychain** (`kSecAttrAccessibleAfterFirstUnlock`); the workspace ID and refresh interval live in `UserDefaults`. Nothing leaves the machine — the app only calls `opencode.ai/workspace/{id}/go` with your cookie.

## Settings

| Setting | Default | Stored in |
|---|---|---|
| Launch GoUsage at login | off | `SMAppService` (System Settings → Login Items) |
| Menu bar label: 3-segment gauge vs `Go` text | `Go` (compact) | `UserDefaults` |
| Refresh interval | 5 minutes | `UserDefaults` |
| `auth` cookie | — | Keychain |
| Workspace ID | — | `UserDefaults` |

## How it works (parser notes)

The Go dashboard is a SolidStart app that inlines server-query results as **minified JavaScript** (not JSON) in a `<script>` block. The relevant call is:

```js
$R[28]($R[18], $R[29] = {
  mine: !0,
  useBalance: !1,
  region: $R[30] = ["us","eu","sg"],
  rollingUsage:  $R[31] = { status: "ok", resetInSec: 9959,   usagePercent: 51 },
  weeklyUsage:   $R[32] = { status: "ok", resetInSec: 324950, usagePercent: 31 },
  monthlyUsage:  $R[33] = { status: "ok", resetInSec: 1265617, usagePercent: 79 }
});
```

`UsageFetcher.parse(html:)` locates each `<name>Usage:$R[N]=` anchor (the `$R` ref is required — without it the regex would match the unrelated billing `monthlyUsage:<dollars>` integer), captures the following balanced `{…}`, and regex-extracts `status` / `resetInSec` / `usagePercent` independently of field order. Booleans (`!0`/`!1`) and string arrays are handled in both JS-minified and JSON-pretty forms.

This is a **tolerant parser against an undocumented internal surface**. If OpenCode changes their server-rendering format the parser will need updating — the Settings page has a **Copy last raw HTML to clipboard** button to make capturing a fresh sample easy.

## Caveats

- No public API exists for Go usage; this scrapes HTML. Expect to touch the parser if the console's payload format changes.
- The `auth` cookie is a credential — the app never logs it and only sends it to `opencode.ai`. Rotate it from your browser if you suspect it's leaked.
- Cookie lifetime is ~1 year; when it expires the app shows an HTTP error in the dropdown — re-paste from your browser.
- Ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`); fine for local use, notarization would be needed to distribute.

## License

MIT — see `LICENSE` if/when added. Built for personal use; YMMV.
