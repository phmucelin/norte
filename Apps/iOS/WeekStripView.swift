import SwiftUI
import NorteKit

/// Faixa da semana: 7 colunas com mini-blocos coloridos por evento,
/// inspirada na referência visual do usuário.
struct WeekStripView: View {
    let grouped: [Date: [CalendarEventData]]
    @Binding var selectedDay: Date

    private var calendar: Calendar { .current }
    private var days: [Date] { AgendaGrouper.weekDays(containing: .now, calendar: calendar) }

    private func weekdayLabel(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: day).prefix(3)).lowercased()
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                dayColumn(day)
            }
        }
        .padding(.horizontal, 12)
    }

    private func blockColor(_ event: CalendarEventData) -> Color {
        if event.isTaskMirror, let urgency = Urgency.from(emojiPrefixOf: event.title) {
            return urgency.color
        }
        return Color(hex: event.colorHex)
    }

    @ViewBuilder
    private func dayColumn(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let dayEvents = grouped[day] ?? []

        VStack(spacing: 6) {
            Text(weekdayLabel(day))
                .font(.system(size: 11))
                .foregroundStyle(isToday ? .primary : Norte.secondaryText)
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 16, weight: isToday ? .bold : .regular, design: .rounded))

            VStack(spacing: 3) {
                ForEach(dayEvents.prefix(4)) { event in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(blockColor(event).opacity(0.9))
                        .frame(height: 8)
                }
                if dayEvents.count > 4 {
                    Text("+\(dayEvents.count - 4)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Norte.secondaryText)
                }
                if dayEvents.isEmpty {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .top)
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
}
