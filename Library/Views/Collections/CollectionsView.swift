import SwiftUI

struct CollectionsView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel

    @State private var showAddSheet = false
    @State private var editingCollection: BookCollection? = nil

    var body: some View {
        NavigationStack {
            List {
                if libraryVM.collections.isEmpty {
                    ContentUnavailableView(
                        "No Collections",
                        systemImage: "folder.badge.plus",
                        description: Text("Create collections to organise your books into subgroups.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(libraryVM.collections) { coll in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(coll.name)
                                    .font(.headline)
                                if let desc = coll.collectionDescription, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(bookCountText(for: coll))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                editingCollection = coll
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteCollections)
                }
            }
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                CollectionEditSheet(collection: nil)
            }
            .sheet(item: $editingCollection) { coll in
                CollectionEditSheet(collection: coll)
            }
        }
    }

    private func bookCountText(for collection: BookCollection) -> String {
        let count = libraryVM.books.filter { $0.collectionId == collection.id }.count
        return "\(count) book\(count == 1 ? "" : "s")"
    }

    private func deleteCollections(at offsets: IndexSet) {
        offsets.forEach { idx in
            libraryVM.deleteCollection(libraryVM.collections[idx])
        }
    }
}

// MARK: - CollectionEditSheet

struct CollectionEditSheet: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var collection: BookCollection?

    @State private var name: String = ""
    @State private var description: String = ""

    var isNew: Bool { collection == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Collection name", text: $name)
                }
                Section("Description (optional)") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isNew ? "New Collection" : "Edit Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Create" : "Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if let coll = collection {
                name = coll.name
                description = coll.collectionDescription ?? ""
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if isNew {
            let coll = BookCollection(name: trimmedName, description: description.isEmpty ? nil : description)
            libraryVM.addCollection(coll)
        } else if var coll = collection {
            coll.name = trimmedName
            coll.collectionDescription = description.isEmpty ? nil : description
            libraryVM.updateCollection(coll)
        }
        dismiss()
    }
}
