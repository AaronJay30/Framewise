import Foundation

public enum PhotoGallerySelection {
    public static func toggled(
        _ photoID: UUID,
        in selectedIDs: Set<UUID>
    ) -> Set<UUID> {
        var next = selectedIDs
        if next.contains(photoID) {
            next.remove(photoID)
        } else {
            next.insert(photoID)
        }
        return next
    }

    public static func reconciled(
        _ selectedIDs: Set<UUID>,
        with visibleIDs: [UUID]
    ) -> Set<UUID> {
        selectedIDs.intersection(visibleIDs)
    }
}
