import SwiftUI

// MARK: - BookcaseView

/// Shows the library as a bookcase: books stand upright and you see their spines,
/// grouped into shelves that fill across the screen width.
struct BookcaseView: View {
    let books: [Book]

    private let maxSpineHeight: CGFloat = 180
    private let shelfThickness: CGFloat = 18
    private let hPadding: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                let rowWidth = proxy.size.width - hPadding * 2
                let shelves = buildShelves(maxWidth: rowWidth)
                LazyVStack(spacing: 0) {
                    ForEach(Array(shelves.enumerated()), id: \.offset) { _, row in
                        BookshelfRow(
                            books: row,
                            maxSpineHeight: maxSpineHeight,
                            shelfThickness: shelfThickness
                        )
                    }
                }
                .padding(.horizontal, hPadding)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
            .background(
                // Warm off-white wall behind the shelves
                Color(red: 0.93, green: 0.90, blue: 0.84)
                    .ignoresSafeArea()
            )
        }
    }

    // MARK: - Layout helpers

    /// Derives the spine width in points from page count and binding type.
    /// When page count is unknown we fall back to a title-length heuristic so
    /// manually-entered books without metadata still look reasonable.
    private func spineWidth(for book: Book) -> CGFloat {
        let minW: CGFloat = 22
        let maxW: CGFloat = 76
        if let pages = book.pageCount, pages > 0 {
            let w = book.binding.baseThicknessPt + CGFloat(pages) * book.binding.pointsPerPage
            return min(max(w, minW), maxW)
        }
        // Fallback: title-length heuristic
        let len = CGFloat(max(book.title.count, 4))
        return min(max(len * 1.8 + 10, minW), maxW)
    }

    private func buildShelves(maxWidth: CGFloat) -> [[Book]] {
        var shelves: [[Book]] = []
        var row: [Book] = []
        var used: CGFloat = 0
        for book in books {
            let w = spineWidth(for: book)
            if !row.isEmpty && used + w > maxWidth {
                shelves.append(row)
                row = [book]
                used = w
            } else {
                row.append(book)
                used += w
            }
        }
        if !row.isEmpty { shelves.append(row) }
        return shelves
    }
}

// MARK: - BookshelfRow

private struct BookshelfRow: View {
    let books: [Book]
    let maxSpineHeight: CGFloat
    let shelfThickness: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Books sit on the shelf with bottom alignment
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookSpineView(book: book, maxHeight: maxSpineHeight)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            shelfPlank
        }
        // Wall gap between shelves
        .padding(.top, 30)
    }

    private var shelfPlank: some View {
        ZStack(alignment: .top) {
            // Main wood-grain surface (top face of the shelf)
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.82, green: 0.62, blue: 0.34), location: 0.0),
                    .init(color: Color(red: 0.66, green: 0.47, blue: 0.22), location: 0.55),
                    .init(color: Color(red: 0.50, green: 0.34, blue: 0.14), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Vertical grain lines (deterministic positions, no random)
            Canvas { ctx, size in
                let grainLines: [(CGFloat, Double)] = [
                    (10, 0.05), (24, 0.03), (42, 0.06), (60, 0.04), (78, 0.05),
                    (98, 0.03), (120, 0.06), (142, 0.04), (162, 0.05), (188, 0.03),
                    (208, 0.06), (230, 0.04), (252, 0.05), (272, 0.03), (298, 0.06),
                    (318, 0.04), (342, 0.05), (360, 0.03),
                ]
                for (baseX, opacity) in grainLines {
                    var x = baseX
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + 1.5, y: size.height))
                        ctx.stroke(path, with: .color(.black.opacity(opacity)), lineWidth: 1)
                        x += 380
                    }
                }
            }
            // Specular highlight along the top lip
            Rectangle()
                .fill(Color.white.opacity(0.30))
                .frame(height: 2)
        }
        .frame(height: shelfThickness)
        // Darker front face / lower lip of the board
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(red: 0.48, green: 0.32, blue: 0.13),
                    Color(red: 0.35, green: 0.22, blue: 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 4)
        }
        .shadow(color: .black.opacity(0.40), radius: 5, x: 0, y: 4)
    }
}

// MARK: - BookSpineView

private struct BookSpineView: View {
    let book: Book
    let maxHeight: CGFloat

    @State private var coverImage: UIImage? = nil

    /// Spine width — derived from page count + binding, else title-length fallback.
    private var width: CGFloat {
        let minW: CGFloat = 22
        let maxW: CGFloat = 76
        if let pages = book.pageCount, pages > 0 {
            let w = book.binding.baseThicknessPt + CGFloat(pages) * book.binding.pointsPerPage
            return min(max(w, minW), maxW)
        }
        let len = CGFloat(max(book.title.count, 4))
        return min(max(len * 1.8 + 10, minW), maxW)
    }

    /// Deterministic height variation using stable UUID bytes so each book
    /// always stands at the same height across launches.
    private var height: CGFloat {
        let u = book.id.uuid
        let h = (Int(u.0) &* 13) &+ (Int(u.1) &* 7) &+ Int(u.2)
        let variation = CGFloat(abs(h) % 36)  // 0…35 pt
        return maxHeight - 22 + variation       // (maxHeight-22)…(maxHeight+13)
    }

