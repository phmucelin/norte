import Foundation
import SwiftData
import NorteKit

enum RecurrenceEngine {
    /// Horizonte (em dias) até onde as ocorrências recorrentes são pré-criadas.
    /// Cobre a semana atual e a próxima com folga.
    static let defaultHorizonDays = 14

    /// Ao concluir uma tarefa recorrente com prazo, cria a próxima ocorrência.
    /// Mantido para compatibilidade/uso pontual; o app usa `fillSeries` para
    /// materializar a série inteira. Não cria se a tarefa já faz parte de uma
    /// série (evita duplicar com o `fillSeries`).
    @discardableResult
    static func spawnNextIfNeeded(completed task: NorteTask, in context: ModelContext) -> NorteTask? {
        guard task.seriesID == nil,
              task.status == .done,
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

    /// Materializa as ocorrências de toda tarefa recorrente com prazo até o
    /// horizonte, uma por período (dia/semana/quinzena/mês). Idempotente: só
    /// cria as datas que ainda faltam. Retorna quantas ocorrências criou.
    @discardableResult
    static func fillSeries(in context: ModelContext,
                           horizonDays: Int = defaultHorizonDays,
                           now: Date = .now,
                           calendar: Calendar = .current) -> Int {
        let horizon = calendar.date(byAdding: .day, value: horizonDays,
                                    to: calendar.startOfDay(for: now)) ?? now
        guard let all = try? context.fetch(FetchDescriptor<NorteTask>()) else { return 0 }

        // Cabeças de série ganham um seriesID (as recorrentes com prazo).
        for task in all where task.recurrence != .none && task.deadline != nil {
            if task.seriesID == nil { task.seriesID = task.id }
        }

        var created = 0
        let bySeries = Dictionary(grouping: all.filter { $0.seriesID != nil }, by: { $0.seriesID! })
        for (seriesID, members) in bySeries {
            // Referência: a ocorrência mais à frente que ainda repete.
            guard let head = members
                    .filter({ $0.recurrence != .none && $0.deadline != nil })
                    .max(by: { ($0.deadline ?? .distantPast) < ($1.deadline ?? .distantPast) }),
                  let cursor = head.deadline else { continue }

            let existingDays = Set(members.compactMap { $0.deadline.map { calendar.startOfDay(for: $0) } })
            let dates = SeriesPlanner.missingOccurrences(
                after: cursor, existingDays: existingDays,
                recurrence: head.recurrence, horizon: horizon, calendar: calendar)

            for next in dates {
                let copy = NorteTask(
                    title: head.title, context: head.context, urgency: head.urgency,
                    status: .todo, deadline: next, deadlineIsAllDay: head.deadlineIsAllDay,
                    recurrence: head.recurrence, notes: head.notes, seriesID: seriesID
                )
                context.insert(copy)
                created += 1
            }
        }

        if created > 0 { try? context.save() }
        return created
    }
}
