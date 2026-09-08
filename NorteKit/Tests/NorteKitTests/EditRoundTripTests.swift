import Testing
import Foundation
import SwiftData
@testable import NorteKit

/// Reproduz o caminho do TaskEditorSheet.save(): editar uma tarefa já existente
/// via os setters de enum e persistir. Isola se "não salva" vem da persistência.
@Suite("Edição de tarefa persiste")
struct EditRoundTripTests {
    @MainActor
    @Test func editingExistingTaskPersistsAllFields() throws {
        let container = try ModelContainer(
            for: NorteTask.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext

        let task = NorteTask(title: "Original", context: .pessoal, urgency: .baixa, status: .backlog)
        ctx.insert(task)
        try ctx.save()

        // Mesmo caminho do editor: mutar via propriedades computadas + save.
        task.title = "Editada"
        task.context = .chaiSchool
        task.urgency = .alta
        task.status = .doing
        task.deadline = Date(timeIntervalSince1970: 1_000_000)
        task.deadlineIsAllDay = false
        task.recurrence = .weekly
        task.notes = "nota nova"
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<NorteTask>())
        #expect(fetched.count == 1)
        let t = try #require(fetched.first)
        #expect(t.title == "Editada")
        #expect(t.context == .chaiSchool)
        #expect(t.urgency == .alta)
        #expect(t.status == .doing)
        #expect(t.deadlineIsAllDay == false)
        #expect(t.recurrence == .weekly)
        #expect(t.notes == "nota nova")
    }
}
