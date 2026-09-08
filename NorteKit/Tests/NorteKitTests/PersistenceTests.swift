import Testing
import Foundation
import SwiftData
@testable import NorteKit

@Suite("Persistência SwiftData")
struct PersistenceTests {
    @MainActor
    @Test func insertAndFetchRoundTrip() throws {
        let container = try ModelContainer(
            for: NorteTask.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        ctx.insert(NorteTask(title: "Deploy", context: .pessoal, urgency: .media, status: .todo))
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<NorteTask>())
        #expect(fetched.count == 1)
        // recurrenceRaw nil por padrão → recurrence == Recurrence.none (segurança de migração).
        #expect(fetched.first?.recurrence == Recurrence.none)
    }

    @MainActor
    @Test func recurrencePersists() throws {
        let container = try ModelContainer(
            for: NorteTask.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        ctx.insert(NorteTask(title: "Boleto", context: .pessoal, urgency: .alta,
                             status: .todo, deadline: .now, recurrence: .weekly))
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<NorteTask>()).first
        #expect(fetched?.recurrence == .weekly)
    }
}
