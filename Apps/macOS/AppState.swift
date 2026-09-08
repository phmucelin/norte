import SwiftUI
import NorteKit

@MainActor
final class AppState: ObservableObject {
    /// Contextos ativos no filtro; vazio significa "todos".
    @Published var selectedContexts: Set<TaskContext> = []
    @Published var searchText = ""
    @Published var showingNewTask = false
    @Published var editingTask: NorteTask?
    /// Dia selecionado na grade da semana; a agenda lateral mostra este dia.
    @Published var selectedDay: Date = Calendar.current.startOfDay(for: .now)

    func matches(_ task: NorteTask) -> Bool {
        if !selectedContexts.isEmpty && !selectedContexts.contains(task.context) {
            return false
        }
        if !searchText.isEmpty {
            return task.title.localizedCaseInsensitiveContains(searchText)
                || task.notes.localizedCaseInsensitiveContains(searchText)
        }
        return true
    }
}
