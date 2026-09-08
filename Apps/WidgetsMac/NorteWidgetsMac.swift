import WidgetKit
import SwiftUI

// Widgets de desktop / central de notificações do macOS. Reusa o widget do
// dia definido em Apps/WidgetsShared/WidgetShared.swift (systemSmall/medium/large).

@main
struct NorteMacWidgetBundle: WidgetBundle {
    var body: some Widget {
        NorteWeekWidget()
        NorteDayWidget()
        NorteTasksWidget()
    }
}
