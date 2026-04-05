import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct BookDetailView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var bookId: UUID
    @State private var book: Book

    @State private var isEditing = false
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showDeleteConfirm = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var errorMessage: String? = nil

    // Ebook rename state
    @State private var ebookRenameText: String = ""
    @State private var isRenamingEbook = false

    init(book: Book) {
        self.bookId = book.id
        _book = State(initialValue: book)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                coverSection
                infoSection
                collectionSection
                tagsSection
                notesSection
                ebookSection
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Book" : book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Done") { saveEdits() }
                        .fontWeight(.semibold)
                } else {
                    Menu {
                        Button("Edit", systemImage: "pencil") { isEditing = true }
                        Divider()
                        Button("Delete Book", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        // Restore original
                        if let original = libraryVM.books.first(where: { $0.id == bookId }) {
                            book = original
                        }
                        isEditing = false
                    }
                }
            }
        }
        .confirmationDialog("Delete this book?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                libraryVM.deleteBook(book)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showImagePicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    do {
                        try libraryVM.saveLocalCover(img, for: &book)
                        libraryVM.updateBook(book)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(supportedTypes: EbookFormat.supportedUTTypes) { url in
                do {
                    try libraryVM.importEbookFile(from: url, into: &book)
                    libraryVM.updateBook(book)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    // MARK: - Sections

    @ViewBuilder
    private var coverSection: some View {
        HStack(spacing: 16) {
            BookCoverImage(book: book)
                .frame(width: 100, height: 144)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 4)

            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Change Cover", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)

                    if book.localCoverImageFileName != nil {
                        Button(role: .destructive) {
                            if let fname = book.localCoverImageFileName {
                                PersistenceService.shared.deleteCoverImage(named: fname)
                            }
                            book.localCoverImageFileName = nil
                            libraryVM.updateBook(book)
                        } label: {
                            Label("Remove Local Cover", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                } else {
                    if let isbn = book.isbn {
                        Label(isbn, systemImage: "barcode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let publisher = book.publisher {
                        Text(publisher)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let date = book.publishedDate {
                        Text(date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let pages = book.pageCount {
                        Text("\(pages) pages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        GroupBox("Book Info") {
            VStack(alignment: .leading, spacing: 12) {
                if isEditing {
                    LabeledContent("Title") {
                        TextField("Title", text: $book.title)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Author") {
                        TextField("Author", text: $book.author)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("ISBN") {
                        TextField("ISBN", text: Binding(
                            get: { book.isbn ?? "" },
                            set: { book.isbn = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                    }
                    LabeledContent("Publisher") {
                        TextField("Publisher", text: Binding(
                            get: { book.publisher ?? "" },
                            set: { book.publisher = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Published") {
                        TextField("Year", text: Binding(
                            get: { book.publishedDate ?? "" },
                            set: { book.publishedDate = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                } else {
                    HStack {
                        Text(book.title).fontWeight(.semibold)
                        Spacer()
                    }
                    Text("by \(book.author)")
                        .foregroundColor(.secondary)
                    if let desc = book.description {
                        Text(desc)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var collectionSection: some View {
        GroupBox("Collection") {
            Picker("Collection", selection: $book.collectionId) {
                Text("None").tag(Optional<UUID>(nil))
                ForEach(libraryVM.collections) { coll in
                    Text(coll.name).tag(Optional(coll.id))
                }
            }
            .pickerStyle(.menu)
            .disabled(!isEditing)
            .onChange(of: book.collectionId) { _ in
                if !isEditing { libraryVM.updateBook(book) }
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        GroupBox("Tags") {
            VStack(alignment: .leading, spacing: 8) {
                // Current tags
                if book.tagIds.isEmpty {
                    Text("No tags assigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    FlowLayout(alignment: .leading) {
                        ForEach(book.tagIds, id: \.self) { tagId in
                            if let tag = libraryVM.tag(for: tagId) {
                                HStack(spacing: 4) {
                                    TagBadge(tag: tag)
                                    if isEditing {
                                        Button {
                                            book.tagIds.removeAll { $0 == tagId }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if isEditing {
                    let unassignedTags = libraryVM.tags.filter { !book.tagIds.contains($0.id) }
                    if !unassignedTags.isEmpty {
                        Divider()
                        Text("Add tag:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        FlowLayout(alignment: .leading) {
                            ForEach(unassignedTags) { tag in
                                Button {
                                    book.tagIds.append(tag.id)
                                } label: {
                                    TagBadge(tag: tag)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        GroupBox("Notes") {
            if isEditing {
                TextEditor(text: Binding(
                    get: { book.notes ?? "" },
                    set: { book.notes = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 80)
            } else {
                Text(book.notes ?? "No notes")
                    .foregroundColor(book.notes == nil ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var ebookSection: some View {
        GroupBox("Ebook File") {
            if let ebook = book.ebookFile {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            if isRenamingEbook {
                                TextField("Name", text: $ebookRenameText, onCommit: {
                                    guard !ebookRenameText.trimmingCharacters(in: .whitespaces).isEmpty else {
                                        isRenamingEbook = false; return
                                    }
                                    book.ebookFile?.name = ebookRenameText
                                    libraryVM.updateBook(book)
                                    isRenamingEbook = false
                                })
                                .textFieldStyle(.roundedBorder)
                            } else {
                                Text(ebook.name)
                                    .fontWeight(.medium)
                            }
                            Text(ebook.format.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if isEditing {
                            Button {
                                ebookRenameText = ebook.name
                                isRenamingEbook = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }

                    // Ebook notes
                    if isEditing {
                        TextField("Ebook notes…", text: Binding(
                            get: { book.ebookFile?.notes ?? "" },
                            set: { book.ebookFile?.notes = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    } else if let notes = ebook.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Ebook cover change
                    if isEditing {
                        Button {
                            showDocumentPicker = false
                            showImagePicker = true
                        } label: {
                            Label("Change Ebook Cover", systemImage: "photo")
                                .font(.caption)
                        }
                    }

                    if isEditing {
                        Button(role: .destructive) {
                            PersistenceService.shared.deleteEbookFile(named: ebook.fileName)
                            book.ebookFile = nil
                            libraryVM.updateBook(book)
                        } label: {
                            Label("Remove Ebook", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No ebook file attached")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    if isEditing {
                        Button {
                            showDocumentPicker = true
                        } label: {
                            Label("Attach Ebook File", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helpers

    private func saveEdits() {
        libraryVM.updateBook(book)
        isEditing = false
    }
}

// MARK: - Simple Flow Layout

struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
