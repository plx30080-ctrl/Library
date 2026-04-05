import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel

    @State private var showAddBook = false
    @State private var showScanner = false
    @State private var scannedISBN: String? = nil
    @State private var lookupBook: Book? = nil
    @State private var isLookingUp = false
    @State private var isBookcaseMode = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                // Book list / bookcase
                if isBookcaseMode {
                    BookcaseView(books: libraryVM.filteredBooks)
                } else {
                    List {
                        if libraryVM.filteredBooks.isEmpty {
                            ContentUnavailableView(
                                "No Books",
                                systemImage: "books.vertical",
                                description: Text("Add books using the + button or scan a barcode.")
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(libraryVM.filteredBooks) { book in
                                NavigationLink(destination: BookDetailView(book: book)) {
                                    BookRowView(book: book)
                                }
                            }
                            .onDelete { offsets in
                                libraryVM.deleteBooks(at: offsets, in: libraryVM.filteredBooks)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $libraryVM.searchText, prompt: "Search by title, author, ISBN…")
            .navigationTitle("My Library")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { isBookcaseMode.toggle() }
                    } label: {
                        Image(systemName: isBookcaseMode ? "list.bullet" : "books.vertical.fill")
                    }
                    sortMenu
                    addMenu
                }
            }
            .overlay {
                if isLookingUp {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Looking up book…")
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color(.systemGray3).opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView(prefill: lookupBook)
                    .onDisappear { lookupBook = nil }
            }
            .fullScreenCover(isPresented: $showScanner) {
                BarcodeScannerView(onScanned: { code in
                    showScanner = false
                    lookupScannedISBN(code)
                }, onCancel: {
                    showScanner = false
                })
            }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Collection filter chips
                collectionChip(id: nil, name: "All")
                ForEach(libraryVM.collections) { coll in
                    collectionChip(id: coll.id, name: coll.name)
                }

                Divider()
                    .frame(height: 20)

                // Tag filter chips
                ForEach(libraryVM.tags) { tag in
                    tagChip(tag: tag)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func collectionChip(id: UUID?, name: String) -> some View {
        let isSelected = libraryVM.selectedCollectionId == id
        return Button {
            libraryVM.selectedCollectionId = isSelected ? nil : id
        } label: {
            Text(name)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: isSelected ? 0 : 1))
        }
    }

    private func tagChip(tag: Tag) -> some View {
        let isSelected = libraryVM.selectedTagIds.contains(tag.id)
        return Button {
            if isSelected { libraryVM.selectedTagIds.remove(tag.id) }
            else { libraryVM.selectedTagIds.insert(tag.id) }
        } label: {
            TagBadge(tag: tag)
                .opacity(isSelected ? 1.0 : 0.6)
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
    }

    // MARK: - Toolbars

    private var sortMenu: some View {
        Menu {
            ForEach(BookSortOrder.allCases) { order in
                Button {
                    libraryVM.sortOrder = order
                } label: {
                    HStack {
                        Text(order.rawValue)
                        if libraryVM.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Scan Barcode", systemImage: "barcode.viewfinder") {
                showScanner = true
            }
            Button("Add Manually", systemImage: "plus.circle") {
                lookupBook = nil
                showAddBook = true
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
        }
    }

    // MARK: - ISBN lookup

    private func lookupScannedISBN(_ code: String) {
        isLookingUp = true
        Task {
            do {
                let book = try await BookLookupService.shared.lookup(isbn: code)
                await MainActor.run {
                    isLookingUp = false
                    lookupBook = book ?? Book(title: "", author: "", isbn: code)
                    showAddBook = true
                }
            } catch {
                await MainActor.run {
                    isLookingUp = false
                    lookupBook = Book(title: "", author: "", isbn: code)
                    showAddBook = true
                }
            }
        }
    }
}
