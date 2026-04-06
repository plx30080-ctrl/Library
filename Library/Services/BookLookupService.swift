import Foundation

// MARK: - Open Library API response shapes

private struct OLSearchResult: Decodable {
    let numFound: Int
    let docs: [OLDoc]

    enum CodingKeys: String, CodingKey {
        case numFound = "numFound"
        case docs
    }
}

private struct OLDoc: Decodable {
    let title: String?
    let authorName: [String]?
    let isbn: [String]?
    let coverI: Int?
    let publishDate: [String]?
    let publisher: [String]?
    let numberOfPagesMedian: Int?
    let firstSentence: OLFirstSentence?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case isbn
        case coverI = "cover_i"
        case publishDate = "publish_date"
        case publisher
        case numberOfPagesMedian = "number_of_pages_median"
        case firstSentence = "first_sentence"
    }
}

/// Open Library returns `first_sentence` as an array of strings in the Search API.
private struct OLFirstSentence: Decodable {
    let sentences: [String]

    var value: String? { sentences.first }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([String].self) {
            sentences = arr
        } else if let str = try? container.decode(String.self) {
            sentences = [str]
        } else {
            sentences = []
        }
    }
}

// MARK: - Google Books API response shapes

private struct GBResponse: Decodable {
    let totalItems: Int
    let items: [GBItem]?
}

private struct GBItem: Decodable {
    let volumeInfo: GBVolumeInfo
}

private struct GBVolumeInfo: Decodable {
    let title: String?
    let authors: [String]?
    let description: String?
    let publisher: String?
    let publishedDate: String?
    let pageCount: Int?
    let imageLinks: GBImageLinks?
}

private struct GBImageLinks: Decodable {
    let thumbnail: String?
    let smallThumbnail: String?
}

// MARK: - Service

/// Looks up book metadata using the Open Library Search API.
class BookLookupService {
    static let shared = BookLookupService()
    private init() {}

    private let session: URLSession = .shared

    // MARK: Public API

    /// Search by ISBN. Tries Open Library first, then supplements or falls back
    /// to Google Books for any missing cover URL, description, or page count.
    func lookup(isbn: String) async throws -> Book? {
        let clean = isbn.replacingOccurrences(of: "-", with: "")
        var book = try await searchByISBN(clean)

        // Try Google Books to fill gaps (missing cover, description, pageCount)
        if let gb = try? await fetchGoogleBooks(isbn: clean) {
            if book == nil {
                book = gb
            } else {
                // Supplement missing fields only
                if book!.coverImageURL == nil   { book!.coverImageURL  = gb.coverImageURL }
                if book!.description == nil     { book!.description    = gb.description }
                if book!.pageCount == nil       { book!.pageCount      = gb.pageCount }
                if book!.publisher == nil       { book!.publisher      = gb.publisher }
                if book!.publishedDate == nil   { book!.publishedDate  = gb.publishedDate }
            }
        }
        return book
    }

    /// Free-text search by title and/or author.
    func search(query: String) async throws -> [Book] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://openlibrary.org/search.json?q=\(encoded)&limit=20&fields=title,author_name,isbn,cover_i,publish_date,publisher,number_of_pages_median,first_sentence"
        return try await fetch(urlString: urlString)
    }

    /// Search by title alone.
    func searchByTitle(_ title: String) async throws -> [Book] {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "https://openlibrary.org/search.json?title=\(encoded)&limit=20&fields=title,author_name,isbn,cover_i,publish_date,publisher,number_of_pages_median,first_sentence"
        return try await fetch(urlString: urlString)
    }

    // MARK: Private helpers

    private func searchByISBN(_ isbn: String) async throws -> Book? {
        let clean = isbn.replacingOccurrences(of: "-", with: "")
        let urlString = "https://openlibrary.org/search.json?isbn=\(clean)&limit=1&fields=title,author_name,isbn,cover_i,publish_date,publisher,number_of_pages_median,first_sentence"
        var books = try await fetch(urlString: urlString)
        guard !books.isEmpty else { return nil }
        // Supplement with binding info from the Books API
        if let binding = try? await fetchBinding(isbn: clean) {
            books[0].binding = binding
        }
        return books.first
    }

    /// Fetches `physical_format` for a single ISBN from the Open Library Books API.
    private func fetchBinding(isbn: String) async throws -> BindingType {
        let urlString = "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&jscmd=data&format=json"
        guard let url = URL(string: urlString) else { return .unknown }
        let (data, _) = try await session.data(from: url)
        // Response: { "ISBN:xxx": { "physical_format": "Paperback", ... } }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = root["ISBN:\(isbn)"] as? [String: Any],
              let format = entry["physical_format"] as? String else {
            return .unknown
        }
        return bindingType(from: format)
    }

    private func bindingType(from physicalFormat: String) -> BindingType {
        let lower = physicalFormat.lowercased()
        if lower.contains("hardcover") || lower.contains("hardback") || lower.contains("hard cover") {
            return .hardback
        }
        if lower.contains("paperback") || lower.contains("softcover") || lower.contains("soft cover")
            || lower.contains("mass market") || lower.contains("trade paper") {
            return .paperback
        }
        return .unknown
    }

    /// Queries Google Books for a single ISBN.  Returns a Book with whatever
    /// fields Google provided; caller merges into the OL result.
    private func fetchGoogleBooks(isbn: String) async throws -> Book? {
        let encoded = isbn.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? isbn
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=isbn:\(encoded)&maxResults=1"
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await session.data(from: url)
        guard let resp = try? JSONDecoder().decode(GBResponse.self, from: data),
              let item = resp.items?.first else { return nil }
        let info = item.volumeInfo
        // Upgrade http thumbnail to https and request larger size
        let rawThumb = info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail
        let thumb = rawThumb?
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "&zoom=1", with: "&zoom=2")
        return Book(
            title: info.title ?? "Unknown Title",
            author: info.authors?.first ?? "Unknown Author",
            isbn: isbn,
            coverImageURL: thumb,
            description: info.description,
            publisher: info.publisher,
            publishedDate: info.publishedDate,
            pageCount: info.pageCount
        )
    }

    private func fetch(urlString: String) async throws -> [Book] {
        guard let url = URL(string: urlString) else { return [] }
        let (data, _) = try await session.data(from: url)
        let result = try JSONDecoder().decode(OLSearchResult.self, from: data)
        return result.docs.map { doc in
            var book = Book(
                title: doc.title ?? "Unknown Title",
                author: doc.authorName?.first ?? "Unknown Author",
                isbn: doc.isbn?.first,
                coverImageURL: doc.coverI.map { "https://covers.openlibrary.org/b/id/\($0)-M.jpg" },
                description: doc.firstSentence?.value,
                publisher: doc.publisher?.first,
                publishedDate: doc.publishDate?.first,
                pageCount: doc.numberOfPagesMedian
            )
            book.isbn = book.isbn ?? doc.isbn?.first
            return book
        }
    }
}
