import SwiftUI

// Helpers used across the app
extension Color {
    /// Initialise a Color from a CSS hex string such as "#FF3B30" or "FF3B30".
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6, let int = UInt64(hexSanitized, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Return a hex string representation of this colour (approximate – based on UIColor).
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

extension Book {
    /// A deterministic spine colour derived from the book's title.
    /// Uses a DJB2-style hash so results are stable across app launches.
    var spineColor: Color {
        let hash = title.unicodeScalars.reduce(5381) {
            ($0 &<< 5) &+ $0 &+ Int(bitPattern: UInt($1.value))
        }
        // Muted library-style palette: (hue, saturation, brightness)
        let palette: [(Double, Double, Double)] = [
            (0.00, 0.62, 0.44),   // burgundy
            (0.62, 0.60, 0.42),   // navy
            (0.33, 0.55, 0.38),   // forest green
            (0.74, 0.52, 0.40),   // violet
            (0.50, 0.58, 0.38),   // teal
            (0.07, 0.65, 0.48),   // burnt orange
            (0.08, 0.60, 0.36),   // brown
            (0.57, 0.48, 0.44),   // steel blue
            (0.20, 0.52, 0.36),   // olive
            (0.90, 0.44, 0.44),   // mauve
        ]
        let (h, s, b) = palette[abs(hash) % palette.count]
        return Color(hue: h, saturation: s, brightness: b)
    }
}
