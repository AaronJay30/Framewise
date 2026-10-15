import Foundation

public enum PhotoPreviewSelection {
    public static func neighbor(
        afterRemoving removedID: UUID,
        from orderedIDs: [UUID]
    ) -> UUID? {
        guard let removedIndex = orderedIDs.firstIndex(of: removedID) else { return nil }

        let nextIndex = removedIndex + 1
        if orderedIDs.indices.contains(nextIndex) {
            return orderedIDs[nextIndex]
        }

        let previousIndex = removedIndex - 1
        return orderedIDs.indices.contains(previousIndex) ? orderedIDs[previousIndex] : nil
    }
}
