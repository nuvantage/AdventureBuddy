import SwiftUI
import UIKit

enum JPEGPhoto {
    static let compressionQuality: CGFloat = 0.82
    /// Longest edge in pixels after downscale. Existing SwiftData photos are left as stored.
    static let maxLongestSide: CGFloat = 1600

    static func data(from image: UIImage) -> Data? {
        downscaled(image).jpegData(compressionQuality: compressionQuality)
    }

    static func data(from raw: Data) -> Data {
        if let image = UIImage(data: raw), let jpeg = data(from: image) {
            return jpeg
        }
        return raw
    }

    static func downscaled(_ image: UIImage) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxLongestSide, longest > 0 else { return image }

        let factor = maxLongestSide / longest
        let newSize = CGSize(
            width: max((pixelWidth * factor).rounded(), 1),
            height: max((pixelHeight * factor).rounded(), 1)
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
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
