import Foundation

/// A newest-first slice of the captured-photo library for one calendar day.
public struct CapturedPhotoDayGroup: Identifiable, Equatable, Sendable {
    public let day: Date
    public let photos: [CapturedPhoto]

    public var id: Date { day }

    public init(day: Date, photos: [CapturedPhoto]) {
        self.day = day
        self.photos = photos
    }
}

/// Groups captures by the user's calendar day without changing the source library.
public enum CapturedPhotoGrouping {
    public static func groupByDay(
        _ photos: [CapturedPhoto],
        calendar: Calendar = .current
    ) -> [CapturedPhotoDayGroup] {
        let grouped = Dictionary(grouping: photos) { photo in
            calendar.startOfDay(for: photo.capturedAt)
        }

        return grouped.keys.sorted(by: >).map { day in
            let photos = grouped[day, default: []].sorted { left, right in
                if left.capturedAt != right.capturedAt {
                    return left.capturedAt > right.capturedAt
                }

                return left.id.uuidString < right.id.uuidString
            }

            return CapturedPhotoDayGroup(day: day, photos: photos)
        }
    }
}
