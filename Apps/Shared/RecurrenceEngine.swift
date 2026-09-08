import Foundation
import SwiftData
import NorteKit

enum RecurrenceEngine {
    /// Ao concluir uma tarefa recorrente com prazo, cria a próxima ocorrência
    /// (nova tarefa, prazo avançado, status resetado para "A Fazer"). A
    /// original permanece em Feito como histórico e tem sua recorrência
    /// limpa, evitando gerar duplicatas em reconciliações futuras.
    @discardableResult
    static func spawnNextIfNeeded(completed task: NorteTask, in context: ModelContext) -> NorteTask? {
        guard task.status == .done,
              task.recurrence != .none,
              let deadline = task.deadline,
              let next = task.recurrence.nextDate(after: deadline) else { return nil }

        let copy = NorteTask(
            title: task.title,
            context: task.context,
            urgency: task.urgency,
            status: .todo,
            deadline: next,
            deadlineIsAllDay: task.deadlineIsAllDay,
            recurrence: task.recurrence,
            notes: task.notes
        )
        context.insert(copy)
        task.recurrence = .none
        return copy
    }
}
