import XCTest
@testable import FrameWiseCore

final class CapturedPhotoGroupingTests: XCTestCase {
    func testGroupByDayOrdersDaysNewestFirst() {
        let calendar = utcCalendar
        let older = makePhoto(
            id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            date: date(day: 1, hour: 10, calendar: calendar)
        )
        let newer = makePhoto(
            id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            date: date(day: 2, hour: 9, calendar: calendar)
        )

        let groups = CapturedPhotoGrouping.groupByDay(
            [older, newer],
            calendar: calendar
        )

        XCTAssertEqual(groups.map(\.photos), [[newer], [older]])
        XCTAssertEqual(
            groups.map(\.day),
            [
                date(day: 2, hour: 0, calendar: calendar),
                date(day: 1, hour: 0, calendar: calendar),
            ]
        )
    }

    func testGroupByDayOrdersPhotosNewestFirstWithinEachDay() {
        let calendar = utcCalendar
        let older = makePhoto(
            id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            date: date(day: 1, hour: 8, calendar: calendar)
        )
        let newer = makePhoto(
            id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            date: date(day: 1, hour: 18, calendar: calendar)
        )

        let groups = CapturedPhotoGrouping.groupByDay(
            [older, newer],
            calendar: calendar
        )

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].photos, [newer, older])
    }

    func testGroupByDaySeparatesLocalCalendarBoundaries() {
        let calendar = utcCalendar
        let beforeMidnight = makePhoto(
            id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            date: date(day: 1, hour: 23, minute: 59, calendar: calendar)
        )
        let afterMidnight = makePhoto(
            id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            date: date(day: 2, hour: 0, minute: 1, calendar: calendar)
        )

        let groups = CapturedPhotoGrouping.groupByDay(
            [beforeMidnight, afterMidnight],
            calendar: calendar
        )

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].photos, [afterMidnight])
        XCTAssertEqual(groups[1].photos, [beforeMidnight])
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        day: Int,
        hour: Int,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(year: 2024, month: 1, day: day, hour: hour, minute: minute)
        )!
    }

    private func makePhoto(id: String, date: Date) -> CapturedPhoto {
        CapturedPhoto(
            id: UUID(uuidString: id)!,
            data: Data([0x01]),
            capturedAt: date,
            isExported: false
        )!
    }
}
