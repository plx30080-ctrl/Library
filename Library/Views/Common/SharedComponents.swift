import SwiftUI

// Pill-shaped tag badge
struct TagBadge: View {
    let tag: Tag

    var body: some View {
        Text(tag.name)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tag.color.opacity(0.2))
            .foregroundColor(tag.color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tag.color.opacity(0.4), lineWidth: 1))
    }
}

// Async cover image with placeholder
struct BookCoverImage: View {
    let book: Book

    @State private var uiImage: UIImage? = nil
    @State private var remoteImage: UIImage? = nil

    var body: some View {
        Group {
            if let img = uiImage ?? remoteImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                    Image(systemName: "book.closed")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
        }
        .onAppear { loadImages() }
        .onChange(of: book.localCoverImageFileName) { loadImages() }
    }

    private func loadImages() {
        // Local cover takes precedence
        if let fileName = book.localCoverImageFileName {
            uiImage = PersistenceService.shared.coverImage(named: fileName)
        }
        // Fall back to remote cover URL
        if uiImage == nil, let urlString = book.coverImageURL, let url = URL(string: urlString) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    await MainActor.run { remoteImage = img }
                }
            }
        }
    }
}
