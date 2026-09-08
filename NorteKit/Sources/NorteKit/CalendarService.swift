import Foundation
import EventKit

public enum NorteCalendarError: LocalizedError {
    case accessDenied
    case noWritableSource
    case mirrorCalendarMissing

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Sem acesso ao calendário. Autorize em Ajustes → Privacidade → Calendários."
        case .noWritableSource:
            return "Nenhuma conta de calendário gravável encontrada. Adicione sua conta Google em Ajustes → Contas de Internet."
        case .mirrorCalendarMissing:
            return "O calendário \"📋 Tarefas\" não existe. Abra o app para recriá-lo."
        }
    }
}

/// Abstração sobre o EventKit para permitir fakes em testes.
public protocol CalendarServicing {
    func requestAccess() async throws -> Bool
    func googleSourceAvailable() -> Bool
    func ensureCalendars() throws
    func events(from: Date, to: Date) throws -> [CalendarEventData]
    /// Cria um evento no calendário de contexto indicado (por título).
    func createEvent(title: String, start: Date, end: Date, isAllDay: Bool,
                     calendarTitle: String, recurrence: Recurrence) throws
    func mirrorItems() throws -> [MirrorItem]
    /// Aplica as ações e devolve, para cada tarefa criada, o ID do evento novo.
    @discardableResult
    func apply(_ actions: [MirrorAction]) throws -> [UUID: String]
}

public final class EventKitCalendarService: CalendarServicing {
    public static let mirrorCalendarTitle = "📋 Tarefas"
    public static let taskIDPrefix = "norte-task-id: "
    public static let statusPrefix = "norte-status: "
    public static let contextPrefix = "norte-context: "

    private let store = EKEventStore()

    public init() {}

    // MARK: - Acesso e contas

    public func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    public var authorizationGranted: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Fonte CalDAV da conta Google; cai para qualquer CalDAV e, por último,
    /// para a fonte do calendário padrão (local — funciona, mas não sincroniza).
    private func writableSource() -> EKSource? {
        let calDAV = store.sources.filter { $0.sourceType == .calDAV }
        let google = calDAV.first {
            let title = $0.title.lowercased()
            return title.contains("google") || title.contains("gmail")
        }
        return google ?? calDAV.first ?? store.defaultCalendarForNewEvents?.source
    }

    public func googleSourceAvailable() -> Bool {
        store.sources.contains { source in
            guard source.sourceType == .calDAV else { return false }
            let title = source.title.lowercased()
            return title.contains("google") || title.contains("gmail")
        }
    }

    // MARK: - Bootstrap de calendários

    public func ensureCalendars() throws {
        guard let source = writableSource() else { throw NorteCalendarError.noWritableSource }
        let existingTitles = Set(store.calendars(for: .event).map(\.title))
        var wanted: [(title: String, hex: String)] = TaskContext.allCases
            .map { ($0.displayName, $0.colorHex) }
        wanted.append((Self.mirrorCalendarTitle, "8E8E93"))

        for entry in wanted where !existingTitles.contains(entry.title) {
            let calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = entry.title
            calendar.source = source
            calendar.cgColor = Self.cgColor(hex: entry.hex)
            try store.saveCalendar(calendar, commit: true)
        }
    }

    // MARK: - Leitura de eventos

    public func events(from: Date, to: Date) throws -> [CalendarEventData] {
        guard authorizationGranted else { throw NorteCalendarError.accessDenied }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        return store.events(matching: predicate).map { event in
            let isMirror = event.calendar?.title == Self.mirrorCalendarTitle
            return CalendarEventData(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "(sem título)",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar?.title ?? "",
                colorHex: Self.colorHex(for: event.calendar),
                isTaskMirror: isMirror,
                taskID: isMirror ? Self.parseTaskID(fromNotes: event.notes) : nil,
                taskStatus: isMirror ? Self.parseStatus(fromNotes: event.notes) : nil,
                taskContext: isMirror ? Self.parseContext(fromNotes: event.notes) : nil,
                recurrence: Self.recurrence(from: event.recurrenceRules)
            )
        }
        .sorted { $0.start < $1.start }
    }

