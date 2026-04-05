# Library

Library App for iOS that allows you to scan barcodes, import information from the book, and create a digital library/catalogue.

## Features

- **Barcode / ISBN scanning** – Point your camera at any ISBN or EAN-13 barcode to automatically look up and import book details.
- **Book information lookup** – Powered by the [Open Library](https://openlibrary.org/) API. If a barcode scan doesn't produce a match, you can search by title or free-text query directly in the *Add Book* form.
- **Alphabetical & other sort orders** – Sort your library by title (A–Z / Z–A), author (A–Z / Z–A), or date added.
- **Collections (subgroups)** – Create named collections to organise your books into shelves or reading lists.
- **Tagging** – Create colour-coded tags and assign them to books. Filter the library view by one or more tags at once.
- **Ebook file import** – Import `.epub`, `.pdf`, `.mobi`, `.azw`, `.txt`, and other file types directly from Files or iCloud Drive.
- **Customisable ebook entries** – Rename the ebook, set a custom cover image, and add personal notes for each file.

## Requirements

- **Xcode 15** or later
- **iOS 17.0** deployment target (iPhone & iPad)

## Getting Started

1. Clone this repository.
2. Open `Library.xcodeproj` in Xcode.
3. Select your development team in *Signing & Capabilities*.
4. Build and run on a device or simulator (`⌘R`).

> **Note:** Barcode scanning requires a physical device with a camera. Camera permission must be granted on first launch.

## Project Structure

```
Library/
├── Library.xcodeproj/          Xcode project
└── Library/                    App source
    ├── LibraryApp.swift         App entry point
    ├── ContentView.swift        Tab navigation
    ├── Models/
    │   ├── Book.swift           Core book model (supports ebook attachment)
    │   ├── BookCollection.swift Named subgroup / shelf
    │   └── Tag.swift            Colour-coded tag
    ├── ViewModels/
    │   ├── LibraryViewModel.swift  All CRUD, sorting, filtering, persistence
    │   └── ScannerViewModel.swift  AVFoundation barcode scanning
    ├── Views/
    │   ├── Library/
    │   │   ├── LibraryView.swift    Main library list with filter/sort bar
    │   │   ├── BookRowView.swift    Single row showing cover + metadata
    │   │   ├── BookDetailView.swift Full detail / edit view
    │   │   └── AddBookView.swift    New book form with ISBN/API lookup
    │   ├── Scanner/
    │   │   └── BarcodeScannerView.swift  Camera + live barcode detection
    │   ├── Collections/
    │   │   └── CollectionsView.swift     Create/edit/delete collections
    │   ├── Tags/
    │   │   └── TagsView.swift            Create/edit/delete colour tags
    │   ├── EbookFiles/
    │   │   └── EbookFilesView.swift      Import and customise ebook files
    │   └── Common/
    │       ├── SharedComponents.swift    TagBadge, BookCoverImage
    │       └── DocumentPickerView.swift  UIDocumentPickerViewController wrapper
    ├── Services/
    │   ├── BookLookupService.swift   Open Library REST API client
    │   └── PersistenceService.swift  JSON file storage in Documents directory
    └── Extensions/
        └── Extensions.swift          Color+hex, View helpers
```

## Permissions

The app requests the following permissions at runtime:

| Permission | Reason |
|---|---|
| **Camera** | Scan ISBN / EAN-13 barcodes |
| **Photo Library** | Set custom cover images for books and ebooks |

## Data Storage

All data is persisted as JSON files in the app's sandboxed Documents directory:

| File | Contents |
|---|---|
| `books.json` | Book catalogue |
| `collections.json` | Named collections |
| `tags.json` | Tag definitions |
| `ebooks/` | Imported ebook files |
| `covers/` | User-supplied cover images |

