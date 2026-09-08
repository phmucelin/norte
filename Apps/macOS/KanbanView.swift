import SwiftUI
import SwiftData
import NorteKit

struct KanbanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NorteTask.createdAt, order: .reverse) private var tasks: [NorteTask]

    /// Chamado após qualquer mudança que afete o espelho no calendário.
    var onTasksChanged: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(TaskStatus.allCases) { status in
                column(for: status)
            }
        }
        .padding(12)
    }

    private func visibleTasks(in status: TaskStatus) -> [NorteTask] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        return tasks.filter { task in
            guard task.status == status, appState.matches(task) else { return false }
            if status == .done, let completedAt = task.completedAt, completedAt < cutoff {
                return false
            }
            return true
        }
    }

    private func column(for status: TaskStatus) -> some View {
        let columnTasks = visibleTasks(in: status)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(status.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(columnTasks.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Norte.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(columnTasks) { task in
                        TaskCardView(task: task)
                            .draggable(task.id.uuidString)
                            .onTapGesture { appState.editingTask = task }
                    }
                    if columnTasks.isEmpty {
                        Text(status == .backlog ? "Sem tarefas aqui. ⌘N cria a primeira." : "Arraste um card para cá.")
                            .font(.system(size: 11))
                            .foregroundStyle(Norte.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
                .padding(2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
        .dropDestination(for: String.self) { items, _ in
            move(taskIDs: items, to: status)
        }
    }

    private func move(taskIDs: [String], to status: TaskStatus) -> Bool {
        var moved = false
        for idString in taskIDs {
            guard let uuid = UUID(uuidString: idString),
                  let task = tasks.first(where: { $0.id == uuid }),
                  task.status != status else { continue }
            let wasDone = task.status == .done
            task.status = status
            if status == .done && !wasDone {
                RecurrenceEngine.spawnNextIfNeeded(completed: task, in: modelContext)
            }
            moved = true
        }
        if moved {
            try? modelContext.save()
            onTasksChanged()
        }
        return moved
    }
}
