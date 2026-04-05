import SwiftUI

// MARK: - AddBookView

/// Shown after scanning a barcode OR for manual entry.
/// Pre-populated with API data if available.
struct AddBookView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    // Optional pre-populated data
    var prefill: Book?

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var isbn: String = ""
    @State private var publisher: String = ""
    @State private var publishedDate: String = ""
    @State private var pageCount: String = ""
    @State private var description: String = ""
    @State private var coverURL: String = ""
    @State private var selectedCollectionId: UUID? = nil
    @State private var selectedTagIds: Set<UUID> = []
    @State private var notes: String = ""

    @State private var isSearching = false
    @State private var searchResults: [Book] = []
    @State private var searchQuery: String = ""
    @State private var lookupError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                // ISBN lookup
                Section("ISBN Lookup") {
                    HStack {
                        TextField("Enter ISBN or search term", text: $searchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button {
                            performSearch()
                        } label: {
                            if isSearching {
                                ProgressView()
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .disabled(isSearching || searchQuery.isEmpty)
                    }

                    if !searchResults.isEmpty {
                        ForEach(searchResults) { result in
                            Button {
                                populate(from: result)
                                searchResults = []
                                searchQuery = ""
                            } label: {
                                HStack(spacing: 10) {
                                    BookCoverImage(book: result)
                                        .frame(width: 36, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    VStack(alignment: .leading) {
                                        Text(result.title).font(.callout).foregroundColor(.primary)
                                        Text(result.author).font(.caption).foregroundColor(.secondary)
                                        if let yr = result.publishedDate {
                                            Text(yr).font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if let err = lookupError {
                        Text(err).foregroundColor(.red).font(.caption)
                    }
                }

                Section("Book Details") {
                    TextField("Title *", text: $title)
                    TextField("Author *", text: $author)
                    TextField("ISBN", text: $isbn).keyboardType(.numberPad)
                    TextField("Publisher", text: $publisher)
                    TextField("Published Date", text: $publishedDate)
                    TextField("Page Count", text: $pageCount).keyboardType(.numberPad)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }

                Section("Collection") {
                    Picker("Collection", selection: $selectedCollectionId) {
                        Text("None").tag(Optional<UUID>(nil))
                        ForEach(libraryVM.collections) { coll in
                            Text(coll.name).tag(Optional(coll.id))
                        }
                    }
                }

                Section("Tags") {
                    if libraryVM.tags.isEmpty {
                        Text("No tags yet — create them in the Tags tab.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(libraryVM.tags) { tag in
                            HStack {
                                TagBadge(tag: tag)
                                Spacer()
                                if selectedTagIds.contains(tag.id) {
                                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedTagIds.contains(tag.id) {
                                    selectedTagIds.remove(tag.id)
                                } else {
                                    selectedTagIds.insert(tag.id)
                                }
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addBook() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  author.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if let pf = prefill { populate(from: pf) }
        }
    }

    // MARK: - Actions

    private func performSearch() {
        isSearching = true
        lookupError = nil
        Task {
            do {
                // Looks like ISBN if all digits (and maybe dashes)
                let stripped = searchQuery.replacingOccurrences(of: "-", with: "")
                let isISBN = stripped.allSatisfy { $0.isNumber } && (stripped.count == 10 || stripped.count == 13)
                if isISBN {
                    if let book = try await BookLookupService.shared.lookup(isbn: stripped) {
                        await MainActor.run {
                            searchResults = [book]
                            isSearching = false
                        }
                    } else {
                        // Fall back to text search
                        let results = try await BookLookupService.shared.search(query: searchQuery)
                        await MainActor.run {
                            searchResults = results
                            isSearching = false
                        }
                    }
                } else {
                    let results = try await BookLookupService.shared.search(query: searchQuery)
                    await MainActor.run {
                        searchResults = results
                        isSearching = false
                    }
                }
            } catch {
                await MainActor.run {
                    lookupError = "Lookup failed: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    private func populate(from book: Book) {
        title = book.title
        author = book.author
        isbn = book.isbn ?? ""
        publisher = book.publisher ?? ""
        publishedDate = book.publishedDate ?? ""
        pageCount = book.pageCount.map { String($0) } ?? ""
        description = book.description ?? ""
        coverURL = book.coverImageURL ?? ""
    }

    private func addBook() {
        var book = Book(
            title: title.trimmingCharacters(in: .whitespaces),
            author: author.trimmingCharacters(in: .whitespaces),
            isbn: isbn.isEmpty ? nil : isbn,
            coverImageURL: coverURL.isEmpty ? nil : coverURL,
            description: description.isEmpty ? nil : description,
            publisher: publisher.isEmpty ? nil : publisher,
            publishedDate: publishedDate.isEmpty ? nil : publishedDate,
            pageCount: Int(pageCount)
        )
        book.collectionId = selectedCollectionId
        book.tagIds = Array(selectedTagIds)
        book.notes = notes.isEmpty ? nil : notes
        libraryVM.addBook(book)
        dismiss()
    }
}
