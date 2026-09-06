# Architecture

Tabiori is a native iPhone application using SwiftUI, Observation, MapKit, PhotosUI, QuickLook, ImageIO and PDFKit. It targets iOS 17 or later, uses Swift 5 language mode, and has no third-party dependencies.

## Data and persistence

`Core/` holds Codable value types for trips, itinerary items, places, attachments and checklist items. A trip owns its items and attachment metadata. A document can optionally reference an item in the same trip.

`TripValidator` checks calendar-day bounds in the trip time zone, monetary values, coordinates, unique identifiers and document associations. `TravelRepository` validates and atomically replaces the JSON document. `AttachmentRepository` generates UUID-based file names and rejects unsafe paths and files over 25 MiB.

`AppStore` is main-actor isolated. Views edit local value copies, then call `save`. Live state changes only after persistence succeeds. An initial read error leaves the existing file intact and disables mutations. Deleting an itinerary item detaches its documents without deleting them. Deleting a trip saves the updated trip list before removing its document files.

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

All itinerary times use the trip's time zone; costs use the trip's currency without automatic conversion. Trips are limited to 366 calendar days.

## Testing

Foundation logic is exposed through the TravelCore Swift Package. XCTest UI tests use a separate `Tabiori-UITests` application-support directory through the `--uitesting` argument. `--reset-data` only affects that directory and is ignored without `--uitesting`. Xcode synchronized groups include new Swift files in App, Core and UITests automatically.
