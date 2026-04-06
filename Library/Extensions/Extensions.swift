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
    /// Used only when no cover image is available.
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

extension UIImage {
    /// Samples the average colour of a narrow vertical strip at the centre of
    /// the image — a good approximation of the dominant spine colour.
    /// Returns nil if pixel data cannot be read.
    var dominantSpineColor: Color? {
        guard let cgImage = cgImage else { return nil }
        let w = cgImage.width, h = cgImage.height
        let stripW = max(1, w / 6)
        let startX = (w - stripW) / 2
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: stripW, height: h,
                                  bitsPerComponent: 8, bytesPerRow: stripW * 4,
                                  space: cs, bitmapInfo: bitmapInfo) else { return nil }
        // Draw only the centre strip into the tiny context
        ctx.draw(cgImage, in: CGRect(x: -CGFloat(startX), y: 0,
                                     width: CGFloat(w), height: CGFloat(h)))
        guard let data = ctx.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: stripW * h * 4)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        let pixels = stripW * h
        for i in 0..<pixels {
            let base = i * 4
            r += CGFloat(ptr[base])     / 255
            g += CGFloat(ptr[base + 1]) / 255
            b += CGFloat(ptr[base + 2]) / 255
        }
        let n = CGFloat(pixels)
        // Slightly darken the average so it reads as a rich spine tone
        let factor: CGFloat = 0.82
        return Color(red: Double(r / n * factor),
                     green: Double(g / n * factor),
                     blue: Double(b / n * factor))
    }
}
