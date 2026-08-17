import SwiftUI
import UIKit

enum JPEGPhoto {
    static let compressionQuality: CGFloat = 0.82

    static func data(from image: UIImage) -> Data? {
        image.jpegData(compressionQuality: compressionQuality)
    }

    static func data(from raw: Data) -> Data {
        if let image = UIImage(data: raw), let jpeg = data(from: image) {
            return jpeg
        }
        return raw
    }
}

enum DeviceCamera {
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onCapture: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = (info[.originalImage] as? UIImage) ?? (info[.editedImage] as? UIImage),
               let data = JPEGPhoto.data(from: image) {
                parent.onCapture(data)
            }
            parent.isPresented = false
        }
    }
}

struct TakePhotoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Take photo", systemImage: "camera.fill")
        }
        .accessibilityHint("Opens the camera")
    }
}
