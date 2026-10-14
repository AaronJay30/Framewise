#if canImport(UIKit) && canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
import FrameWiseCore
import UIKit

enum CameraPhotoProcessor {
    private static let context = CIContext()

    static func process(data: Data, settings: CameraSettings) -> Data {
        // [AC-CAMSET1014-E3]
        guard let image = UIImage(data: data),
              let normalizedImage = normalizedImage(image),
              let input = CIImage(image: normalizedImage) else {
            return CameraPhotoProcessingPolicy.output(
                original: data,
                processed: nil
            )
        }

        let extent = input.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            return CameraPhotoProcessingPolicy.output(
                original: data,
                processed: nil
            )
        }

        let normalizedCrop = settings.aspectRatio.cropRect(
            forWidth: extent.width,
            height: extent.height
        )
        let cropRect = CGRect(
            x: extent.minX + normalizedCrop.x * extent.width,
            y: extent.minY + (1 - normalizedCrop.y - normalizedCrop.height) * extent.height,
            width: normalizedCrop.width * extent.width,
            height: normalizedCrop.height * extent.height
        )
        let boundedCrop = cropRect.integral.intersection(extent)
        guard !boundedCrop.isNull, boundedCrop.width > 0, boundedCrop.height > 0 else {
            return CameraPhotoProcessingPolicy.output(
                original: data,
                processed: nil
            )
        }

        let adjustments = settings.photographicStyle.adjustments
        let cropped = input.cropped(to: boundedCrop)

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = cropped
        colorControls.saturation = Float(adjustments.saturation)
        colorControls.contrast = Float(adjustments.contrast)
        colorControls.brightness = Float(adjustments.brightness)

        guard let colorOutput = colorControls.outputImage else {
            return CameraPhotoProcessingPolicy.output(
                original: data,
                processed: nil
            )
        }

        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = colorOutput
        colorMatrix.rVector = CIVector(
            x: CGFloat(adjustments.redMultiplier),
            y: 0,
            z: 0,
            w: 0
        )
        colorMatrix.gVector = CIVector(
            x: 0,
            y: CGFloat(adjustments.greenMultiplier),
            z: 0,
            w: 0
        )
        colorMatrix.bVector = CIVector(
            x: 0,
            y: 0,
            z: CGFloat(adjustments.blueMultiplier),
            w: 0
        )
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        colorMatrix.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)

        guard let output = colorMatrix.outputImage,
              let rendered = context.createCGImage(
                output,
                from: output.extent.integral
              ) else {
            return CameraPhotoProcessingPolicy.output(
                original: data,
                processed: nil
            )
        }

        let processed = UIImage(cgImage: rendered).jpegData(compressionQuality: 0.92)
        return CameraPhotoProcessingPolicy.output(
            original: data,
            processed: processed
        )
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage? {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: image.size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
#else
import Foundation
import FrameWiseCore

enum CameraPhotoProcessor {
    static func process(data: Data, settings: CameraSettings) -> Data {
        data
    }
}
#endif
