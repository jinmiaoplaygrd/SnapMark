# Contributing And Release Notes

This project is small, but it has a few macOS-specific operational constraints that are easy to break accidentally. Treat signing, install path, and permission behavior as part of the product, not as packaging details.

## Contributor Guidelines

### Before Changing Runtime Behavior

Check whether the change touches:

- Screen Recording or other TCC-gated APIs
- activation policy or focus behavior
- overlay window lifecycle
- capture coordinate conversion
- image export or pasteboard behavior

If it does, test with the canonical installed app copy, not an arbitrary bundle path.

### Local Workflow

Build:

```bash
cd /Users/jinmiao/Dev/SnapMark
./build.sh
```

Install and run:

```bash
rm -rf /Applications/SnapMark.app
cp -R dist/SnapMark.app /Applications/SnapMark.app
open /Applications/SnapMark.app
```

Run regression checks for content sizing and toolbar overflow behavior:

```bash
bash scripts/run-regression-checks.sh
```

### Do Not Reintroduce These Problems

- multiple runnable app bundles with the same bundle identifier
- unsigned or inconsistently signed test bundles
- synchronous teardown of selection overlays during active event handling
- point/pixel confusion in export code

## Manual Test Checklist

Run these checks after meaningful UI or capture changes.

Before the manual checks, run:

```bash
bash scripts/run-regression-checks.sh
```

### Capture

- launch app from `/Applications/SnapMark.app`
- trigger capture from the hotkey
- drag a region on the main display
- drag a region on a secondary display if available
- press Escape to cancel selection

### Annotation

- draw rectangle, arrow, and pen annotations
- create multiline text and click outside to commit
- confirm Delete removes the current pending edit or last annotation
- confirm `Cmd+Z` undoes correctly

### Export

- copy result to clipboard and paste into a target app
- verify orientation is correct
- verify pasted size matches expected capture size
- save as PNG and reopen it to inspect dimensions

### Permissions

- test first-run behavior on a system where Screen Recording permission is not yet granted
- grant permission and relaunch the app
- verify capture succeeds after relaunch

## Release Checklist

Before calling a build releasable, verify:

1. `./build.sh` completes successfully.
2. The app bundle is produced at `dist/SnapMark.app`.
3. The installed test copy is `/Applications/SnapMark.app`.
4. The bundle identifier is still `com.snapmark.app`.
5. The app launches, captures, annotates, copies, and saves.
6. No duplicate installed copies are being used during testing.
7. Screen Recording permission behavior still matches the documented flow.

## If Permissions Start Behaving Strangely Again

Check these in order:

1. Are you launching `/Applications/SnapMark.app`?
2. Was the app rebuilt with [build.sh](build.sh)?
3. Did the bundle identifier change?
4. Are there duplicate copies of the app elsewhere?
5. Did macOS need a relaunch after the permission change?

That sequence catches most regressions faster than debugging the capture code first.