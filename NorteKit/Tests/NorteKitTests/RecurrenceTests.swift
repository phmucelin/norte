import Testing
import Foundation
@testable import NorteKit

@Suite("Recorrência")
struct RecurrenceTests {
    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return cal
    }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    @Test func noneHasNoNextDate() {
        #expect(Recurrence.none.nextDate(after: date(2026, 9, 7), calendar: calendar) == nil)
    }

    @Test func dailyAddsOneDay() {
        #expect(Recurrence.daily.nextDate(after: date(2026, 9, 7), calendar: calendar)
                == date(2026, 9, 8))
    }

    @Test func weeklyAddsSevenDays() {
        #expect(Recurrence.weekly.nextDate(after: date(2026, 9, 7), calendar: calendar)
                == date(2026, 9, 14))
    }

    @Test func biweeklyAddsFourteenDays() {
        #expect(Recurrence.biweekly.nextDate(after: date(2026, 9, 7), calendar: calendar)
                == date(2026, 9, 21))
    }

    @Test func monthlyAddsOneMonth() {
        #expect(Recurrence.monthly.nextDate(after: date(2026, 9, 7), calendar: calendar)
                == date(2026, 10, 7))
    }

    @Test func monthlyHandlesEndOfMonth() {
        // 31 de janeiro + 1 mês → fevereiro (Calendar fixa para o último dia válido).
        let jan31 = date(2026, 1, 31)
        let next = Recurrence.monthly.nextDate(after: jan31, calendar: calendar)
        let components = calendar.dateComponents([.month], from: next!)
        #expect(components.month == 2)
    }

    @Test func displayNames() {
        #expect(Recurrence.none.displayName == "Não repete")
        #expect(Recurrence.daily.displayName == "Todo dia")
        #expect(Recurrence.weekly.displayName == "Toda semana")
        #expect(Recurrence.biweekly.displayName == "A cada 2 semanas")
        #expect(Recurrence.monthly.displayName == "Todo mês")
    }
}
