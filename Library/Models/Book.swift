import Foundation

// Supported ebook file formats
enum EbookFormat: String, Codable, CaseIterable, Identifiable {
    case epub = "epub"
    case pdf = "pdf"
    case mobi = "mobi"
    case azw = "azw"
    case azw3 = "azw3"
    case txt = "txt"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .epub: return "EPUB"
        case .pdf: return "PDF"
        case .mobi: return "MOBI"
        case .azw: return "AZW"
        case .azw3: return "AZW3"
        case .txt: return "TXT"
        case .other: return "Other"
        }
    }

    /// UTType identifiers used by UIDocumentPickerViewController
    static var supportedUTTypes: [String] {
        [
            "org.idpf.epub-container",    // epub
            "com.adobe.pdf",              // pdf
            "public.text",               // txt
            "public.data"                // generic / mobi / azw
        ]
    }
}

// An ebook file that has been imported into the library
struct EbookFile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// Display name (user-editable)
    var name: String
    /// Filename stored in the app's documents directory
    var fileName: String
    /// Original file extension / format
    var format: EbookFormat
    /// Optional user-supplied cover image filename stored in documents directory
    var customCoverFileName: String?
    /// User notes for this ebook
    var notes: String?
    var dateImported: Date = Date()
}

// Core book model
struct Book: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var author: String
    var isbn: String?
    /// Remote URL for the cover thumbnail (from API)
    var coverImageURL: String?
    /// Local cover image filename stored in documents directory
    var localCoverImageFileName: String?
    var description: String?
    var publisher: String?
    var publishedDate: String?
    var pageCount: Int?
    /// IDs of Tag objects associated with this book
    var tagIds: [UUID] = []
    /// ID of the BookCollection this book belongs to (nil = uncategorised)
    var collectionId: UUID?
    /// Attached ebook file, if any
    var ebookFile: EbookFile?
    /// Free-form notes
    var notes: String?
    var dateAdded: Date = Date()

    // Convenience initialiser for manually-added books
    init(
        title: String,
        author: String,
        isbn: String? = nil,
        coverImageURL: String? = nil,
        description: String? = nil,
        publisher: String? = nil,
        publishedDate: String? = nil,
        pageCount: Int? = nil
    ) {
        self.title = title
        self.author = author
        self.isbn = isbn
        self.coverImageURL = coverImageURL
        self.description = description
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.pageCount = pageCount
    }
}
