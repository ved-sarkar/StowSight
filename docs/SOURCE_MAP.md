# Source map

| Path | Role |
| --- | --- |
| `StorageTracker/ContentView.swift` | Inventory screen and `ItemRow` view; references missing model, view model, and camera types |
| `Sources/App/StorageTrackerApp.swift` | App entry point injecting the Core Data context |
| `Sources/App/PersistenceController.swift` | Persistent container configuration; the named data model is absent |
| `Sources/StorageTracker/main.swift` | Alternative simple app entry point with the same type name |
| `Package.swift` | Original executable package targeting `Sources`, declaring iOS/macOS and SwiftLog |

These files preserve the original relative paths and bytes. They capture overlapping scaffolds, not a resolved target structure. The meaningful inventory view sits outside the package target. Both entry-point files are inside that target. The inventory view's camera and view-model callbacks demonstrate the intended interface but have no implementations in this snapshot.

The local Xcode shell's Hello World view, generated starter tests, user settings, signing configuration, empty view file, private planning notes, and third-party tutorial notebook were omitted. The starter tests did not verify the inventory view, so they are not presented as coverage for it. No assets or notebook outputs were copied.

Future assembly would require choosing one app entry point, including the inventory view in its target, implementing its referenced types, and defining the persistent model. Video capture and item extraction remain planned work. No changes implementing those features were made during portfolio packaging.
