import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

// MARK: - EbookFilesView

/// A standalone view listing all ebook files attached to books in the library,
/// with options to import a new standalone ebook (which creates a new book entry),
/// or to customise (rename / change cover / add notes) existing ones.
struct EbookFilesView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel

    @State private var showDocumentPicker = false
    @State private var editingBook: Book? = nil
    @State private var errorMessage: String? = nil

    private var ebookBooks: [Book] {
        libraryVM.books.filter { $0.ebookFile != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if ebookBooks.isEmpty {
                    ContentUnavailableView(
                        "No Ebook Files",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Import an ebook file to attach it to a book in your library.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(ebookBooks) { book in
                        Button {
                            editingBook = book
                        } label: {
                            EbookRowView(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        detachEbooks(at: offsets)
                    }
                }
            }
            .navigationTitle("Ebook Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(supportedTypes: EbookFormat.supportedUTTypes) { url in
                    importNewEbook(from: url)
                }
            }
            .sheet(item: $editingBook) { book in
                EbookCustomiseSheet(book: book)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    // MARK: - Actions

    /// Import a file and create a new (partially empty) book entry in the library.
    private func importNewEbook(from url: URL) {
        do {
            var book = Book(
                title: url.deletingPathExtension().lastPathComponent,
                author: "Unknown Author"
            )
            try libraryVM.importEbookFile(from: url, into: &book)
            libraryVM.addBook(book)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func detachEbooks(at offsets: IndexSet) {
        offsets.forEach { idx in
            var book = ebookBooks[idx]
            if let ebook = book.ebookFile {
                PersistenceService.shared.deleteEbookFile(named: ebook.fileName)
                book.ebookFile = nil
                libraryVM.updateBook(book)
            }
        }
    }
}

// MARK: - EbookRowView

struct EbookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            BookCoverImage(book: book)
                .frame(width: 44, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(radius: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.ebookFile?.name ?? book.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("Book: \(book.title)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let format = book.ebookFile?.format {
                    Text(format.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - EbookCustomiseSheet

struct EbookCustomiseSheet: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var book: Book

    @State private var bookTitle: String = ""
    @State private var ebookName: String = ""
    @State private var ebookNotes: String = ""
    @State private var showImagePicker = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Ebook Display Name") {
                    TextField("Name", text: $ebookName)
                }

                Section("Associated Book Title") {
                    TextField("Book Title", text: $bookTitle)
                }

                Section("Cover Image") {
                    HStack {
                        BookCoverImage(book: book)
                            .frame(width: 60, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                        Button("Change Cover") { showImagePicker = true }
                            .buttonStyle(.bordered)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $ebookNotes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Customise Ebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    var updatedBook = book
                    do {
                        try libraryVM.saveLocalCover(img, for: &updatedBook)
                        libraryVM.updateBook(updatedBook)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .onAppear {
            bookTitle = book.title
            ebookName = book.ebookFile?.name ?? book.title
            ebookNotes = book.ebookFile?.notes ?? ""
        }
    }

    private func save() {
        var updatedBook = book
        updatedBook.title = bookTitle.trimmingCharacters(in: .whitespaces).isEmpty ? book.title : bookTitle.trimmingCharacters(in: .whitespaces)
        updatedBook.ebookFile?.name = ebookName.trimmingCharacters(in: .whitespaces).isEmpty ? (book.ebookFile?.name ?? book.title) : ebookName.trimmingCharacters(in: .whitespaces)
        updatedBook.ebookFile?.notes = ebookNotes.isEmpty ? nil : ebookNotes
        libraryVM.updateBook(updatedBook)
        dismiss()
    }
}
