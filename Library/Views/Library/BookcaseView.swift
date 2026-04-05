import SwiftUI

// MARK: - BookcaseView

/// Shows the library as a bookcase: books stand upright and you see their spines,
/// grouped into shelves that wrap across the screen width.
struct BookcaseView: View {
    let books: [Book]

    private let shelfHeight: CGFloat = 170
    private let shelfThickness: CGFloat = 14
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
                            shelfHeight: shelfHeight,
                            shelfThickness: shelfThickness
                        )
                    }
                }
                .padding(.horizontal, hPadding)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    // MARK: - Layout helpers

    private func spineWidth(for book: Book) -> CGFloat {
        let len = CGFloat(max(book.title.count, 4))
        return min(max(len * 1.7 + 12, 26), 52)
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
    let shelfHeight: CGFloat
    let shelfThickness: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookSpineView(book: book, height: shelfHeight)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            shelfPlank
        }
    }

    private var shelfPlank: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.70, green: 0.50, blue: 0.28),
                    Color(red: 0.48, green: 0.32, blue: 0.14),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Specular highlight along the top lip of the shelf
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(height: 2)
        }
        .frame(height: shelfThickness)
        .shadow(color: .black.opacity(0.40), radius: 3, x: 0, y: 3)
    }
}

// MARK: - BookSpineView

private struct BookSpineView: View {
    let book: Book
    let height: CGFloat

    @State private var coverImage: UIImage? = nil

    private var width: CGFloat {
        let len = CGFloat(max(book.title.count, 4))
        return min(max(len * 1.7 + 12, 26), 52)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background: cover image squeezed to spine, else a palette colour
            spineBackground
                .frame(width: width, height: height)
                .clipped()

            // Cream-coloured page edge at the top of the book
            pageEdge

            // Title + author rotated to run along the spine (top → bottom)
            spineText

            // Right-edge darkening simulates the book's depth
            rightEdgeShadow
        }
        .frame(width: width, height: height)
        .onAppear { loadCover() }
        .onChange(of: book.localCoverImageFileName) { _, _ in loadCover() }
    }

    // MARK: Sub-views

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

    private var pageEdge: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.95, green: 0.93, blue: 0.88).opacity(0.55))
                .frame(height: 3)
            Spacer()
        }
    }

    /// Text that runs top-to-bottom along the spine.
    /// Strategy: create a wide/short container, rotate 90°, then override the
    /// layout frame to match the actual spine dimensions.
    private var spineText: some View {
        VStack(spacing: 2) {
            Text(book.title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.70), radius: 1, x: 0, y: 0)
            Text(book.author)
                .font(.system(size: 8.5, weight: .regular))
                .lineLimit(1)
                .foregroundColor(.white.opacity(0.90))
                .shadow(color: .black.opacity(0.55), radius: 1, x: 0, y: 0)
        }
        .padding(.horizontal, 4)
        // Pre-rotation frame: wide (runs along spine length) × narrow (fits spine width)
        .frame(width: height - 20, height: width - 6)
        .rotationEffect(.degrees(90))
        // Post-rotation: snap layout frame back to spine dimensions
        .frame(width: width, height: height)
    }

    private var rightEdgeShadow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.28)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: min(width * 0.28, 10))
        }
    }

    private func loadCover() {
        if let name = book.localCoverImageFileName {
            coverImage = PersistenceService.shared.coverImage(named: name)
        } else {
            coverImage = nil
        }
    }
}
