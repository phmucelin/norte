import SwiftUI
import SwiftData
import NorteKit

@main
struct NorteApp: App {
    @StateObject private var appState = AppState()
    let container: ModelContainer

    init() {
        container = NorteApp.makeContainer()
    }

    /// Cria o container e, se o store estiver incompatível (ex.: schema antigo
    /// que não migra), recria do zero — o app nunca deve rodar num estado
    /// quebrado silencioso.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([NorteTask.self])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            FileHandle.standardError.write(
                Data("Norte: falha ao abrir o store (\(error)). Recriando do zero.\n".utf8))
            let base = config.url
            let dir = base.deletingLastPathComponent()
            for suffix in ["", "-shm", "-wal"] {
                let url = dir.appendingPathComponent(base.lastPathComponent + suffix)
                try? FileManager.default.removeItem(at: url)
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Norte: não foi possível criar o store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1000, minHeight: 620)
        }
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nova tarefa") { appState.showingNewTask = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var coordinator: SyncCoordinator = {
        let coordinator = SyncCoordinator()
        coordinator.useWeekWindow = true
        return coordinator
    }()

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            if coordinator.permissionGranted {
                WeekGridView(coordinator: coordinator, selectedDay: $appState.selectedDay)
            }
            HSplitView {
                KanbanView(onTasksChanged: { coordinator.taskDidChange() })
                    .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
                Group {
                    if coordinator.permissionGranted {
                        AgendaSidebar(coordinator: coordinator, selectedDay: appState.selectedDay)
                    } else {
                        AgendaPermissionPrompt {
                            Task { await coordinator.start(modelContext: modelContext) }
                        }
                    }
                }
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 340, maxHeight: .infinity)
            }
        }
        .background(Norte.background)
        .task { await coordinator.start(modelContext: modelContext) }
        .onOpenURL { url in handleDeepLink(url) }
        .sheet(isPresented: $appState.showingNewTask) {
            TaskEditorSheet(task: nil, onSave: { coordinator.taskDidChange() })
        }
        .sheet(item: $appState.editingTask) { task in
            TaskEditorSheet(task: task, onSave: { coordinator.taskDidChange() })
        }
    }

    /// norte://task/<uuid> abre a tarefa no editor; norte://open só traz o app
    /// à frente (comportamento automático ao abrir a URL).
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "norte", url.host == "task" else { return }
        let idString = url.lastPathComponent
        guard let uuid = UUID(uuidString: idString) else { return }
        let descriptor = FetchDescriptor<NorteTask>(predicate: #Predicate { $0.id == uuid })
        if let task = try? modelContext.fetch(descriptor).first {
            appState.editingTask = task
        }
    }
}

struct HeaderBar: View {
    @EnvironmentObject private var appState: AppState

    private var todayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: .now).norteSentenceCased
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(todayText)
                .font(.system(size: 20, weight: .light, design: .rounded))

            Spacer()

            ForEach(TaskContext.allCases) { context in
                ContextChip(context: context,
                            isSelected: appState.selectedContexts.contains(context)) {
                    if appState.selectedContexts.contains(context) {
                        appState.selectedContexts.remove(context)
                    } else {
                        appState.selectedContexts.insert(context)
                    }
                }
            }

            TextField("Buscar", text: $appState.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            Button {
                appState.showingNewTask = true
            } label: {
                Label("Nova tarefa", systemImage: "plus")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

struct ContextChip: View {
    let context: TaskContext
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle().fill(context.color).frame(width: 7, height: 7)
                Text(context.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isSelected ? context.color.opacity(0.22) : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? context.color : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
