import Foundation

/// Evento de calendário desacoplado do EventKit, consumível por views e widgets.
public struct CalendarEventData: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var calendarTitle: String
    public var colorHex: String
    /// true quando o evento vem do calendário "📋 Tarefas" (espelho).
    public var isTaskMirror: Bool
    /// UUID da NorteTask de origem, para deep-link (apenas eventos espelho).
    public var taskID: UUID?
    /// Coluna do Kanban da tarefa de origem (apenas eventos espelho).
    public var taskStatus: TaskStatus?
    /// Contexto/empresa da tarefa de origem (apenas eventos espelho).
    public var taskContext: TaskContext?
    /// Recorrência do evento no calendário (mapeada do EKRecurrenceRule).
    public var recurrence: Recurrence

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool,
                calendarTitle: String, colorHex: String, isTaskMirror: Bool,
                taskID: UUID? = nil, taskStatus: TaskStatus? = nil, taskContext: TaskContext? = nil,
                recurrence: Recurrence = .none) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.colorHex = colorHex
        self.isTaskMirror = isTaskMirror
        self.taskID = taskID
        self.taskStatus = taskStatus
        self.taskContext = taskContext
        self.recurrence = recurrence
    }
}

public enum DeadlineFormatter {
    /// Texto relativo em pt-BR para um prazo: "hoje", "amanhã", "faltam Nd",
    /// "atrasada Nd".
    public static func relative(_ deadline: Date, now: Date = .now,
                                calendar: Calendar = .current) -> (text: String, isOverdue: Bool) {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: deadline)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        switch days {
        case ..<0: return ("atrasada \(-days)d", true)
        case 0: return ("hoje", false)
        case 1: return ("amanhã", false)
        default: return ("faltam \(days)d", false)
        }
    }
}

public enum AgendaGrouper {
    /// Agrupa eventos por dia (startOfDay). Eventos que atravessam mais de um
    /// dia aparecem em todos os dias que tocam; o instante final é exclusivo
    /// (um evento de dia inteiro termina à meia-noite seguinte e não vaza).
    public static func groupByDay(events: [CalendarEventData],
                                  calendar: Calendar = .current) -> [Date: [CalendarEventData]] {
        var grouped: [Date: [CalendarEventData]] = [:]
        for event in events {
            var day = calendar.startOfDay(for: event.start)
            let lastInstant = event.end > event.start ? event.end.addingTimeInterval(-1) : event.start
            let lastDay = calendar.startOfDay(for: lastInstant)
            while day <= lastDay {
                grouped[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.start < $1.start }
        }
        return grouped
    }

    /// Os 7 dias (startOfDay) da semana que contém `date`, começando na
    /// segunda-feira.
    public static func weekDays(containing date: Date,
                                calendar: Calendar = .current) -> [Date] {
        var cal = calendar
        cal.firstWeekday = 2 // segunda
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
}
