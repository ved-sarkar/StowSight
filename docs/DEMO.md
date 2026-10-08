# StowSight demo gallery

These six screens are native renders of the working macOS SwiftUI prototype. Everything shown is synthetic. No video file, real household inventory, live model response or desktop recording was used.

## 1. Choose a storage-room scenario

The built-in clip choices feed fixed observations through the mock adapter. The UI states clearly that phone capture and live inference are future work.

![StowSight synthetic clip intake](screenshots/01-video-intake.png)

## 2. Correct and approve

The ambiguous case becomes a sewing kit, and a repeated view of the drill is excluded. Names, descriptions and locations are editable. Approval remains an explicit action.

![Reviewed proposals and excluded duplicate](screenshots/02-human-review.png)

## 3. Return to saved belongings

Approved objects are stored in local JSON and survive relaunch. The app keeps last-seen and last-used history separate.

![Three approved belongings in the local inventory](screenshots/03-approved-inventory.png)

## 4. Reconcile a new observation

The drill is explicitly matched to an existing identity. The lantern and helmet still need decisions. Existing objects without a confirmed match will be kept.

![Explicit rescan matching and retention notice](screenshots/04-rescan-reconciliation.png)

## 5. Keep what the clip did not show

After approval, the inventory contains a new helmet, the drill’s reviewed location and the sewing kit that was outside the second scan.

![Saved rescan retains unseen belongings](screenshots/06-rescan-saved.png)

## 6. Recover without losing inventory

A deliberate mock error exposes retry and cancel. Recognition failures do not mutate saved items.

![Recoverable recognition error](screenshots/05-recoverable-error.png)

## Reproduce the images

Run `./Scripts/screenshots.sh` from the repository root. The capture runner creates an isolated temporary JSON store, drives the real review model, and renders `ContentView` through `NSHostingView.cacheDisplay` at 1280 × 900. Temporary data is removed afterward. It requests no screen-recording permission and does not capture any other application.
