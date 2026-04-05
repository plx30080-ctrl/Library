import SwiftUI

// Main tab-based navigation
struct ContentView: View {
    @StateObject private var libraryVM = LibraryViewModel()

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }

            CollectionsView()
                .tabItem {
                    Label("Collections", systemImage: "folder.fill")
                }

            TagsView()
                .tabItem {
                    Label("Tags", systemImage: "tag.fill")
                }

            EbookFilesView()
                .tabItem {
                    Label("Ebooks", systemImage: "doc.text.fill")
                }
        }
        .environmentObject(libraryVM)
    }
}

#Preview {
    ContentView()
}
