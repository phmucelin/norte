import SwiftUI
import SwiftData
import EventKit
import WidgetKit
import NorteKit

/// Orquestra EventKit: permissão, bootstrap dos calendários, leitura de
/// eventos para a agenda e reconciliação do espelho de tarefas.
@MainActor
final class SyncCoordinator: ObservableObject {
    @Published var permissionGranted = false
    @Published var googleAvailable = true
    @Published var calendarsReady = false
    @Published var events: [CalendarEventData] = []
    @Published var syncError: String?

    private let service = EventKitCalendarService()
    private var modelContext: ModelContext?
    private var reconcileScheduled = false

    /// Janela da agenda: hoje + próximos dias.
    var agendaDays: Int = 4
    /// Quando true, a janela cobre a semana atual inteira (usado no iPhone).
    var useWeekWindow = false

    func start(modelContext: ModelContext?) async {
        self.modelContext = modelContext
        do {
            permissionGranted = try await service.requestAccess()
        } catch {
            permissionGranted = false
        }
        guard permissionGranted else { return }

        googleAvailable = service.googleSourceAvailable()
        do {
            try service.ensureCalendars()
            calendarsReady = true
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }

        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadEvents()
                self?.taskDidChange()
            }
        }

        topUpSeries()
        reconcile()
        loadEvents()
    }

    /// Materializa as próximas ocorrências das tarefas recorrentes (Option 2:
    /// "aparece em todos os dias"). Não depende de permissão de calendário.
    func topUpSeries() {
        guard let modelContext else { return }
        RecurrenceEngine.fillSeries(in: modelContext)
    }

    /// Cria um evento no calendário do contexto e recarrega a agenda.
    func createEvent(title: String, context: TaskContext, start: Date, end: Date,
                     isAllDay: Bool, recurrence: Recurrence = .none) {
        do {
            try service.createEvent(title: title, start: start, end: end,
                                    isAllDay: isAllDay, calendarTitle: context.displayName,
                                    recurrence: recurrence)
            syncError = nil
            loadEvents()
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// Edita um evento existente e recarrega a agenda.
    func updateEvent(id: String, title: String, start: Date, end: Date,
                     isAllDay: Bool, recurrence: Recurrence = .none) {
        do {
            try service.updateEvent(id: id, title: title, start: start, end: end,
                                    isAllDay: isAllDay, recurrence: recurrence)
            syncError = nil
            loadEvents()
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// Apaga um evento e recarrega a agenda.
    func deleteEvent(id: String) {
        do {
            try service.deleteEvent(id: id)
            syncError = nil
            loadEvents()
        } catch {
            syncError = error.localizedDescription
        }
    }

    func loadEvents() {
        guard permissionGranted else { return }
        let calendar = Calendar.current
        let start: Date
        let spanDays: Int
        if useWeekWindow {
            start = AgendaGrouper.weekDays(containing: .now, calendar: calendar).first
                ?? calendar.startOfDay(for: .now)
            spanDays = 7
        } else {
            start = calendar.startOfDay(for: .now)
            spanDays = agendaDays
        }
        guard let end = calendar.date(byAdding: .day, value: spanDays, to: start) else { return }
        do {
            events = try service.events(from: start, to: end)
            // Avisa os widgets pra atualizarem em segundos, em vez de esperar a
            // janela de ~30 min. loadEvents() roda após toda mudança (criar/
            // editar/apagar evento, editar tarefa) e no EKEventStoreChanged.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// Reconciliação com debounce: chamadas em sequência viram uma só.
    func taskDidChange() {
        guard !reconcileScheduled else { return }
        reconcileScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            reconcileScheduled = false
            topUpSeries()
            reconcile()
            loadEvents()
        }
    }

    func reconcile() {
        guard permissionGranted, calendarsReady, let modelContext else { return }
        do {
            let tasks = try modelContext.fetch(FetchDescriptor<NorteTask>())
            let snapshots = tasks.map {
                TaskSnapshot(id: $0.id, title: $0.title, urgency: $0.urgency,
                             status: $0.status, context: $0.context, deadline: $0.deadline,
                             deadlineIsAllDay: $0.deadlineIsAllDay)
            }
            let existing = try service.mirrorItems()
            let actions = MirrorPlanner.plan(tasks: snapshots, existing: existing)
            let created = try service.apply(actions)
            if !created.isEmpty {
                for task in tasks {
                    if let eventID = created[task.id] { task.mirrorEventID = eventID }
                }
                try? modelContext.save()
            }
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }
}
