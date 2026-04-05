import Foundation

// A named subgroup (shelf) that can contain books
struct BookCollection: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var collectionDescription: String?
    var createdAt: Date = Date()

    init(name: String, description: String? = nil) {
        self.name = name
        self.collectionDescription = description
    }
}
