import Foundation

public enum PhotoPreviewDismissal {
    public static func isDownwardDominant(
        translationX: Double,
        translationY: Double
    ) -> Bool {
        translationX.isFinite
            && translationY.isFinite
            && translationY > 0
            && translationY > abs(translationX)
    }

    public static func shouldDismiss(
        translationX: Double,
        translationY: Double,
        threshold: Double = 120
    ) -> Bool {
        guard threshold.isFinite,
              threshold > 0 else {
            return false
        }

        return translationY >= threshold
            && isDownwardDominant(translationX: translationX, translationY: translationY)
    }
}
