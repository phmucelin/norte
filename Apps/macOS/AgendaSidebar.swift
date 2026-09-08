import SwiftUI
import NorteKit

struct AgendaSidebar: View {
    @ObservedObject var coordinator: SyncCoordinator
    /// Dia selecionado na grade da semana.
    var selectedDay: Date

    @State private var showingNewEvent = false

    private var calendar: Calendar { .current }

    private var grouped: [Date: [CalendarEventData]] {
        AgendaGrouper.groupByDay(events: coordinator.events, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Agenda")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    showingNewEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .help("Novo evento neste dia")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    daySection(calendar.startOfDay(for: selectedDay))
                }
                .padding(12)
            }

            if let error = coordinator.syncError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.system(size: 11))
                        .lineLimit(3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1))
            }
        }
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingNewEvent) {
            EventEditorSheet(day: selectedDay) { title, context, start, end, isAllDay in
                coordinator.createEvent(title: title, context: context,
                                        start: start, end: end, isAllDay: isAllDay)
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "Hoje" }
        if calendar.isDateInTomorrow(day) { return "Amanhã" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d/M"
        return formatter.string(from: day).norteSentenceCased
    }

    @ViewBuilder
    private func daySection(_ day: Date) -> some View {
        let dayEvents = grouped[day] ?? []
        VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle(day))
                .font(.system(size: 13, weight: .semibold))

            if dayEvents.isEmpty {
                Text("Livre 🎉")
                    .font(.system(size: 11))
                    .foregroundStyle(Norte.secondaryText)
            } else {
                ForEach(dayEvents) { event in
                    EventRow(event: event)
                }
            }
        }
    }
}

struct EventRow: View {
    let event: CalendarEventData

    private var accentColor: Color {
        if event.isTaskMirror, let urgency = Urgency.from(emojiPrefixOf: event.title) {
            return urgency.color
        }
        return Color(hex: event.colorHex)
    }

    private var timeText: String {
        if event.isAllDay { return "dia todo" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.start)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(timeText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Norte.secondaryText)
                .frame(width: 46, alignment: .trailing)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(event.isTaskMirror ? "tarefa" : event.calendarTitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Norte.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
