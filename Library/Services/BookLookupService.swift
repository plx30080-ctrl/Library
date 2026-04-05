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
        // Search API returns an array of strings
        if let arr = try? container.decode([String].self) {
            sentences = arr
        } else if let str = try? container.decode(String.self) {
            sentences = [str]
        } else {
            sentences = []
        }
    }
}

// MARK: - Service

/// Looks up book metadata using the Open Library Search API.
class BookLookupService {
    static let shared = BookLookupService()
    private init() {}

    private let session: URLSession = .shared

    // MARK: Public API

    /// Search by ISBN. Falls back to title/author search if ISBN returns no results.
    func lookup(isbn: String) async throws -> Book? {
        // First try ISBN-specific search
        if let book = try await searchByISBN(isbn) {
            return book
        }
        // Nothing found
        return nil
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
        let books = try await fetch(urlString: urlString)
        return books.first
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
