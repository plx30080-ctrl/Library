import Foundation
import SwiftUI

// A coloured tag that can be applied to books
struct Tag: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// Hex string, e.g. "#FF3B30"
    var colorHex: String

    init(name: String, colorHex: String = "#007AFF") {
        self.name = name
        self.colorHex = colorHex
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - Predefined tag colours

extension Tag {
    static let paletteColors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#007AFF", "#5856D6", "#AF52DE",
        "#FF2D55", "#8E8E93"
    ]
}
