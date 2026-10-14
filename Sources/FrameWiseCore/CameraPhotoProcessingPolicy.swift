import Foundation

public enum CameraPhotoProcessingPolicy {
    public static func output(original: Data, processed: Data?) -> Data {
        guard let processed, !processed.isEmpty else {
            return original
        }

        return processed
    }
}
