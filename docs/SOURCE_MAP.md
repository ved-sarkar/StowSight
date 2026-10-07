# Source map and validation

| Path | Role |
| --- | --- |
| `Sources/InventoryCore/InventoryStore.swift` | Codable item model, input validation, reload, and atomic save operations |
| `Sources/StorageTrackerApp/StorageTrackerApp.swift` | Shared application view model and local Application Support file location |
| `Sources/StorageTrackerApp/ContentView.swift` | Inventory list, item editor, date-reset action, and deletion confirmation |
| `Tests/InventoryChecks/InventoryChecks.swift` | Focused persistence and failure-path checks using temporary fictional data |
| `Package.swift` | One macOS SwiftUI executable, one Foundation core target, and a dependency-free check runner |

## Persistence behavior

An item has a stable UUID, name, description, location, estimated value, and last-used date. Empty names, negative/non-finite values, and duplicate stored identifiers are rejected. A failed save leaves the previous in-memory list intact. A malformed inventory file is not replaced with an empty inventory; the UI disables editing until the file is repaired or restored and the app reopened.

The JSON file is a normal local file, not encrypted storage or a database with multi-process transactions. No contents are sent over the network. Keep personal inventories out of the repository; `inventory*.json` is ignored as an additional precaution.

## History and scope

The initial source snapshot (`039fcb3`) captured the original inventory view, two conflicting app entry points, and a Core Data container with no model. The new 2026-10-07 implementation resolves that structure into a manual macOS inventory app. It preserves the intended item fields and last-used action, adds add/edit/delete persistence, and does not add camera or model-provider integrations. The unused SwiftLog dependency was removed.

The original local working folder was not modified. The initial repository commit retains the prior scaffolds. Its tutorial notebook, generated Xcode shell/tests, user/signing settings, and private notes were never included.

## Validation

Checked on 2026-10-07 with Apple Swift 6.3.2 on Apple Silicon:

- `swift run InventoryChecks`: all four persistence checks passed (CRUD round trip, invalid changes, malformed/duplicate records, and failed writes).
- `swift build --product StorageTracker`: SwiftUI application compiled and linked successfully.

The runner uses Foundation and temporary fictional data, so XCTest or third-party test libraries are not required. No camera, network provider, personal inventory, or hardware was used. The app was compiled but not launched; UI interaction has not been verified in this environment.
