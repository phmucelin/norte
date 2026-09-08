import WidgetKit
import SwiftUI
import NorteKit

// Widgets exclusivos do iOS (tela de bloqueio). O widget do dia e o motor de
// timeline moram em Apps/WidgetsShared/WidgetShared.swift.

// MARK: - Lock screen: linha única

struct InlineWidgetView: View {
    let entry: AgendaEntry

    var body: some View {
        if let next = entry.upcoming.first {
            Text("\(shortTime(next)) \(next.title)")
        } else {
            Text(entry.hasAccess ? "Sem mais eventos hoje" : "Abra o Norte")
        }
    }
}

struct NorteInlineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NorteInlineWidget", provider: AgendaProvider()) { entry in
            InlineWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Próximo evento")
        .description("O próximo compromisso do dia, na tela de bloqueio.")
        .supportedFamilies([.accessoryInline])
    }
}

// MARK: - Lock screen: retangular

struct RectangularWidgetView: View {
    let entry: AgendaEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.upcoming.isEmpty {
                Text(entry.hasAccess ? "Sem mais eventos hoje 🎉" : "Abra o Norte para autorizar")
                    .font(.system(size: 12, weight: .medium))
            } else {
                ForEach(entry.upcoming.prefix(3)) { event in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(eventColor(event))
                            .frame(width: 3, height: 12)
                        Text(shortTime(event))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text(event.title)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NorteRectangularWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NorteRectangularWidget", provider: AgendaProvider()) { entry in
            RectangularWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Meu dia")
        .description("Os próximos compromissos e tarefas, na tela de bloqueio.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Bundle iOS

@main
struct NorteWidgetBundle: WidgetBundle {
    var body: some Widget {
        NorteInlineWidget()
        NorteRectangularWidget()
        NorteDayWidget()
        NorteWeekWidget()
        NorteTasksWidget()
    }
}
