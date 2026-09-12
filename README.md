# PR Menu

A macOS menu bar app for the pull requests that belong to you on GitHub: **created by you**, **assigned to you**, and **requested for your review**.

Click a row to open the pull request in your default browser. Each row shows a GitHub-style check ring and the fraction of checks that have passed.

## Run it

macOS 15 or later. You need Swift (Xcode or Command Line Tools) to build.

```bash
make run
```

That compiles a `PR Menu.app` in `dist/` and opens it. A pull-request icon appears in the menu bar; the number next to it is how many unique open PRs were found.

To keep it around:

```bash
make install
```

Then add **PR Menu** to System Settings → General → Login Items if you want it at login.

## GitHub access

The app looks for credentials in this order:

1. A personal access token saved in Settings (stored in your Keychain)
2. Your existing GitHub CLI login (`gh auth token`)

A classic token needs the `repo` scope. A fine-grained token needs read access to Pull requests and Checks on the repositories you care about.

If `gh` is already signed in, you can skip the token and just open the app.

## What it shows

- Three sections, each refreshed about every minute
- Title, repository, number, age, and a Draft badge when needed
- Check ring: green passed, gray pending, red failed (skipped checks are omitted)
- Fraction on the right: `passed / complete`
- Right-click a row to copy its URL

## Build without Make

```bash
swift build -c release
./scripts/build.sh
open "dist/PR Menu.app"
```
