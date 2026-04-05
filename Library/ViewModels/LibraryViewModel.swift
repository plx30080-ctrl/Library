import Foundation
import Combine
import UIKit

// MARK: - Sort order

enum BookSortOrder: String, CaseIterable, Identifiable {
    case dateAdded = "Date Added"
    case titleAZ = "Title (A–Z)"
    case titleZA = "Title (Z–A)"
    case authorAZ = "Author (A–Z)"
    case authorZA = "Author (Z–A)"

    var id: String { rawValue }
}

// MARK: - LibraryViewModel

@MainActor
class LibraryViewModel: ObservableObject {

    // MARK: Data

    @Published var books: [Book] = []
    @Published var collections: [BookCollection] = []
    @Published var tags: [Tag] = []

    // MARK: Filter / sort state

    @Published var sortOrder: BookSortOrder = .dateAdded
    @Published var searchText: String = ""
    @Published var selectedCollectionId: UUID? = nil
    /// nil = no tag filter; non-empty = show books that have ALL of those tags
    @Published var selectedTagIds: Set<UUID> = []

    private let persistence = PersistenceService.shared

    // MARK: Init

    init() {
        load()
    }

    // MARK: - Computed: filtered & sorted books

    var filteredBooks: [Book] {
        var result = books

        // Collection filter
        if let collId = selectedCollectionId {
            result = result.filter { $0.collectionId == collId }
        }

        // Tag filter
        if !selectedTagIds.isEmpty {
            result = result.filter { book in
                selectedTagIds.isSubset(of: Set(book.tagIds))
            }
        }

        // Search text
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.author.lowercased().contains(query) ||
                ($0.isbn?.lowercased().contains(query) ?? false)
            }
        }

        // Sort
        switch sortOrder {
        case .dateAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .titleAZ:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleZA:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .authorAZ:
            result.sort { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        case .authorZA:
            result.sort { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedDescending }
        }

        return result
    }

    // MARK: - Book CRUD

    func addBook(_ book: Book) {
        books.insert(book, at: 0)
        save()
    }

    func updateBook(_ book: Book) {
        guard let idx = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[idx] = book
        save()
    }

    func deleteBook(_ book: Book) {
        // Clean up attached ebook file if present
        if let ebook = book.ebookFile {
            persistence.deleteEbookFile(named: ebook.fileName)
        }
        // Clean up local cover
        if let cover = book.localCoverImageFileName {
            persistence.deleteCoverImage(named: cover)
        }
        books.removeAll { $0.id == book.id }
        save()
    }

    func deleteBooks(at offsets: IndexSet, in displayedBooks: [Book]) {
        offsets.forEach { idx in
            deleteBook(displayedBooks[idx])
        }
    }

    // MARK: - Collection CRUD

    func addCollection(_ collection: BookCollection) {
        collections.append(collection)
        save()
    }

    func updateCollection(_ collection: BookCollection) {
        guard let idx = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        collections[idx] = collection
        save()
    }

    func deleteCollection(_ collection: BookCollection) {
        // Unassign all books from this collection
        for i in books.indices where books[i].collectionId == collection.id {
            books[i].collectionId = nil
        }
        collections.removeAll { $0.id == collection.id }
        save()
    }

    func collectionName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return collections.first { $0.id == id }?.name
    }

    // MARK: - Tag CRUD

    func addTag(_ tag: Tag) {
        tags.append(tag)
        save()
    }

    func updateTag(_ tag: Tag) {
        guard let idx = tags.firstIndex(where: { $0.id == tag.id }) else { return }
        tags[idx] = tag
        save()
    }

    func deleteTag(_ tag: Tag) {
        // Remove tag from all books
        for i in books.indices {
            books[i].tagIds.removeAll { $0 == tag.id }
        }
        tags.removeAll { $0.id == tag.id }
        save()
    }

    func tag(for id: UUID) -> Tag? {
        tags.first { $0.id == id }
    }

    // MARK: - Ebook file import

    func importEbookFile(from url: URL, into book: inout Book) throws {
        let fileName = try persistence.importEbookFile(from: url)
        let ext = url.pathExtension.lowercased()
        let format = EbookFormat(rawValue: ext) ?? .other
        let ebookFile = EbookFile(
            name: url.deletingPathExtension().lastPathComponent,
            fileName: fileName,
            format: format
        )
        book.ebookFile = ebookFile
    }

    // MARK: - Cover image

    func saveLocalCover(_ image: UIImage, for book: inout Book) throws {
        // Remove old cover if any
        if let old = book.localCoverImageFileName {
            persistence.deleteCoverImage(named: old)
        }
        let fileName = try persistence.saveCoverImage(image, forBookId: book.id)
        book.localCoverImageFileName = fileName
    }

    func coverImage(for book: Book) -> UIImage? {
        guard let fileName = book.localCoverImageFileName else { return nil }
        return persistence.coverImage(named: fileName)
    }

    // MARK: - Persistence

    private func save() {
        persistence.saveBooks(books)
        persistence.saveCollections(collections)
        persistence.saveTags(tags)
    }

    private func load() {
        books = persistence.loadBooks()
        collections = persistence.loadCollections()
        tags = persistence.loadTags()
    }
}
