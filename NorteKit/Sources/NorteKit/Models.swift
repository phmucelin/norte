import Foundation
import SwiftData

/// Contexto (empresa/área) de uma tarefa ou calendário.
public enum TaskContext: String, CaseIterable, Codable, Sendable, Identifiable {
    case iaSolutions
    case chaiSchool
    case nathPereira
    case faculdade
    case pessoal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iaSolutions: return "IA Solutions"
        case .chaiSchool: return "Chai School"
        case .nathPereira: return "Nath Pereira"
        case .faculdade: return "Faculdade"
        case .pessoal: return "Pessoal"
        }
    }

    /// Sigla curta para tags/widgets.
    public var shortCode: String {
        switch self {
        case .iaSolutions: return "IA"
        case .chaiSchool: return "CHAI"
        case .nathPereira: return "NATH"
        case .faculdade: return "FAC"
        case .pessoal: return "PES"
        }
    }

    /// Contexto a partir do nome de exibição do calendário (nil se não bater).
    public static func from(displayName: String) -> TaskContext? {
        allCases.first { $0.displayName == displayName }
    }

    /// Cor do contexto (sem "#"), usada nos cards e na criação dos calendários.
    public var colorHex: String {
        switch self {
        case .iaSolutions: return "7C5CFF"
        case .chaiSchool: return "00B8D9"
        case .nathPereira: return "FF6B9D"
        case .faculdade: return "FFB020"
        case .pessoal: return "36B37E"
        }
    }
}

/// Coluna do Kanban.
public enum TaskStatus: String, CaseIterable, Codable, Sendable, Identifiable {
    case backlog
    case todo
    case doing
    case done

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .backlog: return "Backlog"
        case .todo: return "A Fazer"
        case .doing: return "Fazendo"
        case .done: return "Feito"
        }
    }
}

/// Urgência da tarefa; o emoji prefixa o título do evento espelhado.
public enum Urgency: String, CaseIterable, Codable, Sendable, Identifiable {
    case alta
    case media
    case baixa

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .alta: return "🔴"
        case .media: return "🟡"
        case .baixa: return "🟢"
        }
    }

    public var displayName: String {
        switch self {
        case .alta: return "Alta"
        case .media: return "Média"
        case .baixa: return "Baixa"
        }
    }

    /// Recupera a urgência a partir do prefixo de emoji de um título espelhado.
    public static func from(emojiPrefixOf title: String) -> Urgency? {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        return allCases.first { trimmed.hasPrefix($0.emoji) }
    }
}

/// Recorrência de uma tarefa. Ao concluir, gera a próxima ocorrência.
public enum Recurrence: String, CaseIterable, Codable, Sendable, Identifiable {
    case none
    case daily
    case weekly
    case biweekly
    case monthly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "Não repete"
        case .daily: return "Todo dia"
        case .weekly: return "Toda semana"
        case .biweekly: return "A cada 2 semanas"
        case .monthly: return "Todo mês"
        }
    }

    /// Próxima data a partir de `date`; nil quando não há recorrência.
    public func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none: return nil
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly: return calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}

/// Tarefa do Kanban. Persistida via SwiftData apenas no Mac.
@Model
public final class NorteTask {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var contextRaw: String
    public var statusRaw: String
    public var urgencyRaw: String
    public var deadline: Date?
    public var deadlineIsAllDay: Bool
    /// Opcional para migração leve segura de stores criados antes da recorrência
    /// (nil = não repete).
    public var recurrenceRaw: String?
    public var notes: String
    public var createdAt: Date
    public var completedAt: Date?
    /// Identificador do evento espelhado no calendário "📋 Tarefas".
    public var mirrorEventID: String?

    public init(
        title: String,
        context: TaskContext,
        urgency: Urgency,
        status: TaskStatus = .backlog,
        deadline: Date? = nil,
        deadlineIsAllDay: Bool = true,
        recurrence: Recurrence = .none,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.contextRaw = context.rawValue
        self.statusRaw = status.rawValue
        self.urgencyRaw = urgency.rawValue
        self.deadline = deadline
        self.deadlineIsAllDay = deadlineIsAllDay
        self.recurrenceRaw = recurrence.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.completedAt = nil
        self.mirrorEventID = nil
    }

    public var context: TaskContext {
        get { TaskContext(rawValue: contextRaw) ?? .pessoal }
        set { contextRaw = newValue.rawValue }
    }

    public var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .backlog }
        set {
            statusRaw = newValue.rawValue
            completedAt = newValue == .done ? (completedAt ?? .now) : nil
        }
    }

    public var urgency: Urgency {
        get { Urgency(rawValue: urgencyRaw) ?? .media }
        set { urgencyRaw = newValue.rawValue }
    }

    public var recurrence: Recurrence {
        get { recurrenceRaw.flatMap(Recurrence.init(rawValue:)) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }
}
