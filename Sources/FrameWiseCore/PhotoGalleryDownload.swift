import Foundation

public enum PhotoGalleryDownload {
    public static func pendingIDs(
        selectedIDs: Set<UUID>,
        exportedIDs: Set<UUID>
    ) -> Set<UUID> {
        selectedIDs.subtracting(exportedIDs)
    }
}
