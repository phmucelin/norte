import SwiftUI
import NorteKit

/// Lista do dia selecionado: eventos em ordem cronológica e, separada,
/// a seção de tarefas espelhadas com cor de urgência.
struct DayListView: View {
    let day: Date
    let events: [CalendarEventData]

    private var appointments: [CalendarEventData] { events.filter { !$0.isTaskMirror } }
    private var mirrorTasks: [CalendarEventData] { events.filter(\.isTaskMirror) }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            if events.isEmpty {
                Text("Dia livre 🎉")
                    .font(.system(size: 13))
                    .foregroundStyle(Norte.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }

            ForEach(appointments) { event in
                iOSEventRow(event: event)
            }

            if !mirrorTasks.isEmpty {
                Text("Tarefas")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.top, appointments.isEmpty ? 0 : 10)
                ForEach(mirrorTasks) { event in
                    iOSEventRow(event: event)
                }
            }
        }
        .padding(.horizontal, 12)
    }
}

struct iOSEventRow: View {
    let event: CalendarEventData

    private var accentColor: Color {
        if event.isTaskMirror, let urgency = Urgency.from(emojiPrefixOf: event.title) {
            return urgency.color
        }
        return Color(hex: event.colorHex)
    }

    private var displayTitle: String {
        guard event.isTaskMirror, let urgency = Urgency.from(emojiPrefixOf: event.title) else {
            return event.title
        }
        return event.title
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: urgency.emoji, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private var timeText: String {
        if event.isAllDay { return "dia todo" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.start)
    }

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: event.isTaskMirror ? "checklist" : "clock")
                        .font(.system(size: 10))
                    Text(timeText)
                        .font(.system(size: 12, design: .rounded))
                }
                .foregroundStyle(Norte.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
