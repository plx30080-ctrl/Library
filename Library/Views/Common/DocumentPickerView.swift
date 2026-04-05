import SwiftUI
import UniformTypeIdentifiers

// UIKit document picker wrapped for SwiftUI
struct DocumentPickerView: UIViewControllerRepresentable {
    let supportedTypes: [String]
    var onPicked: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let utTypes = supportedTypes.compactMap { UTType($0) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: utTypes.isEmpty ? [.data] : utTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        init(onPicked: @escaping (URL) -> Void) { self.onPicked = onPicked }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPicked(url)
        }
    }
}
