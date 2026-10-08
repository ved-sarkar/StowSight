# StowSight validation — 2026-10-08

The macOS offline prototype builds successfully. Core persistence, scan workflow and app-model integration checks pass. Six native UI screens were rendered and visually inspected after the StowSight branding update.

## Reproduce

```sh
./Scripts/check.sh
./Scripts/screenshots.sh
```

The installed Apple Swift 6.3.2 toolchain on Apple Silicon compiled both `StowSight` and the legacy `StorageTracker` product. Tests ran through `InventoryChecks` and `StowSight --check-app`. Screenshot generation ran through `StowSight --render-screenshots`.

In the constrained execution environment, compiler caches and build outputs were kept in temporary storage. SwiftPM’s nested package sandbox was disabled because it cannot start inside that environment; the outer execution sandbox remained active. No extra permissions or software installations were needed. User-cache and AppKit notification-service diagnostics did not prevent builds, checks or captures.

## Checks that passed

| Area | What was verified |
| --- | --- |
| Existing persistence checks | CRUD round trip; invalid values preserve disk/memory; corrupt or duplicate stored records preserve files; failed writes preserve memory |
| Review decisions | Pending proposals block approval; corrections persist; exclusions stay absent; a second commit is rejected |
| Duplicate observations | Case/whitespace-normalized names require separate-object confirmation or exclusion |
| Rescan reconciliation | Explicit matching preserves identity and usage history; reviewed location updates; unseen items stay unchanged; new items can be added |
| Match conflicts | Multiple proposals cannot target one identity; missing match targets are rejected |
| Stale review | In-memory inventory changed after a scan begins cannot be overwritten by that review |
| Failed saves | Invalid proposals leave disk unchanged; write failures retain drafts; a successful retry commits once |
| Cancellation | Discard and in-flight cancellation reject late results and writes |
| Error recovery | Mock failure, retry and empty-result handling |
| Data compatibility | Duplicate observation IDs are rejected; legacy manual JSON loads without last-seen fields |
| App integration | Intake, pending gate, correction/approval, reload, manual deletion and corrupt-store handling work through the observable view model |
| Late adapter responses | A cancelled adapter that still returns cannot replace a newer scan session |

These tests use temporary synthetic data and no external dependencies. They are executable assertion suites, not XCTest tests.

## Native screenshots

All images in [the demo gallery](DEMO.md) render the actual `ContentView` and its native editable controls via `NSHostingView.cacheDisplay` at 1280 × 900. The capture runner drives real `ScanSession` decisions and `InventoryViewModel.approveScan` against an isolated temporary JSON file. No desktop screenshot or screen-recording permission is involved.

The gallery covers clip intake, corrected/excluded proposals, approved inventory, rescan reconciliation, saved rescan retention and a recoverable recognition error. The images use the StowSight indigo/lilac design and storage-room fixtures. Checksums are recorded in [SCREENSHOT_CHECKSUMS.txt](SCREENSHOT_CHECKSUMS.txt).

Visual checks found no overlapping or truncated primary content at the captured size. Offscreen captures and app-model checks do not constitute end-to-end mouse/keyboard automation, accessibility certification or iPhone device testing.

## Intentional limits

- Clip choices are fixture IDs; no real media is opened or processed.
- Scores, timestamps and the storyboard are synthetic.
- No camera, microphone, photo-library access, paid inference, provider credentials or model setup is included.
- Live Gemini inference, an iOS target, frame evidence and visual identity matching are planned.
- Drafts remain in memory only. Concurrent processes writing the same store are unsupported.
- There is no cloud synchronization or encrypted inventory database.

See [the live-integration plan](LIVE_INTEGRATION.md) for the next milestones and provider/permission decisions. The earlier manual release’s evidence is preserved separately in [HISTORY.md](HISTORY.md).
