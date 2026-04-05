import SwiftUI

struct BookRowView: View {
    let book: Book
    @EnvironmentObject var libraryVM: LibraryViewModel

    var body: some View {
        HStack(spacing: 12) {
            BookCoverImage(book: book)
                .frame(width: 50, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(radius: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let collName = libraryVM.collectionName(for: book.collectionId) {
                    Label(collName, systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Tag badges
                if !book.tagIds.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(book.tagIds, id: \.self) { tagId in
                                if let tag = libraryVM.tag(for: tagId) {
                                    TagBadge(tag: tag)
                                }
                            }
                        }
                    }
                }

                if book.ebookFile != nil {
                    Label("Ebook attached", systemImage: "doc.text")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
