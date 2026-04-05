import Foundation
import UIKit

/// Persists library data as JSON files in the app's Documents directory.
class PersistenceService {
    static let shared = PersistenceService()
    private init() {}

    private let fileManager = FileManager.default

    // MARK: - File URLs

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var booksURL: URL {
        documentsURL.appendingPathComponent("books.json")
    }

    private var collectionsURL: URL {
        documentsURL.appendingPathComponent("collections.json")
    }

    private var tagsURL: URL {
        documentsURL.appendingPathComponent("tags.json")
    }

    var ebookFilesDirectory: URL {
        let dir = documentsURL.appendingPathComponent("ebooks", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    var coverImagesDirectory: URL {
        let dir = documentsURL.appendingPathComponent("covers", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Books

    func saveBooks(_ books: [Book]) {
        encode(books, to: booksURL)
    }

    func loadBooks() -> [Book] {
        decode([Book].self, from: booksURL) ?? []
    }

    // MARK: - Collections

    func saveCollections(_ collections: [BookCollection]) {
        encode(collections, to: collectionsURL)
    }

    func loadCollections() -> [BookCollection] {
        decode([BookCollection].self, from: collectionsURL) ?? []
    }

    // MARK: - Tags

    func saveTags(_ tags: [Tag]) {
        encode(tags, to: tagsURL)
    }

    func loadTags() -> [Tag] {
        decode([Tag].self, from: tagsURL) ?? []
    }

    // MARK: - Ebook file management

    /// Copy a source file URL into the app's ebooks directory. Returns the destination filename.
    func importEbookFile(from sourceURL: URL) throws -> String {
        let destName = UUID().uuidString + "_" + sourceURL.lastPathComponent
        let destURL = ebookFilesDirectory.appendingPathComponent(destName)
        // Gain access to security-scoped resource if needed
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }
        try fileManager.copyItem(at: sourceURL, to: destURL)
        return destName
    }

    /// Delete an ebook file by filename.
    func deleteEbookFile(named fileName: String) {
        let url = ebookFilesDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }

    func ebookFileURL(named fileName: String) -> URL {
        ebookFilesDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Cover image management

    /// Save a UIImage as a cover image. Returns the stored filename.
    func saveCoverImage(_ image: UIImage, forBookId id: UUID) throws -> String {
        let fileName = "cover_\(id.uuidString).jpg"
        let url = coverImagesDirectory.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "PersistenceService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not encode image"])
        }
        try data.write(to: url)
        return fileName
    }

    func coverImageURL(named fileName: String) -> URL {
        coverImagesDirectory.appendingPathComponent(fileName)
    }

    func coverImage(named fileName: String) -> UIImage? {
        let url = coverImagesDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteCoverImage(named fileName: String) {
        let url = coverImagesDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Generic encode / decode helpers

    private func encode<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("PersistenceService encode error: \(error)")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("PersistenceService decode error: \(error)")
            return nil
        }
    }
}
