import Foundation

public enum PhotoPreviewDismissal {
    public static func shouldDismiss(
        translationX: Double,
        translationY: Double,
        threshold: Double = 120
    ) -> Bool {
        guard translationX.isFinite,
              translationY.isFinite,
              threshold.isFinite,
              threshold > 0 else {
            return false
        }

        return translationY >= threshold && translationY > abs(translationX)
    }
}
