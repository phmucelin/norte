import WidgetKit
import SwiftUI
import NorteKit

// Deep links: clicar no widget abre o app; clicar numa tarefa abre-a no editor.
enum NorteDeepLink {
    static let scheme = "norte"
    static var open: URL { URL(string: "\(scheme)://open")! }
    static func task(_ id: UUID) -> URL { URL(string: "\(scheme)://task/\(id.uuidString)")! }
}

// MARK: - Timeline (compartilhado por iOS e macOS)

struct AgendaEntry: TimelineEntry {
    let date: Date
    let events: [CalendarEventData]
    let hasAccess: Bool

    /// Eventos ainda não terminados no instante da entry.
    var upcoming: [CalendarEventData] {
        events.filter { $0.end > date || $0.isAllDay }
    }
}

struct AgendaProvider: TimelineProvider {
    private func loadEntry(at date: Date) -> AgendaEntry {
        let service = EventKitCalendarService()
        guard service.authorizationGranted else {
            return AgendaEntry(date: date, events: [], hasAccess: false)
        }
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? date
        let events = (try? service.events(from: start, to: end)) ?? []
        return AgendaEntry(date: date, events: events, hasAccess: true)
    }

    func placeholder(in context: Context) -> AgendaEntry {
        AgendaEntry(date: .now, events: [], hasAccess: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> Void) {
        completion(loadEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgendaEntry>) -> Void) {
        // Uma entry a cada 15 min pelas próximas 4 h; depois o sistema recarrega.
        let now = Date()
        let entries = stride(from: 0, through: 16, by: 1).map { step in
            loadEntry(at: now.addingTimeInterval(Double(step) * 15 * 60))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Helpers visuais

func eventColor(_ event: CalendarEventData) -> Color {
    if event.isTaskMirror, let urgency = Urgency.from(emojiPrefixOf: event.title) {
        return urgency.color
    }
    return Color(hex: event.colorHex)
}

func shortTime(_ event: CalendarEventData) -> String {
    if event.isAllDay { return "dia todo" }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: event.start)
}

// MARK: - Widget do dia (systemSmall / medium / large — iOS e macOS)

struct DayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AgendaEntry

    private var maxItems: Int {
        switch family {
        case .systemSmall: return 3
        case .systemLarge: return 9
        default: return 4
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = family == .systemSmall ? "EEE, d/M" : "EEE, d 'de' MMM"
        return formatter.string(from: entry.date).norteSentenceCased
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 6) {
            Text(dateText)
                .font(.system(size: family == .systemSmall ? 12 : 13, weight: .semibold, design: .rounded))

            if entry.upcoming.isEmpty {
                Spacer()
                Text(entry.hasAccess ? "Dia livre 🎉" : "Abra o Norte para autorizar o calendário.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.upcoming.prefix(maxItems)) { event in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(eventColor(event))
                            .frame(width: 3, height: 14)
                        Text(shortTime(event))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                        Text(event.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color(hex: "121216"), for: .widget)
        .widgetURL(NorteDeepLink.open)
    }
}

/// Widget principal (kind "NorteDayWidget"): pequeno mostra o dia; médio e
/// grande mostram a GRADE DA SEMANA. Mantém este kind porque é o que o macOS
/// já reconhece — assim a semana aparece sem depender do catálogo destravar.
struct AdaptiveDayWeekView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RangeEntry

    var body: some View {
        if family == .systemSmall {
            DaySmallView(entry: entry)
        } else {
            WeekWidgetView(entry: entry)
        }
    }
}

struct DaySmallView: View {
    let entry: RangeEntry

    private var today: [CalendarEventData] {
        let calendar = Calendar.current
        return entry.events
            .filter { calendar.isDateInToday($0.start) }
            .sorted { $0.start < $1.start }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE, d/M"
        return formatter.string(from: entry.date).norteSentenceCased
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            if !entry.hasAccess {
                Spacer(); Text("Abra o Norte").font(.system(size: 11)).foregroundStyle(.secondary); Spacer()
            } else if today.isEmpty {
                Spacer(); Text("Dia livre 🎉").font(.system(size: 12)).foregroundStyle(.secondary); Spacer()
            } else {
                ForEach(today.prefix(3)) { event in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1.5).fill(eventColor(event)).frame(width: 3, height: 12)
                        Text(shortTime(event)).font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(event.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color(hex: "121216"), for: .widget)
        .widgetURL(NorteDeepLink.open)
    }
}

struct NorteDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NorteDayWidget", provider: WeekProvider()) { entry in
            AdaptiveDayWeekView(entry: entry)
        }
        .configurationDisplayName("Norte — semana")
        .description("Sua semana por dia (médio/grande) ou os eventos de hoje (pequeno).")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Provider de intervalo (semana / próximos dias)

struct RangeEntry: TimelineEntry {
    let date: Date
    let events: [CalendarEventData]
    let hasAccess: Bool
}

/// Carrega eventos de uma janela de dias a partir do início da semana atual
/// (segunda-feira). Usado pelos widgets de semana e de tarefas.
struct WeekProvider: TimelineProvider {
    private func loadEntry(at date: Date) -> RangeEntry {
        let service = EventKitCalendarService()
        guard service.authorizationGranted else {
            return RangeEntry(date: date, events: [], hasAccess: false)
        }
        let calendar = Calendar.current
        let start = AgendaGrouper.weekDays(containing: date, calendar: calendar).first
            ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? date
        let events = (try? service.events(from: start, to: end)) ?? []
        return RangeEntry(date: date, events: events, hasAccess: true)
    }

    func placeholder(in context: Context) -> RangeEntry {
        RangeEntry(date: .now, events: [], hasAccess: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RangeEntry) -> Void) {
        completion(loadEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RangeEntry>) -> Void) {
        let entry = loadEntry(at: Date())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget da semana (grid, estilo da referência)

/// Linha da lista: cabeçalho de dia ou um evento.
private enum WeekRow: Identifiable {
    case header(Date)
    case event(CalendarEventData)
    var id: String {
        switch self {
        case .header(let d): return "h\(d.timeIntervalSince1970)"
        case .event(let e): return "e\(e.id)"
        }
    }
}

struct WeekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RangeEntry

    private var calendar: Calendar { .current }
    private var days: [Date] { AgendaGrouper.weekDays(containing: entry.date, calendar: calendar) }
    private var grouped: [Date: [CalendarEventData]] {
        AgendaGrouper.groupByDay(events: entry.events, calendar: calendar)
    }
    private var rowBudget: Int { family == .systemLarge ? 13 : 5 }

    /// Dias de hoje até o fim da semana que têm eventos, achatados em linhas.
    private var rows: [WeekRow] {
        let today = calendar.startOfDay(for: .now)
        var out: [WeekRow] = []
        for day in days where day >= today {
            let evs = (grouped[day] ?? []).sorted { $0.start < $1.start }
            guard !evs.isEmpty else { continue }
            out.append(.header(day))
            out.append(contentsOf: evs.map { .event($0) })
        }
        return out
    }

    // Cor/sigla por contexto (tarefas) ou calendário (eventos).
    private func hexFor(_ event: CalendarEventData) -> String {
        if event.isTaskMirror {
            if let ctx = event.taskContext { return ctx.colorHex }
            if let u = Urgency.from(emojiPrefixOf: event.title) {
                switch u { case .alta: return "FF453A"; case .media: return "FFD60A"; case .baixa: return "30D158" }
            }
        }
        return event.colorHex
    }
    private func accent(_ event: CalendarEventData) -> Color { Color(pillHex: hexFor(event)) }

    private func sigla(_ event: CalendarEventData) -> String {
        if event.isTaskMirror {
            return event.taskContext?.shortCode ?? "TAR"
        }
        return TaskContext.from(displayName: event.calendarTitle)?.shortCode
            ?? String(event.calendarTitle.prefix(4)).uppercased()
    }

    private func displayTitle(_ event: CalendarEventData) -> String {
        guard event.isTaskMirror, let u = Urgency.from(emojiPrefixOf: event.title) else { return event.title }
        return event.title.replacingOccurrences(of: u.emoji, with: "").trimmingCharacters(in: .whitespaces)
    }

    private func timeShort(_ event: CalendarEventData) -> String {
        if event.isAllDay { return "dia" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.start)
    }

    private func headerText(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE d"
        var s = formatter.string(from: day).capitalized(with: Locale(identifier: "pt_BR"))
        if calendar.isDateInToday(day) { s = "Hoje · " + s }
        return s
    }

    var body: some View {
        Group {
            if !entry.hasAccess {
                centered("Abra o Norte para autorizar o calendário.")
            } else if rows.isEmpty {
                centered("Sem eventos essa semana 🎉")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(rows.prefix(rowBudget)) { row in
                        switch row {
                        case .header(let day):
                            Text(headerText(day))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        case .event(let event):
                            eventRow(event)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color(hex: "121216"), for: .widget)
        .widgetURL(NorteDeepLink.open)
    }

    private func centered(_ text: String) -> some View {
        VStack { Spacer(); Text(text).font(.system(size: 12)).foregroundStyle(.secondary); Spacer() }
            .frame(maxWidth: .infinity)
    }

    private func eventRow(_ event: CalendarEventData) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2).fill(accent(event)).frame(width: 3, height: 24)
            Text(timeShort(event))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)
            Text(displayTitle(event))
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(sigla(event))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(accent(event), in: Capsule())
        }
    }
}

struct NorteWeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NorteWeekWidget", provider: WeekProvider()) { entry in
            WeekWidgetView(entry: entry)
        }
        .configurationDisplayName("Minha semana")
        .description("Sua semana por dia: horário, título e a empresa (sigla).")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Widget de tarefas a vencer (por urgência)

struct TasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RangeEntry

    /// Colunas do Kanban exibidas no widget (as com prazo; "Feito" não é
    /// espelhado). Tarefas sem status caem em "A Fazer".
    private let columns: [TaskStatus] = [.backlog, .todo, .doing]

    private var tasks: [CalendarEventData] {
        entry.events.filter(\.isTaskMirror).sorted { $0.start < $1.start }
    }

    private func tasks(in status: TaskStatus) -> [CalendarEventData] {
        tasks.filter { ($0.taskStatus ?? .todo) == status }
    }

    private func urgencyColor(_ event: CalendarEventData) -> Color {
        Urgency.from(emojiPrefixOf: event.title)?.color ?? Color(hex: "8E8E93")
    }

    private func cleanTitle(_ event: CalendarEventData) -> String {
        guard let urgency = Urgency.from(emojiPrefixOf: event.title) else { return event.title }
        return event.title.replacingOccurrences(of: urgency.emoji, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "hoje" }
        if calendar.isDateInTomorrow(date) { return "amanhã" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE d/M"
        return formatter.string(from: date).lowercased()
    }

    var body: some View {
        Group {
            if !entry.hasAccess {
                centered("Abra o Norte para autorizar o calendário.")
            } else if tasks.isEmpty {
                centered("Nenhuma tarefa com prazo 🎉")
            } else if family == .systemSmall {
                listLayout
            } else {
                kanbanLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color(hex: "121216"), for: .widget)
        .widgetURL(NorteDeepLink.open)
    }

    private func centered(_ text: String) -> some View {
        VStack { Spacer(); Text(text).font(.system(size: 12)).foregroundStyle(.secondary); Spacer() }
            .frame(maxWidth: .infinity)
    }

    // Kanban: uma coluna por status (médio/grande).
    private var kanbanLayout: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(columns) { status in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text(status.displayName)
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(tasks(in: status).count)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(tasks(in: status).prefix(family == .systemLarge ? 6 : 3)) { task in
                        card(task)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    // Lista compacta (pequeno).
    private var listLayout: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Tarefas").font(.system(size: 12, weight: .semibold, design: .rounded))
            ForEach(tasks.prefix(4)) { task in
                HStack(spacing: 6) {
                    Circle().fill(urgencyColor(task)).frame(width: 7, height: 7)
                    Text(cleanTitle(task)).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(dayLabel(task.start)).font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Card do kanban; abre a tarefa no Norte ao clicar.
    @ViewBuilder
    private func card(_ task: CalendarEventData) -> some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(urgencyColor(task)).frame(width: 6, height: 6)
                Text(cleanTitle(task)).font(.system(size: 11, weight: .medium)).lineLimit(2)
            }
            Text(dayLabel(task.start)).font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))

        if let id = task.taskID {
            Link(destination: NorteDeepLink.task(id)) { content }
        } else {
            content
        }
    }
}

struct NorteTasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NorteTasksWidget", provider: WeekProvider()) { entry in
            TasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Tarefas a vencer")
        .description("Suas tarefas com prazo nesta semana, por urgência.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
