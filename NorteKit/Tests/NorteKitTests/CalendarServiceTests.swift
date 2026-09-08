import Testing
import Foundation
@testable import NorteKit

@Suite("CalendarService helpers")
struct CalendarServiceTests {
    @Test func notesRoundTrip() {
        let id = UUID()
        let notes = EventKitCalendarService.notes(forTaskID: id)
        #expect(EventKitCalendarService.parseTaskID(fromNotes: notes) == id)
    }

    @Test func parseIgnoresUnrelatedNotes() {
        #expect(EventKitCalendarService.parseTaskID(fromNotes: "anotação qualquer") == nil)
        #expect(EventKitCalendarService.parseTaskID(fromNotes: nil) == nil)
        #expect(EventKitCalendarService.parseTaskID(fromNotes: "norte-task-id: não-é-uuid") == nil)
    }

    @Test func parseFindsIDAmongOtherLines() {
        let id = UUID()
        let notes = "lembrete pessoal\n\(EventKitCalendarService.notes(forTaskID: id))\noutra linha"
        #expect(EventKitCalendarService.parseTaskID(fromNotes: notes) == id)
    }

    @Test func hexColorRoundTrip() {
        let color = EventKitCalendarService.cgColor(hex: "7C5CFF")
        #expect(EventKitCalendarService.hexString(from: color) == "7C5CFF")
    }
}
