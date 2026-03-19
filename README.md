# Git Menu Bar

A minimal, beautiful macOS menu bar app that puts your GitHub pull requests one click away.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menu bar native** — lives in your menu bar with a PR count badge. No dock icon, no windows to manage.
- **Three views** — switch between Reviews, Assigned, and Created tabs to see what needs your attention.
- **Status at a glance** — color-coded indicators show review state (approved, changes requested, pending) and CI status (passing, failing, running) separately.
- **Click to open** — click any PR to open it directly in your browser.
- **Auto-refresh** — polls GitHub every 60 seconds. Manual refresh available anytime.
- **Secure** — your GitHub token is stored in the macOS Keychain, never in plain text.
- **Zero dependencies** — built entirely with SwiftUI, Foundation, and Security frameworks. No third-party packages.
- **Light & Dark mode** — adapts automatically to your system appearance.
- **Launch at login** — optional, toggle it in Settings.

## Screenshots

*Coming soon*

## Installation

### Build from source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/git-menu-bar.git
   cd git-menu-bar
   ```

2. Build:
   ```bash
   swift build -c release
   ```

3. Create the app bundle and run:
   ```bash
   mkdir -p build/GitMenuBar.app/Contents/MacOS
   mkdir -p build/GitMenuBar.app/Contents/Resources
   cp .build/release/GitMenuBar build/GitMenuBar.app/Contents/MacOS/
   cp GitMenuBar/Info.plist build/GitMenuBar.app/Contents/
   open build/GitMenuBar.app
   ```

Or open `Package.swift` in Xcode and hit Run.

## Setup

1. **Create a GitHub Personal Access Token:**
   - Go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)
   - Generate a new token (classic) with the `repo` scope
   - Copy the token

2. **Add the token to Git Menu Bar:**
   - Click the pull request icon in your menu bar
   - Click "Connect GitHub" (or the gear icon if already set up)
   - Paste your token and click Save

3. Your pull requests will load automatically.

## Architecture

```
GitMenuBar/
├── GitMenuBarApp.swift              # App entry point with MenuBarExtra
├── Info.plist                       # LSUIElement (menu bar only, no dock icon)
├── Models/
│   └── PullRequest.swift            # PR model, review/CI enums, filter types
├── Services/
│   ├── GitHubAPIService.swift       # GitHub GraphQL API client
│   └── KeychainHelper.swift         # macOS Keychain wrapper
├── ViewModels/
│   └── PRListViewModel.swift        # State management, polling, auth
└── Views/
    ├── MenuBarView.swift            # Main popover layout
    ├── PRRowView.swift              # Individual PR row with status badges
    ├── SettingsView.swift           # Preferences window
    └── EmptyStateView.swift         # Empty, error, and loading states
```

### Key design decisions

- **GitHub GraphQL API (v4)** — a single query fetches PRs across all repositories with review status, CI checks, and labels. No N+1 REST calls.
- **`MenuBarExtra` with `.window` style** — provides a rich SwiftUI popover instead of a basic dropdown menu.
- **`actor`-based API service** — thread-safe network layer using Swift concurrency.
- **Keychain storage** — tokens are stored using the Security framework, never in UserDefaults or on disk.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+
- A GitHub account with a Personal Access Token

## License

MIT
