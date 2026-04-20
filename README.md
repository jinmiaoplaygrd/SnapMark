# SnapMark

SnapMark is a native macOS screen capture and annotation utility built with Swift, AppKit, Carbon, and Core Graphics. It is designed as a small but opinionated reference app for future macOS utilities that need menu bar behavior, global shortcuts, screen capture, annotation, and stable interaction with macOS privacy and signing systems.

The app is useful on its own, but the repo is also intended to preserve the engineering decisions and macOS-specific lessons that were expensive to learn once and should not need to be relearned on the next project.

## Scope

SnapMark currently supports:

- menu bar operation without normal Dock presence
- global hotkey capture with `Ctrl+Shift+A`
- multi-display region selection
- screenshot capture with Screen Recording permission checks
- high-fidelity capture that preserves the original screen brightness and color without including the dimmed selection overlay
- annotation with rectangle, arrow, pen, and multiline text
- responsive annotation toolbar with overflow access through a `...` menu when the editor window is narrow
- undo and remove-last behavior
- editor windows that open at the captured image's natural size so small captures keep the correct aspect ratio
- copy to clipboard and save as PNG

## Document Map

- Overview and setup: this file
- Formal project design: [DESIGN.md](DESIGN.md)
- Reusable macOS app lessons and template: [MACOS_UTILITY_TEMPLATE.md](MACOS_UTILITY_TEMPLATE.md)
- Contributor workflow and release checklist: [CONTRIBUTING.md](CONTRIBUTING.md)

## Project Layout

- [Package.swift](Package.swift): Swift Package definition for the executable target
- [build.sh](build.sh): local build, bundle assembly, and signing pipeline
- [Info.plist](Info.plist): bundle metadata and privacy usage strings
- [SnapMark/App.swift](SnapMark/App.swift): AppKit entrypoint and menu bar lifecycle
- [SnapMark/GlobalHotkey.swift](SnapMark/GlobalHotkey.swift): Carbon global shortcut registration
- [SnapMark/CaptureCoordinator.swift](SnapMark/CaptureCoordinator.swift): permission checks, overlay lifecycle, capture-to-editor workflow
- [SnapMark/RegionSelector.swift](SnapMark/RegionSelector.swift): fullscreen selection overlay windows and drag behavior
- [SnapMark/ScreenCapture.swift](SnapMark/ScreenCapture.swift): screen capture permission and bitmap capture logic
- [SnapMark/AnnotationEditor.swift](SnapMark/AnnotationEditor.swift): editor window behavior and keyboard shortcuts
- [SnapMark/AnnotationCanvas.swift](SnapMark/AnnotationCanvas.swift): drawing, text editing, export rendering
- [SnapMark/Views/ToolbarView.swift](SnapMark/Views/ToolbarView.swift): annotation toolbar controls

## Build And Install

Build the app bundle:

```bash
cd /Users/jinmiao/Dev/SnapMark
./build.sh
```

Output:

- `dist/SnapMark.app`

Run the built bundle directly:

```bash
open dist/SnapMark.app
```

Install the canonical copy:

```bash
rm -rf /Applications/SnapMark.app
cp -R dist/SnapMark.app /Applications/SnapMark.app
open /Applications/SnapMark.app
```

The canonical installed path is intentionally `/Applications/SnapMark.app`. Earlier iterations had multiple bundles with the same bundle identifier in different locations, which confused Launch Services and TCC permission behavior.

## Signing And Permissions

SnapMark depends on stable bundle identity. This is not an optional packaging concern; it directly affects whether macOS privacy permissions behave predictably.

The build pipeline in [build.sh](build.sh):

- creates or reuses a dedicated local keychain
- creates or reuses a self-signed code signing identity named `SnapMark Local Development`
- signs the `.app` bundle as `com.snapmark.app`

The app requires Screen Recording permission and uses the permission flow implemented in [SnapMark/ScreenCapture.swift](SnapMark/ScreenCapture.swift).

Important operating rule:

- after granting Screen Recording permission, expect to relaunch the app before capture becomes reliable

## Capture And Editor Behavior

Recent behavior worth preserving:

- capture is taken from beneath the selection overlay window so the final image keeps the original screen brightness and color instead of inheriting the overlay dimming
- the annotation editor opens at the captured image's natural dimensions instead of reusing a stale window size from a previous capture
- when the editor window is too narrow to show the full toolbar, hidden controls remain available from the `...` overflow menu instead of falling off-screen

## Why This Repo Matters

The main long-term value of SnapMark is that it already crossed several macOS-specific failure modes that commonly slow down first-time utility apps:

- unstable signing identity causing repeated permission churn
- duplicate app bundles causing Launch Services confusion
- overlay window lifetime causing capture-time crashes
- activation and focus handling issues in menu bar apps
- Retina point-vs-pixel mistakes in exported images

Those lessons are documented here so the next macOS app can start from a better baseline.

## Status

SnapMark is currently a working local utility and a reusable reference implementation for future macOS capture-style tools.