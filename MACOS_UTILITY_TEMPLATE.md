# macOS Utility App Template

This document captures the reusable guidance from SnapMark for future native macOS utilities, especially small tools that use menu bar lifecycle, hotkeys, overlays, or privacy-controlled APIs.

## Start With These Defaults

### Identity

- choose a stable bundle identifier immediately
- keep it unchanged during early development unless there is a very good reason to rotate it
- decide one canonical installed location for local testing

Recommended baseline:

- bundle identifier like `com.example.toolname`
- canonical install path in `/Applications/ToolName.app`

### App Model

Prefer direct AppKit lifecycle when the app needs:

- menu bar status item behavior
- nonstandard activation or focus handling
- fullscreen overlays
- global hotkeys
- tight control of window lifetime

### Signing

If the app touches TCC-protected APIs, sign every build you actually run.

Examples of APIs that should push you toward stable signing early:

- Screen Recording
- Accessibility
- camera or microphone access
- automation or Apple Events in some workflows

## Recommended Local Development Pattern

### Build Output

- build to a single output folder such as `dist/`
- do not keep multiple runnable bundles around with the same bundle identifier

### Signing Pipeline

Use a reproducible local signing flow that:

- creates or reuses a dedicated build keychain
- creates or reuses a local self-signed code-signing certificate
- signs the final bundle on every build

### Install Flow

Use one install command consistently:

```bash
rm -rf /Applications/ToolName.app
cp -R dist/ToolName.app /Applications/ToolName.app
open /Applications/ToolName.app
```

## TCC Permission Rules

Treat macOS privacy permissions as identity-bound and process-sensitive.

Practical rules:

- preflight before doing the protected action
- request only when needed
- assume a relaunch may be required after the user grants permission
- do not assume the current process becomes trustworthy immediately

When debugging permission issues, check these first:

- bundle identifier
- signing consistency
- actual path of the running bundle
- existence of duplicate installed copies

## Window And Event Lifecycle Rules

For overlay-driven tools:

- avoid destroying windows synchronously from the same event callback that triggered the transition
- prefer ordering windows out first, then closing them later on the main queue
- temporarily retain windows if AppKit lifetime issues are suspected

Signals that you may have a lifecycle problem rather than an API problem:

- crashes on the main thread during autorelease pool drain
- disappearing windows right after mouse events
- unstable behavior only during transition boundaries such as mouse-up or close

## Graphics And Export Rules

Always separate:

- logical size in points
- backing bitmap size in pixels

On Retina systems, confusing those two produces subtle bugs such as:

- copied images pasting at the wrong size
- saved output not matching the captured region exactly
- blurred or rescaled final exports

Recommended practice:

- preserve original bitmap pixel dimensions for export
- keep logical size metadata explicit
- prefer concrete pasteboard data representations over relying on implicit `NSImage` behavior alone

## UX And Interaction Rules

Treat transient UI, responsive layout, and content sizing as product behavior, not polish work to defer until later.

### Preserve Source Fidelity

If the product captures, previews, or edits user content:

- do not let temporary UI chrome such as dimming overlays, selection masks, or transition states leak into the final captured result
- prefer fixing fidelity at the capture or rendering source instead of compensating afterward with brightness or color adjustments
- test the preview against the saved output so the user is not surprised by a mismatch

### Size Windows Around Content First

For content-driven tools:

- open the first editing surface at the content's natural size when practical
- do not reuse stale autosaved window dimensions across fundamentally different content sizes unless the UX explicitly calls for that behavior
- avoid large default minimum sizes that distort or visually drown small pieces of content

### Preserve Aspect Ratio During Presentation

When showing captured images, documents, or media:

- keep the original aspect ratio unless the user explicitly requests stretching or cropping
- separate the content frame from the host window frame so resizing the window does not accidentally imply rescaling the content model
- verify small-content and large-content cases separately; bugs often only show up at one end of the size range

### Degrade Controls Gracefully

When horizontal space gets tight:

- never let essential actions silently fall off-screen
- move lower-priority or trailing controls into an overflow affordance such as a `...` menu
- keep the overflow behavior predictable so users can still find the same actions in the same order
- prefer preserving direct access to the most frequently used controls before secondary ones

### Responsive UX Checks

Run these checks whenever the UI depends on content size or window size:

1. Does the content still look correct at its smallest expected size?
2. Does the UI remain usable when the window is narrower than the ideal toolbar width?
3. Does the saved or copied output match what the preview implies?
4. Are temporary interaction layers excluded from the final user-visible result?

## Suggested Project Skeleton

- `Package.swift` or Xcode project
- `build.sh` for deterministic build and signing
- `Info.plist` with privacy strings from day one
- `App.swift` or app delegate entrypoint
- `CaptureCoordinator.swift` or equivalent flow orchestrator
- `README.md`
- `DESIGN.md`
- `CONTRIBUTING.md`

## Debugging Order For First-Time macOS Utilities

When the app misbehaves, debug in this order:

1. Is the running bundle the one you think it is?
2. Is the bundle identifier stable and correct?
3. Was the current build actually signed?
4. Is macOS waiting for a relaunch after permission changes?
5. Are you closing windows or changing activation state at a fragile time?
6. Are points and pixels being mixed in rendering or export?

This order saves time because many early macOS problems are identity and lifecycle problems before they are logic problems.