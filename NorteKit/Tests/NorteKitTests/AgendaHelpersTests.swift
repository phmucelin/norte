import Testing
import Foundation
@testable import NorteKit

@Suite("Agenda helpers")
struct AgendaHelpersTests {
    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return cal
    }

    // Segunda-feira, 2026-09-07 10:00 em São Paulo.
    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 10))!
    }

    func date(_ day: Int, _ hour: Int = 12, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test func deadlineToday() {
        let result = DeadlineFormatter.relative(date(7, 18), now: now, calendar: calendar)
        #expect(result == (text: "hoje", isOverdue: false))
    }

    @Test func deadlineTomorrow() {
        let result = DeadlineFormatter.relative(date(8), now: now, calendar: calendar)
        #expect(result == (text: "amanhã", isOverdue: false))
    }

    @Test func deadlineInDays() {
        let result = DeadlineFormatter.relative(date(10), now: now, calendar: calendar)
        #expect(result == (text: "faltam 3d", isOverdue: false))
    }

    @Test func deadlineOverdue() {
        let result = DeadlineFormatter.relative(date(5), now: now, calendar: calendar)
        #expect(result == (text: "atrasada 2d", isOverdue: true))
    }

    func event(id: String, start: Date, end: Date, allDay: Bool = false) -> CalendarEventData {
        CalendarEventData(id: id, title: id, start: start, end: end, isAllDay: allDay,
                          calendarTitle: "Pessoal", colorHex: "36B37E", isTaskMirror: false)
    }

    @Test func groupByDaySplitsByStartOfDay() {
        let monday = event(id: "a", start: date(7, 9), end: date(7, 10))
        let tuesday = event(id: "b", start: date(8, 9), end: date(8, 10))
        let grouped = AgendaGrouper.groupByDay(events: [monday, tuesday], calendar: calendar)
        #expect(grouped[calendar.startOfDay(for: date(7))]?.map(\.id) == ["a"])
        #expect(grouped[calendar.startOfDay(for: date(8))]?.map(\.id) == ["b"])
    }

    @Test func multiDayEventAppearsOnEachDay() {
        let spanning = event(id: "viagem", start: date(7, 22), end: date(9, 8))
        let grouped = AgendaGrouper.groupByDay(events: [spanning], calendar: calendar)
        for day in [7, 8, 9] {
            #expect(grouped[calendar.startOfDay(for: date(day))]?.map(\.id) == ["viagem"])
        }
    }

    @Test func allDayEventDoesNotLeakIntoNextDay() {
        // Evento de dia inteiro no dia 7: end é meia-noite do dia 8 (exclusivo).
        let allDay = event(id: "feriado", start: calendar.startOfDay(for: date(7)),
                           end: calendar.startOfDay(for: date(8)), allDay: true)
        let grouped = AgendaGrouper.groupByDay(events: [allDay], calendar: calendar)
        #expect(grouped[calendar.startOfDay(for: date(7))]?.map(\.id) == ["feriado"])
        #expect(grouped[calendar.startOfDay(for: date(8))] == nil)
    }

    @Test func daysOfWeekContainingReturnsSevenDaysStartingMonday() {
        let week = AgendaGrouper.weekDays(containing: now, calendar: calendar)
        #expect(week.count == 7)
        #expect(week.first == calendar.startOfDay(for: date(7)))
        #expect(week.last == calendar.startOfDay(for: date(13)))
    }
}
