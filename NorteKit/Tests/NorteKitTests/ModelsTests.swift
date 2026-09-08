import Testing
import Foundation
@testable import NorteKit

@Suite("Modelos")
struct ModelsTests {
    @Test func contextDisplayNames() {
        #expect(TaskContext.iaSolutions.displayName == "IA Solutions")
        #expect(TaskContext.chaiSchool.displayName == "Chai School")
        #expect(TaskContext.nathPereira.displayName == "Nath Pereira")
        #expect(TaskContext.faculdade.displayName == "Faculdade")
        #expect(TaskContext.pessoal.displayName == "Pessoal")
    }

    @Test func contextColorsAreValidHex() {
        for context in TaskContext.allCases {
            #expect(context.colorHex.count == 6)
            #expect(UInt32(context.colorHex, radix: 16) != nil)
        }
    }

    @Test func statusColumnsInOrder() {
        #expect(TaskStatus.allCases == [.backlog, .todo, .doing, .done])
        #expect(TaskStatus.allCases.map(\.displayName) == ["Backlog", "A Fazer", "Fazendo", "Feito"])
    }

    @Test func urgencyEmoji() {
        #expect(Urgency.alta.emoji == "🔴")
        #expect(Urgency.media.emoji == "🟡")
        #expect(Urgency.baixa.emoji == "🟢")
    }

    @Test func urgencyFromEmojiPrefix() {
        #expect(Urgency.from(emojiPrefixOf: "🔴 Deploy urgente") == .alta)
        #expect(Urgency.from(emojiPrefixOf: "🟡 Revisar PR") == .media)
        #expect(Urgency.from(emojiPrefixOf: "  🟢 Ler docs") == .baixa)
        #expect(Urgency.from(emojiPrefixOf: "Sem emoji") == nil)
    }

    @Test func norteTaskDefaults() {
        let task = NorteTask(title: "Testar", context: .nathPereira, urgency: .alta)
        #expect(task.status == .backlog)
        #expect(task.deadline == nil)
        #expect(task.mirrorEventID == nil)
        #expect(task.completedAt == nil)
        task.status = .done
        #expect(task.statusRaw == TaskStatus.done.rawValue)
    }
}