    public func createEvent(title: String, start: Date, end: Date, isAllDay: Bool,
                            calendarTitle: String, recurrence: Recurrence = .none) throws {
        guard authorizationGranted else { throw NorteCalendarError.accessDenied }
        let calendar = store.calendars(for: .event).first { $0.title == calendarTitle }
            ?? store.defaultCalendarForNewEvents
        guard let target = calendar else { throw NorteCalendarError.noWritableSource }
        let event = EKEvent(eventStore: store)
        event.calendar = target
        event.title = title
        event.isAllDay = isAllDay
        if isAllDay {
            let day = Calendar.current.startOfDay(for: start)
            event.startDate = day
            event.endDate = day
        } else {
            event.startDate = start
            event.endDate = max(end, start.addingTimeInterval(900))
        }
        if let rule = Self.recurrenceRule(for: recurrence) { event.recurrenceRules = [rule] }
        try store.save(event, span: .thisEvent, commit: true)
    }

    /// Edita um evento já existente (título, datas, "dia inteiro" e recorrência).
    /// Mantém o evento no mesmo calendário. Silencioso se o id não existir mais.
    public func updateEvent(id: String, title: String, start: Date, end: Date,
                            isAllDay: Bool, recurrence: Recurrence = .none) throws {
        guard authorizationGranted else { throw NorteCalendarError.accessDenied }
        guard let event = store.event(withIdentifier: id) else { return }
        event.title = title
        event.isAllDay = isAllDay
        if isAllDay {
            let day = Calendar.current.startOfDay(for: start)
            event.startDate = day
            event.endDate = day
        } else {
            event.startDate = start
            event.endDate = max(end, start.addingTimeInterval(900))
        }
        // Substitui a regra de recorrência (nil limpa). Editar recorrência exige
        // aplicar à série (futureEvents).
        if let rule = Self.recurrenceRule(for: recurrence) {
            event.recurrenceRules = [rule]
        } else {
            event.recurrenceRules = nil
        }
        try store.save(event, span: .futureEvents, commit: true)
    }

    /// Converte a recorrência do Norte numa regra do EventKit (nil = não repete).
    static func recurrenceRule(for recurrence: Recurrence) -> EKRecurrenceRule? {
        switch recurrence {
        case .none: return nil
        case .daily: return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly: return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .biweekly: return EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        case .monthly: return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        }
    }

    /// Mapeia a regra do EventKit de volta para a recorrência do Norte. Padrões
    /// não suportados (dias específicos etc.) caem em `.none`.
    static func recurrence(from rules: [EKRecurrenceRule]?) -> Recurrence {
        guard let rule = rules?.first else { return .none }
        switch rule.frequency {
        case .daily: return .daily
        case .weekly: return rule.interval == 2 ? .biweekly : .weekly
        case .monthly: return .monthly
        default: return .none
        }
    }

    /// Apaga um evento pelo identificador. Silencioso se já não existir.
    public func deleteEvent(id: String) throws {
        guard authorizationGranted else { throw NorteCalendarError.accessDenied }
        guard let event = store.event(withIdentifier: id) else { return }
        try store.remove(event, span: .thisEvent, commit: true)
    }

    // MARK: - Espelho

    private func mirrorCalendar() -> EKCalendar? {
        store.calendars(for: .event).first { $0.title == Self.mirrorCalendarTitle }
    }

    public func mirrorItems() throws -> [MirrorItem] {
        guard authorizationGranted else { throw NorteCalendarError.accessDenied }
        guard let calendar = mirrorCalendar() else { return [] }
        let start = Date().addingTimeInterval(-365 * 24 * 3600)
        let end = Date().addingTimeInterval(3 * 365 * 24 * 3600)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        return store.events(matching: predicate).compactMap { event in
            guard let taskID = Self.parseTaskID(fromNotes: event.notes) else { return nil }
            return MirrorItem(
                eventID: event.eventIdentifier,
                taskID: taskID,
                title: event.title ?? "",
                deadline: event.startDate,
                isAllDay: event.isAllDay,
                status: Self.parseStatus(fromNotes: event.notes),
                context: Self.parseContext(fromNotes: event.notes)
            )
        }
    }

