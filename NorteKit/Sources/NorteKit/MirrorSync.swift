import Foundation

/// Evento já existente no calendário "📋 Tarefas", identificado pelo
/// `norte-task-id` gravado nas notas.
public struct MirrorItem: Equatable, Sendable {
    public var eventID: String
    public var taskID: UUID
    public var title: String
    public var deadline: Date
    public var isAllDay: Bool
    /// Status gravado nas notas do evento (nil em eventos antigos sem o marcador).
    public var status: TaskStatus?
    /// Contexto gravado nas notas (nil em eventos antigos).
    public var context: TaskContext?

    public init(eventID: String, taskID: UUID, title: String, deadline: Date,
                isAllDay: Bool, status: TaskStatus? = nil, context: TaskContext? = nil) {
        self.eventID = eventID
        self.taskID = taskID
        self.title = title
        self.deadline = deadline
        self.isAllDay = isAllDay
        self.status = status
        self.context = context
    }
}

/// Retrato imutável de uma tarefa, desacoplado do SwiftData para permitir
/// testes puros do planner.
public struct TaskSnapshot: Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var urgency: Urgency
    public var status: TaskStatus
    public var context: TaskContext
    public var deadline: Date?
    public var deadlineIsAllDay: Bool

    public init(id: UUID, title: String, urgency: Urgency, status: TaskStatus,
                context: TaskContext, deadline: Date?, deadlineIsAllDay: Bool) {
        self.id = id
        self.title = title
        self.urgency = urgency
        self.status = status
        self.context = context
        self.deadline = deadline
        self.deadlineIsAllDay = deadlineIsAllDay
    }
}

public enum MirrorAction: Equatable, Sendable {
    case create(taskID: UUID, title: String, deadline: Date, isAllDay: Bool,
                status: TaskStatus, context: TaskContext)
    case update(eventID: String, title: String, deadline: Date, isAllDay: Bool,
                status: TaskStatus, context: TaskContext)
    case delete(eventID: String)
}

/// Diff puro entre o estado desejado (tarefas) e o estado real (eventos
/// espelhados). Aplicar as ações e replanejar resulta em lista vazia.
public enum MirrorPlanner {
    public static func mirrorTitle(for task: TaskSnapshot) -> String {
        "\(task.urgency.emoji) \(task.title)"
    }

    public static func plan(tasks: [TaskSnapshot], existing: [MirrorItem]) -> [MirrorAction] {
        var actions: [MirrorAction] = []
        let mirrorsByTask = Dictionary(grouping: existing, by: \.taskID)
        let taskIDs = Set(tasks.map(\.id))

        for task in tasks {
            let mirrors = mirrorsByTask[task.id] ?? []
            guard let deadline = task.deadline, task.status != .done else {
                actions.append(contentsOf: mirrors.map { .delete(eventID: $0.eventID) })
                continue
            }
            let title = mirrorTitle(for: task)
            if let current = mirrors.first {
                if current.title != title
                    || current.deadline != deadline
                    || current.isAllDay != task.deadlineIsAllDay
                    || current.status != task.status
                    || current.context != task.context {
                    actions.append(.update(eventID: current.eventID, title: title,
                                           deadline: deadline, isAllDay: task.deadlineIsAllDay,
                                           status: task.status, context: task.context))
                }
                actions.append(contentsOf: mirrors.dropFirst().map { .delete(eventID: $0.eventID) })
            } else {
                actions.append(.create(taskID: task.id, title: title,
                                       deadline: deadline, isAllDay: task.deadlineIsAllDay,
                                       status: task.status, context: task.context))
            }
        }

        // Eventos órfãos: a tarefa foi apagada do banco.
        actions.append(contentsOf: existing
            .filter { !taskIDs.contains($0.taskID) }
            .map { .delete(eventID: $0.eventID) })

        return actions
    }
}
