import SwiftUI

struct TagsView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel

    @State private var showAddSheet = false
    @State private var editingTag: Tag? = nil

    var body: some View {
        NavigationStack {
            List {
                if libraryVM.tags.isEmpty {
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag.slash",
                        description: Text("Create tags to label and quickly filter your books.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(libraryVM.tags) { tag in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 14, height: 14)

                            TagBadge(tag: tag)

                            Spacer()

                            Text(bookCountText(for: tag))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button {
                                editingTag = tag
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteTags)
                }
            }
            .navigationTitle("Tags")
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
                TagEditSheet(tag: nil)
            }
            .sheet(item: $editingTag) { tag in
                TagEditSheet(tag: tag)
            }
        }
    }

    private func bookCountText(for tag: Tag) -> String {
        let count = libraryVM.books.filter { $0.tagIds.contains(tag.id) }.count
        return "\(count) book\(count == 1 ? "" : "s")"
    }

    private func deleteTags(at offsets: IndexSet) {
        offsets.forEach { idx in
            libraryVM.deleteTag(libraryVM.tags[idx])
        }
    }
}

// MARK: - TagEditSheet

struct TagEditSheet: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var tag: Tag?

    @State private var name: String = ""
    @State private var selectedColorHex: String = Tag.paletteColors[0]

    var isNew: Bool { tag == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Tag name", text: $name)
                }
                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 44)), count: 5), spacing: 12) {
                        ForEach(Tag.paletteColors, id: \.self) { hex in
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hex) ?? .blue)
                                    .frame(width: 36, height: 36)
                                if selectedColorHex == hex {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                }
                            }
                            .onTapGesture { selectedColorHex = hex }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isNew ? "New Tag" : "Edit Tag")
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
            if let t = tag {
                name = t.name
                selectedColorHex = t.colorHex
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if isNew {
            libraryVM.addTag(Tag(name: trimmedName, colorHex: selectedColorHex))
        } else if var t = tag {
            t.name = trimmedName
            t.colorHex = selectedColorHex
            libraryVM.updateTag(t)
        }
        dismiss()
    }
}