    @discardableResult
    public func apply(_ actions: [MirrorAction]) throws -> [UUID: String] {
        guard !actions.isEmpty else { return [:] }
        guard let calendar = mirrorCalendar() else { throw NorteCalendarError.mirrorCalendarMissing }
        var created: [UUID: String] = [:]

        for action in actions {
            switch action {
            case let .create(taskID, title, deadline, isAllDay, status, context):
                let event = EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = title
                event.notes = Self.notes(forTaskID: taskID, status: status, context: context)
                Self.configureDates(of: event, deadline: deadline, isAllDay: isAllDay)
                try store.save(event, span: .thisEvent, commit: false)
                if let id = event.eventIdentifier { created[taskID] = id }

            case let .update(eventID, title, deadline, isAllDay, status, context):
                guard let event = store.event(withIdentifier: eventID) else { continue }
                event.title = title
                if let taskID = Self.parseTaskID(fromNotes: event.notes) {
                    event.notes = Self.notes(forTaskID: taskID, status: status, context: context)
                }
                Self.configureDates(of: event, deadline: deadline, isAllDay: isAllDay)
                try store.save(event, span: .thisEvent, commit: false)

            case let .delete(eventID):
                guard let event = store.event(withIdentifier: eventID) else { continue }
                try store.remove(event, span: .thisEvent, commit: false)
            }
        }
        try store.commit()
        return created
    }

    private static func configureDates(of event: EKEvent, deadline: Date, isAllDay: Bool) {
        event.isAllDay = isAllDay
        if isAllDay {
            let day = Calendar.current.startOfDay(for: deadline)
            event.startDate = day
            event.endDate = day
        } else {
            event.startDate = deadline
            event.endDate = deadline.addingTimeInterval(3600)
        }
    }

    // MARK: - Helpers puros (testáveis)

    public static func notes(forTaskID id: UUID, status: TaskStatus? = nil,
                             context: TaskContext? = nil) -> String {
        var lines = [taskIDPrefix + id.uuidString]
        if let status { lines.append(statusPrefix + status.rawValue) }
        if let context { lines.append(contextPrefix + context.rawValue) }
        return lines.joined(separator: "\n")
    }

    public static func parseTaskID(fromNotes notes: String?) -> UUID? {
        guard let value = line(withPrefix: taskIDPrefix, in: notes) else { return nil }
        return UUID(uuidString: value)
    }

    public static func parseStatus(fromNotes notes: String?) -> TaskStatus? {
        guard let value = line(withPrefix: statusPrefix, in: notes) else { return nil }
        return TaskStatus(rawValue: value)
    }

    public static func parseContext(fromNotes notes: String?) -> TaskContext? {
        guard let value = line(withPrefix: contextPrefix, in: notes) else { return nil }
        return TaskContext(rawValue: value)
    }

    private static func line(withPrefix prefix: String, in notes: String?) -> String? {
        guard let notes else { return nil }
        for line in notes.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    static func cgColor(hex: String) -> CGColor {
        let value = UInt32(hex, radix: 16) ?? 0x8E8E93
        let components: [CGFloat] = [
            CGFloat((value >> 16) & 0xFF) / 255,
            CGFloat((value >> 8) & 0xFF) / 255,
            CGFloat(value & 0xFF) / 255,
            1
        ]
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        return CGColor(colorSpace: sRGB, components: components)
            ?? CGColor(gray: 0.5, alpha: 1)
    }

    /// Paleta de reserva quando a cor do calendário não pode ser lida.
    private static let fallbackPalette = [
        "7C5CFF", "00B8D9", "FF6B9D", "FFB020", "36B37E", "FF453A", "0A84FF", "BF5AF2"
    ]

    /// Cor do calendário; se a cor for neutra/acinzentada ou ilegível, deriva
    /// uma cor vibrante estável a partir do título (calendários diferentes →
    /// cores diferentes).
    static func colorHex(for calendar: EKCalendar?) -> String {
        if let (r, g, b) = rgbComponents(of: calendar?.cgColor) {
            let chroma = max(r, g, b) - min(r, g, b)
            // Só aceita se tiver cor de verdade (saturação) e não for muito escura.
            if chroma >= 0.12, max(r, g, b) >= 0.22 {
                return String(format: "%02X%02X%02X",
                              Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
            }
        }
        let title = calendar?.title ?? ""
        let sum = title.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return fallbackPalette[sum % fallbackPalette.count]
    }

    private static func rgbComponents(of color: CGColor?) -> (Double, Double, Double)? {
        guard let rgb = color?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         intent: .defaultIntent, options: nil),
              let c = rgb.components, c.count >= 3 else { return nil }
        return (Double(c[0]), Double(c[1]), Double(c[2]))
    }

    static func hexString(from color: CGColor?) -> String? {
        guard let (r, g, b) = rgbComponents(of: color) else { return nil }
        return String(format: "%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}
