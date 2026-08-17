import UIKit
import XCTest
@testable import AdventureBuddy

final class JPEGPhotoTests: XCTestCase {
    func testCompressionQualityIsPointEightyTwo() {
        XCTAssertEqual(JPEGPhoto.compressionQuality, 0.82, accuracy: 0.0001)
    }

    func testMaxLongestSideIs1600() {
        XCTAssertEqual(JPEGPhoto.maxLongestSide, 1600, accuracy: 0.1)
    }

    func testEncodesUIImageAsJPEG() {
        let image = solidImage(width: 12, height: 12)
        let data = JPEGPhoto.data(from: image)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
        XCTAssertNotNil(data.flatMap(UIImage.init(data:)))
    }

    func testDownscalesLongestSideAndLeavesSmallImages() {
        let small = JPEGPhoto.downscaled(solidImage(width: 800, height: 600))
        XCTAssertEqual(small.size.width * small.scale, 800, accuracy: 1)
        XCTAssertEqual(small.size.height * small.scale, 600, accuracy: 1)

        let large = JPEGPhoto.downscaled(solidImage(width: 2400, height: 1200))
        let longest = max(large.size.width * large.scale, large.size.height * large.scale)
        XCTAssertEqual(longest, JPEGPhoto.maxLongestSide, accuracy: 1)
        XCTAssertEqual(large.size.width * large.scale, 1600, accuracy: 1)
        XCTAssertEqual(large.size.height * large.scale, 800, accuracy: 1)
    }

    func testReencodesRawBytesAndPassesThroughInvalidData() {
        let raw = JPEGPhoto.data(from: solidImage(width: 12, height: 12)) ?? Data()
        let again = JPEGPhoto.data(from: raw)
        XCTAssertNotNil(UIImage(data: again))

        let garbage = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertEqual(JPEGPhoto.data(from: garbage), garbage)
    }

    private func solidImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
