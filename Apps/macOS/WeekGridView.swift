import SwiftUI
import NorteKit

/// Grade da semana em largura total no topo do app (estilo da referência):
/// 7 colunas com blocos coloridos por evento/tarefa. Clicar seleciona o dia.
struct WeekGridView: View {
    @ObservedObject var coordinator: SyncCoordinator
    @Binding var selectedDay: Date

    private var calendar: Calendar { .current }
    private var days: [Date] { AgendaGrouper.weekDays(containing: .now, calendar: calendar) }
    private var grouped: [Date: [CalendarEventData]] {
        AgendaGrouper.groupByDay(events: coordinator.events, calendar: calendar)
    }

    private func weekdayLabel(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: day).prefix(3)).lowercased()
    }

    private func pillHex(_ event: CalendarEventData) -> String {
        if event.isTaskMirror, let urgency = Urgency.from(emojiPrefixOf: event.title) {
            switch urgency {
            case .alta: return "FF453A"
            case .media: return "FFD60A"
            case .baixa: return "30D158"
            }
        }
        return event.colorHex
    }

    private func blockColor(_ event: CalendarEventData) -> Color {
        Color(pillHex: pillHex(event))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(days, id: \.self) { day in
                dayColumn(day)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func dayColumn(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let dayEvents = grouped[day] ?? []

        VStack(spacing: 5) {
            Text(weekdayLabel(day))
                .font(.system(size: 11))
                .foregroundStyle(isToday ? .primary : Norte.secondaryText)
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 17, weight: isToday ? .bold : .regular, design: .rounded))

            VStack(spacing: 3) {
                ForEach(dayEvents.prefix(6)) { event in
                    eventPill(event)
                }
                if dayEvents.count > 6 {
                    Text("+\(dayEvents.count - 6)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Norte.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.white.opacity(0.35) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedDay = day }
    }

    /// Pílula do evento com hora + título (como na referência).
    private func eventPill(_ event: CalendarEventData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !event.isAllDay {
                Text(timeShort(event))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(event.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(blockColor(event), in: RoundedRectangle(cornerRadius: 4))
    }

    private func timeShort(_ event: CalendarEventData) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.start)
    }
}
