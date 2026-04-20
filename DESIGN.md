# SnapMark Design

## Purpose

SnapMark is a small native macOS utility for region capture and annotation. The design goal is not only to provide a usable screenshot tool, but also to establish a repeatable baseline for future macOS utilities that need to coexist correctly with:

- menu bar app lifecycle
- global keyboard shortcuts
- privacy-controlled APIs such as Screen Recording
- custom overlay windows
- local code signing and stable bundle identity

## Product Intent

The target behavior is similar to lightweight capture tools like Snipaste:

1. Launch capture instantly from a global shortcut.
2. Drag a region on any display.
3. Annotate without a heavyweight editor.
4. Copy or save the result immediately.

The implementation favors predictable system behavior over framework abstraction.

## Architecture Summary

SnapMark is implemented as a Swift Package executable wrapped into a signed app bundle by [build.sh](build.sh).

High-level subsystem split:

- application shell
- capture workflow
- overlay selection UI
- annotation editor
- export pipeline
- signing and installation pipeline

## Runtime Flow

### 1. Application Startup

Startup is handled in [SnapMark/App.swift](SnapMark/App.swift).

Responsibilities:

- create the shared `NSApplication`
- set accessory activation policy
- install menu bar UI
- initialize capture coordinator
- register global hotkey

Key design choice:

- use direct AppKit lifecycle instead of SwiftUI scene lifecycle

Reason:

- the app needs precise control over activation, overlay windows, focus, and menu bar behavior

### 2. Capture Initiation

Capture can start from:

- the menu bar item
- the global hotkey registered in [SnapMark/GlobalHotkey.swift](SnapMark/GlobalHotkey.swift)

The hotkey implementation uses Carbon APIs because they remain a pragmatic way to register system-wide shortcuts for small macOS utilities.

### 3. Permission Gate

Before showing capture overlays, [SnapMark/CaptureCoordinator.swift](SnapMark/CaptureCoordinator.swift) checks Screen Recording permission through [SnapMark/ScreenCapture.swift](SnapMark/ScreenCapture.swift).

Permission sequence:

1. preflight permission state
2. request permission if not yet granted
3. show a relaunch-oriented message when permission changes
4. abort capture until the app is relaunched and permission is actually usable

Key design choice:

- treat TCC permission as process-sensitive and identity-sensitive

Reason:

- a successful permission prompt does not guarantee the current process can immediately capture the screen

### 4. Region Selection

Selection uses one borderless window per screen via [SnapMark/RegionSelector.swift](SnapMark/RegionSelector.swift).

Window characteristics:

- fullscreen borderless windows
- semi-transparent darkened background
- top-level presentation suitable for screen selection
- local drawing for marquee and dimension display

Key design choice:

- create separate selector windows for each screen

Reason:

- it keeps per-screen coordinate handling and fullscreen presentation simpler than trying to fake a single spanning overlay

### 5. Overlay Teardown

This was the most failure-prone area.

Current teardown strategy in [SnapMark/CaptureCoordinator.swift](SnapMark/CaptureCoordinator.swift):

- order overlays out immediately
- disable mouse events immediately
- retain retiring windows temporarily
- close them later on the main queue

Key design choice:

- do not synchronously destroy overlay windows from the same event path that produced the selection

Reason:

- earlier versions crashed with `EXC_BAD_ACCESS` during autorelease pool drain, consistent with AppKit lifetime issues during event dispatch

### 6. Screen Capture

The selected AppKit-space rectangle is converted into Core Graphics screen coordinates in [SnapMark/CaptureCoordinator.swift](SnapMark/CaptureCoordinator.swift), then captured in [SnapMark/ScreenCapture.swift](SnapMark/ScreenCapture.swift).

Current capture implementation:

- `CGWindowListCreateImage`
- `.bestResolution` image option

Key design choice:

- capture bitmap data directly from Core Graphics and keep logical view sizing separate from source pixel dimensions

Reason:

- Retina displays make point size and pixel size diverge; export code must not collapse them accidentally

### 7. Annotation Editor

The editor is hosted by [SnapMark/AnnotationEditor.swift](SnapMark/AnnotationEditor.swift) and rendered by [SnapMark/AnnotationCanvas.swift](SnapMark/AnnotationCanvas.swift).

Supported annotations:

- rectangle
- arrow
- pen
- multiline text

Current editor behavior:

- copy with `Cmd+C`
- save with `Cmd+S`
- undo with `Cmd+Z`
- delete/remove-last with Delete or toolbar action

Key design choice:

- keep annotation state lightweight and local to the canvas instead of introducing a heavier document model

Reason:

- the product goal is fast capture annotation, not a general vector graphics editor

### 8. Text Annotation Model

Text annotations were initially implemented with a single-line text field and later redesigned to use a wrapped multiline editor.

Current behavior in [SnapMark/AnnotationCanvas.swift](SnapMark/AnnotationCanvas.swift):

- multiline editing with wrapping
- commit on focus loss
- persisted text box width after commit
- pending text can be discarded by undo/delete behavior

Key design choice:

- store text box width in the committed annotation model

Reason:

- wrapped text must preserve layout after the editing control is removed

### 9. Export Pipeline

The final image is rendered from the canvas in [SnapMark/AnnotationCanvas.swift](SnapMark/AnnotationCanvas.swift), then copied via [SnapMark/Utilities/ClipboardManager.swift](SnapMark/Utilities/ClipboardManager.swift) or saved via file saver utilities.

Key design choices:

- render final output using original source bitmap dimensions
- preserve logical image size metadata separately
- write concrete image data types to the pasteboard

Reason:

- earlier versions produced incorrect paste sizing and flipped output in some contexts

## Packaging And Identity

### Bundle Identity

The bundle identifier is fixed in [Info.plist](Info.plist) as `com.snapmark.app`.

This identifier must stay stable across builds if the app is expected to behave consistently with TCC permissions.

### Local Signing Strategy

The local build pipeline in [build.sh](build.sh) creates or reuses:

- a dedicated build keychain
- a self-signed development code-signing certificate
- a signed app bundle in `dist/SnapMark.app`

Key design choice:

- sign every app bundle produced for local use

Reason:

- unsigned or inconsistently signed builds caused repeated permission prompts and unpredictable runtime behavior

### Canonical Install Path

The intended installed path is `/Applications/SnapMark.app`.

Key design choice:

- keep one canonical installed app path

Reason:

- multiple bundles with the same identifier caused Launch Services to resolve the wrong copy, which in turn distorted TCC behavior

## Failure Modes We Already Paid For

These are the problems this design now explicitly defends against.

### Repeated Permission Prompts

Root causes previously seen:

- inconsistent signing
- mismatched bundle identity
- multiple installed copies

### Capture-Time Crashes

Root causes previously seen:

- unsafe selector window teardown during event handling
- overly aggressive activation-policy transitions

### Export Mismatch On Retina Displays

Root causes previously seen:

- mixing logical point size with captured pixel dimensions
- relying on implicit `NSImage` representation behavior during clipboard export

## Design Principles For Future Work

- favor predictable AppKit behavior over clever abstraction
- preserve stable identity early
- treat permissions, signing, and installation path as runtime design concerns
- separate logical view size from pixel export size
- keep window lifecycle conservative during input-driven transitions

## Suggested Future Enhancements

- selection and movement of existing annotations
- resize handles for shapes and text boxes
- richer text formatting controls
- configurable shortcut binding
- notarized distribution pipeline