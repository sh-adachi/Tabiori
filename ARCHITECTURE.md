# Architecture

Tabiori is a native iPhone application using SwiftUI, Observation, MapKit, PhotosUI, QuickLook, ImageIO and PDFKit. It targets iOS 17 or later, uses Swift 5 language mode, and has no third-party dependencies.

Version 1.1 adds persisted application settings and defaults for newly created trips.

## Data and persistence

`Core/` holds Codable value types for trips, itinerary items, places, attachments and checklist items. A trip owns its items and attachment metadata. A document can optionally reference an item in the same trip.

`TripValidator` checks calendar-day bounds in the trip time zone, monetary values, coordinates, unique identifiers and document associations. `TravelRepository` validates and atomically replaces the JSON document. `AttachmentRepository` generates UUID-based file names and rejects unsafe paths and files over 25 MiB.

`AppStore` is main-actor isolated. Views edit local value copies, then call `save`. Live state changes only after persistence succeeds. An initial read error leaves the existing file intact and disables mutations. Deleting an itinerary item detaches its documents without deleting them. Deleting a trip saves the updated trip list before removing its document files.

Normal storage lives in `Library/Application Support/Tabiori/`: `trips.json` contains trips, `settings.json` contains application settings, and `Attachments/` contains imported files. Travel and settings loading have separate failure states; a failed settings read disables settings mutations until an explicit reload succeeds.

## Application settings

`AppSettings` is a Codable value type with validated defaults: system appearance, JPY currency, Asia/Tokyo time zone, automatic checklist creation enabled, a five-item checklist template, public transit directions, and reservation-code sharing disabled. The template supports up to 100 items of 200 characters each. `AppSettingsRepository` validates settings and atomically writes `settings.json`; a missing file uses defaults, while an unreadable or invalid existing file produces an error without replacing its contents.

`SettingsView` edits a local draft. Save validates and persists before updating `AppStore.settings`; cancel dismisses without applying changes. The gear button in `TripsView` opens settings, and the About/help screen is available inside settings.

`TabioriApp` applies the saved light, dark or system appearance. `TripEditorView` uses default currency, time zone and checklist settings for new trips only. Changes to defaults leave existing trips unchanged. Metadata edits merge into the latest saved trip to preserve itinerary items, documents and checklist state.

Saved directions preferences select public transit, walking or driving when opening Apple Maps. `TripExport.text(for:includeReservationCodes:)` uses the sharing preference to include or omit structured `reservationCode` fields. This option does not redact free-text notes or attachment contents, and attachments are shared separately through their preview.

## Attachments

`AttachmentImport` uses bounded file reads. Photos are downsampled and re-encoded to JPEG with orientation applied and original metadata removed. PDFs are checked with PDFKit before storage. The UI writes the prepared file, then saves metadata; a failed metadata save removes the newly created file. Bulk imports report failures per file while keeping successful imports.

Each import commits against the latest trip value after asynchronous work. If the trip has been deleted it aborts; if the associated itinerary item has been removed it attaches the document to the trip instead. QuickLook previews local files, and the system share sheet exports them on demand.

## Screens

- `TripsView`: searchable upcoming/past/all trips, first-run introduction and explicit sample creation.
- `TripDetailView`: trip summary, expense summary, document/map/checklist navigation, calendar-day itinerary.
- `TripEditorView` / `ItemEditorView`: local drafts, validation errors, save or cancel.
- `ItemDetailView`: transport and booking metadata, notes, location, completion and deletion.
- `PlacePickerView` / `TripMapView`: cancellable Apple Maps search, manual coordinates, saved map annotations and directions.
- `AttachmentsView`: import, preview, share and delete photos/PDFs.
- `ChecklistView` / `BudgetView`: preparation and expense tracking.
- `SettingsView`: appearance, new-trip defaults, checklist template, directions and sharing preferences; save/cancel and access to About/help.

All itinerary times use the trip's time zone; costs use the trip's currency without automatic conversion. Trips are limited to 366 calendar days.

## Testing

Foundation logic is exposed through the TravelCore Swift Package; AttachmentSupport exposes image and PDF import validation for macOS tests. Settings tests cover validation, persistence, corrupt-file handling and reservation-code sharing. XCTest UI tests use a separate `Tabiori-UITests` application-support directory through the `--uitesting` argument. This isolates both trips and settings. `--reset-data` only affects that directory and is ignored without `--uitesting`.

The eight UI tests verified before settings were added exercise real Photos and Files pickers, persisted trips and checklist state, editing/deletion, and map locations. Two additional settings UI tests verify saved defaults across relaunch, their application to new trips only, and cancellation. Their final verification status is tracked in README.md.

Xcode synchronized groups include new Swift files in App, Core and UITests automatically. The project currently selects Personal Team `92ZKW29LWX` for signing. `Scripts/deploy_iphone.sh <UDID>` builds with provisioning updates enabled, installs the signed application using `devicectl`, and launches it on the connected iPhone; another developer must select their own signing team.
