# TokenFlow

TokenFlow is a small macOS app for tracking Codex token usage from local Codex history.

<img width="1182" height="898" alt="CleanShot 2026-06-11 at 21 10 42" src="https://github.com/user-attachments/assets/54555a5f-2280-4f67-a5d2-d4a5d232b18c" />

## What it shows

TokenFlow gives you a quick view of your current Codex session, recent sessions, and weekly usage.

It tracks input, cached input, output, and reasoning tokens. The app also shows reset times when Codex exposes quota information.

## Features

• Current Codex session usage
• Weekly quota usage
• Recent session list
• Token breakdown for input, cache, output, and reasoning
• Native macOS widgets
• Optional menu bar status item
• Optional usage notifications
• First run onboarding

## Download

Download the signed and notarized DMG from the latest GitHub release:

https://github.com/pulssart/TokenFlow/releases/download/v1.0/TokenFlow-1.0.dmg

## Setup

TokenFlow reads local Codex data, so Codex needs to be signed in on the machine.

Open Settings in the app, then use the Codex login action if needed. The app can also show the onboarding flow again from Settings.

## Build and run

```bash
./script/build_and_run.sh --verify
```

## Release build

```bash
./script/release.sh
```

The release script builds the app, signs it with Developer ID, creates a DMG, and submits it to Apple notarization when the `TokenFlow` notary profile exists in Keychain.