    var body: some View {
        ZStack {
            // 1. Base: cover image or deterministic colour
            spineBackground
                .frame(width: width, height: height)
                .clipped()

            // 2. Woven linen/cloth grain
            grainOverlay
                .frame(width: width, height: height)
                .clipped()
                .allowsHitTesting(false)

            // 3. Horizontal gradient simulating spine curvature
            spineShading
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            // 4. Thin bright strip on the left — front-cover binding edge
            leftBindingHighlight
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            // 5. Dark gradient on the right — spine curving away from viewer
            rightEdgeShadow
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            // 6. Page block at the top (stacked paper lines)
            topPageEdge
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            // 7. Page block at the bottom
            bottomPageEdge
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            // 8. Ambient shadow from above — gives the book a sense of depth
            topAmbientShadow
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            // 9. Rotated title + author text
            spineText
                .frame(width: width, height: height)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
        // Each book casts a subtle shadow on its right neighbour
        .shadow(color: .black.opacity(0.22), radius: 2, x: 2, y: 1)
        .onAppear { loadCover() }
        .onChange(of: book.localCoverImageFileName) { _, _ in loadCover() }
    }

    // MARK: - Layer implementations

    @ViewBuilder
    private var spineBackground: some View {
        if let img = coverImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            book.spineColor
        }
    }

    /// Diagonal crosshatch — imitates woven cloth bookbinding.
    private var grainOverlay: some View {
        Canvas { ctx, size in
            let step: CGFloat = 3.5
            // First diagonal (bottom-left → top-right)
            var offset: CGFloat = -size.height
            while offset < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                ctx.stroke(path, with: .color(.white.opacity(0.055)), lineWidth: 0.7)
                offset += step
            }
            // Second diagonal (top-left → bottom-right)
            offset = -size.height
            while offset < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: offset + size.height, y: 0))
                path.addLine(to: CGPoint(x: offset, y: size.height))
                ctx.stroke(path, with: .color(.black.opacity(0.040)), lineWidth: 0.7)
                offset += step
            }
        }
    }

    /// Multi-stop horizontal gradient: dark at both edges, brighter centre-left.
    /// Creates the illusion of the spine gently curving around the book block.
    private var spineShading: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.26), location: 0.00),
                .init(color: .black.opacity(0.04), location: 0.12),
                .init(color: .clear,               location: 0.32),
                .init(color: .white.opacity(0.09), location: 0.52),
                .init(color: .black.opacity(0.06), location: 0.76),
                .init(color: .black.opacity(0.32), location: 1.00),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Bright vertical strip on the very left — the front-cover hinge.
    private var leftBindingHighlight: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.white.opacity(0.30), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: min(width * 0.16, 7))
            Spacer(minLength: 0)
        }
    }

    private var rightEdgeShadow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [.clear, .black.opacity(0.40)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: min(width * 0.20, 9))
        }
    }

    /// Alternating cream / light-grey lines simulating stacked paper.
    private var topPageEdge: some View {
        VStack(spacing: 0) {
            ZStack {
                // Stacked paper lines
                Canvas { ctx, size in
                    let light = Color(red: 0.97, green: 0.95, blue: 0.90)
                    let shadow = Color(red: 0.86, green: 0.84, blue: 0.78)
                    var y: CGFloat = 0
                    var i = 0
                    while y < size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(path, with: .color(i.isMultiple(of: 2) ? light : shadow), lineWidth: 1)
                        y += 1; i += 1
                    }
                }
                // Soft shadow that rounds the top edge
                LinearGradient(
                    colors: [.black.opacity(0.18), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 8)
            Spacer(minLength: 0)
        }
    }

    private var bottomPageEdge: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Canvas { ctx, size in
                let light = Color(red: 0.97, green: 0.95, blue: 0.90)
                let shadow = Color(red: 0.86, green: 0.84, blue: 0.78)
                var y: CGFloat = 0
                var i = 0
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(path, with: .color(i.isMultiple(of: 2) ? light : shadow), lineWidth: 1)
                    y += 1; i += 1
                }
            }
            .frame(height: 5)
        }
    }

    /// Gradient from top simulates overhead lighting casting the book into slight shadow.
    private var topAmbientShadow: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.20), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 14)
            Spacer(minLength: 0)
        }
    }

    private var spineText: some View {
        VStack(spacing: 2) {
            Text(book.title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.75), radius: 1.5, x: 0, y: 0)
            Text(book.author)
                .font(.system(size: 8.5, weight: .regular))
                .lineLimit(1)
                .foregroundColor(.white.opacity(0.90))
                .shadow(color: .black.opacity(0.55), radius: 1, x: 0, y: 0)
        }
        .padding(.horizontal, 4)
        .frame(width: height - 24, height: width - 6)
        .rotationEffect(.degrees(90))
        .frame(width: width, height: height)
    }

    private func loadCover() {
        if let name = book.localCoverImageFileName {
            coverImage = PersistenceService.shared.coverImage(named: name)
        } else {
            coverImage = nil
        }
    }
}
