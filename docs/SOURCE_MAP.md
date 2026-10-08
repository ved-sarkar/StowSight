# StowSight source map

| File | Responsibility |
| --- | --- |
| `Sources/InventoryCore/InventoryStore.swift` | Codable inventory, validation, atomic JSON persistence; optional last-seen and last-used dates |
| `Sources/InventoryCore/ScanWorkflow.swift` | Explicit mock adapter, synthetic fixtures, review state machine, duplicate/match safeguards and batch commit |
| `Sources/StorageTrackerApp/StorageTrackerApp.swift` | App entry, local store path, observable model, asynchronous cancellation and session identity checks |
| `Sources/StorageTrackerApp/ContentView.swift` | Indigo/lilac StowSight UI: intake, proposal correction/approval, inventory, rescan, errors and manual editor |
| `Sources/StorageTrackerApp/ScreenshotRenderer.swift` | Native offscreen UI rendering with isolated synthetic data |
| `Sources/StorageTrackerApp/ApplicationChecks.swift` | Integration checks of the observable model and asynchronous recognition |
| `Tests/InventoryChecks/` | Executable checks for CRUD, review states, duplicates, cancellation, rescan and persistence |
| `Scripts/` | Local demo, validation and screenshot launchers; no installation or download steps |
| `Package.swift` | StowSight product, legacy StorageTracker launch alias, Foundation core and dependency-free check runner |

## Persistence and review boundaries

Recognition returns observations, never inventory writes. `ScanSession` holds review decisions against a baseline inventory. Approval requires a decision on every proposal and validates the entire batch. Only an explicit user-selected match updates an existing identity; unmatched objects stay saved. Two observations cannot target the same existing identity in one review.

A failed write leaves both stored inventory and displayed inventory unchanged and retains the review for retry. Malformed JSON disables editing instead of replacing the file. JSON is a normal local file, not encrypted storage or a database with multi-process transactions. Keep personal inventories out of the repository; `.demo-data/` and `inventory*.json` are ignored.

The data schema remains compatible with the previous manual inventory. Existing last-used dates load unchanged; newly observed items have no invented last-used date. The default offline data location remains `StorageTrackerDemo/inventory.json` in Application Support. The launcher explicitly selects a checkout-local `.demo-data/inventory.json`, separate from the old manual app’s store.

## History and scope

StowSight extends the manual Storage Tracker prototype with synthetic clip intake and a working review/rescan flow. The repository is named StowSight; internal target directories retain legacy Storage Tracker identifiers for continuity. There is no live media parser, Gemini client, camera implementation or iOS target.

The original author and licensing notices are retained in [ATTRIBUTION.md](../ATTRIBUTION.md). Earlier implementation details and validation are preserved in [HISTORY.md](HISTORY.md), and prior source snapshots remain in Git history.
