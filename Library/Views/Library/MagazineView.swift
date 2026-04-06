import SwiftUI

// MARK: - MagazineView

/// Shows the library as a cover grid — each cell is the front cover of a book.
/// The number of columns is controlled by the caller.
struct MagazineView: View {
    let books: [Book]
    let columns: Int

    var body: some View {
        ScrollView {
            if books.isEmpty {
                ContentUnavailableView(
                    "No Books",
                    systemImage: "books.vertical",
                    description: Text("Add books using the + button or scan a barcode.")
                )
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(books) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            MagazineCellView(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: max(1, columns))
    }
}

// MARK: - MagazineCellView

private struct MagazineCellView: View {
    let book: Book

    @State private var uiImage: UIImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            coverArea
            titleArea
        }
    }

    // MARK: Cover

    private var coverArea: some View {
        GeometryReader { geo in
            ZStack {
                if let img = uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    book.spineColor
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: geo.size.width * 0.35))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)
            // Subtle page-edge strip on the left
            .overlay(alignment: .leading) {
                LinearGradient(
                    colors: [.white.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 5)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .onAppear { loadImage() }
        .onChange(of: book.localCoverImageFileName) { _, _ in loadImage() }
        .onChange(of: book.coverImageURL) { _, _ in loadImage() }
    }

    // MARK: Title / author below cover

    private var titleArea: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(book.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)
            Text(book.author)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: Image loading

    private func loadImage() {
        // Local cover takes priority
        if let name = book.localCoverImageFileName,
           let img = PersistenceService.shared.coverImage(named: name) {
            uiImage = img
            return
        }
        uiImage = nil
        // Fetch remote cover
        if let urlString = book.coverImageURL, let url = URL(string: urlString) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    await MainActor.run { uiImage = img }
                }
            }
        }
    }
}
