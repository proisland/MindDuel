# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Setup (run once after clone on a Mac)
```bash
make setup        # brew install xcodegen && xcodegen generate
make generate     # Re-generate .xcodeproj after editing project.yml
```

### Build & Test (macOS + Xcode required)
```bash
make build        # Debug build targeting iPhone 16 simulator
make test         # Run unit + UI tests on iPhone 16 simulator
make clean        # Remove .xcodeproj and DerivedData
```

`xcodebuild` flags used: `CODE_SIGN_IDENTITY=""  CODE_SIGNING_REQUIRED=NO  DEVELOPMENT_TEAM=""`

### CI
GitHub Actions runs on `macos-15` for every push to `main` and `milestone/**` branches (`.github/workflows/build.yml`).

## Stack

| Layer | Choice |
|---|---|
| Platform | iOS 16+, Swift 5.9, SwiftUI |
| Project config | XcodeGen (`project.yml` is source of truth; `.xcodeproj` is gitignored) |
| Auth | Sign in with Apple (`AuthenticationServices`) |
| Payment (M6) | StoreKit 2 |
| Backend (M2+) | REST API + WebSocket, EU-region |
| Localization | `Localizable.xcstrings` (String Catalogs), Norwegian (`no`) + English (`en`) |
| Color scheme | Dark mode only (forced with `.preferredColorScheme(.dark)`); no light-mode variants needed |

## Project layout

```
MindDuel/                 ← iOS app source (XcodeGen picks up all files here)
  App/                    ← Entry point, AuthState, RootView
  Authentication/         ← Sign in with Apple, UsernameSetupView
  Home/                   ← Post-auth home screen
  DesignSystem/
    Colors.swift          ← Color extensions: .mdBg, .mdAccent, etc.
    Typography.swift      ← .mdStyle(.heading) ViewModifier
    Spacing.swift         ← MDSpacing.xs/sm/md/lg/xl (8 pt grid)
    Components/           ← MDButton, MDPrimaryCard, MDSecondaryCard,
                             MDAvatar, MDPillTag, MDTopBar
  Resources/
    Assets.xcassets/      ← All 22 design-system color sets + AppIcon
    Localizable.xcstrings ← All UI strings (no + en)
MindDuelTests/            ← XCTest unit tests
MindDuelUITests/          ← XCTest UI tests
project.yml               ← XcodeGen config (edit this, not .xcodeproj)
Makefile                  ← setup / generate / build / test / clean
docs/                     ← PRD, Design, Milestones (source of truth for product)
```

## Architecture

### Auth state machine
`AuthState` (ObservableObject, `@MainActor`) holds an `AuthPhase` enum:
- `.signedOut` → `SignInView`
- `.needsUsername(userID:)` → `UsernameSetupView`
- `.authenticated(userID:, username:)` → `HomeView`

It is created with `@StateObject` in `MindDuelApp` and injected via `.environmentObject(authState)`. Every view that needs it declares `@EnvironmentObject private var authState: AuthState`.

### Design tokens
- **Colors**: `Color.mdBg`, `.mdAccent`, `.mdRed`, etc. (defined in `Colors.swift`, backed by named Color Assets)
- **Typography**: `.mdStyle(.heading)` ViewModifier — never use `.font()` directly in feature views
- **Spacing**: `MDSpacing.md` (16 pt), `.lg` (24 pt), etc. — never use raw `CGFloat` spacing constants

### Components
All reusable UI lives in `DesignSystem/Components/`. Use these everywhere rather than rebuilding primitives:
- `MDButton(.primary / .ghost / .danger, title:) { }` — respects `\.isEnabled` environment
- `MDPrimaryCard { }` / `MDSecondaryCard { }` — wraps content with correct background + border
- `MDTopBar(title:, leadingAction:) { trailing }` — three-slot top bar
- `MDAvatar(username:, size: .sm/.md/.lg)`
- `MDPillTag(label:, variant: .accent/.pink/.green/.amber/.red/.neutral)`

### Localization
Always use `String(localized: "key")` or `Text("key")` with keys defined in `Localizable.xcstrings`. Never hardcode user-visible strings in Swift files.

## Branching

| Milepæl | Branch |
|---|---|
| M1 – Fundament | `milestone/m1-fundament` ← current |
| M2 – Spillbar prototype | `milestone/m2-prototype` |
| M3 – Progresjon og score | `milestone/m3-progresjon` |
| M4 – Sosialt lag | `milestone/m4-sosialt` |
| M5 – Flerspiller | `milestone/m5-flerspiller` |
| M6 – Betaling | `milestone/m6-betaling` |
| M7 – Polering | `milestone/m7-polering` |
| M8 – App Store | `milestone/m8-appstore` |

Branch from `main` for each milestone. Open a draft PR early. Check off deliverables in `docs/milestones.md` in the same PR. Tag `m1`, `m2`, … after merge to `main`.
