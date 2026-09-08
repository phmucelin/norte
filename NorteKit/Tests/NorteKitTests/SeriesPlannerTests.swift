import Testing
import Foundation
@testable import NorteKit

@Suite("Séries recorrentes")
struct SeriesPlannerTests {
    private let cal = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    @Test func dailyFillsEachDayUpToHorizon() {
        let head = day(2026, 9, 7)
        let horizon = day(2026, 9, 12)
        let dates = SeriesPlanner.missingOccurrences(
            after: head, existingDays: [cal.startOfDay(for: head)],
            recurrence: .daily, horizon: horizon, calendar: cal)
        // 8,9,10,11,12 → 5 novas ocorrências (o head/7 já existe)
        #expect(dates.count == 5)
        #expect(dates.first == day(2026, 9, 8))
        #expect(dates.last == day(2026, 9, 12))
    }

    @Test func skipsDaysAlreadyPresent() {
        let head = day(2026, 9, 7)
        let horizon = day(2026, 9, 10)
        let existing: Set<Date> = [
            cal.startOfDay(for: day(2026, 9, 7)),
            cal.startOfDay(for: day(2026, 9, 9)), // já existe
        ]
        let dates = SeriesPlanner.missingOccurrences(
            after: head, existingDays: existing,
            recurrence: .daily, horizon: horizon, calendar: cal)
        let days = dates.map { cal.startOfDay(for: $0) }
        #expect(days.contains(cal.startOfDay(for: day(2026, 9, 8))))
        #expect(days.contains(cal.startOfDay(for: day(2026, 9, 10))))
        #expect(!days.contains(cal.startOfDay(for: day(2026, 9, 9)))) // pulado
        #expect(dates.count == 2)
    }

    @Test func weeklyAndNoneBehaveCorrectly() {
        let head = day(2026, 9, 7)
        let horizon = day(2026, 9, 30)
        let weekly = SeriesPlanner.missingOccurrences(
            after: head, existingDays: [cal.startOfDay(for: head)],
            recurrence: .weekly, horizon: horizon, calendar: cal)
        #expect(weekly == [day(2026, 9, 14), day(2026, 9, 21), day(2026, 9, 28)])

        let none = SeriesPlanner.missingOccurrences(
            after: head, existingDays: [], recurrence: .none, horizon: horizon, calendar: cal)
        #expect(none.isEmpty)
    }
}
