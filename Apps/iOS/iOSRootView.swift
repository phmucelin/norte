import SwiftUI
import NorteKit

struct iOSRootView: View {
    @StateObject private var coordinator: SyncCoordinator = {
        let coordinator = SyncCoordinator()
        coordinator.useWeekWindow = true
        return coordinator
    }()

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private var grouped: [Date: [CalendarEventData]] {
        AgendaGrouper.groupByDay(events: coordinator.events)
    }

    private var headerText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: selectedDay).norteSentenceCased
    }

    var body: some View {
        Group {
            if coordinator.permissionGranted {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(headerText)
                            .font(.system(size: 22, weight: .light, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        WeekStripView(grouped: grouped, selectedDay: $selectedDay)

                        DayListView(day: selectedDay,
                                    events: grouped[selectedDay] ?? [])
                    }
                    .padding(.bottom, 24)
                }
                .refreshable { coordinator.loadEvents() }
            } else {
                iOSOnboardingView {
                    Task { await coordinator.start(modelContext: nil) }
                }
            }
        }
        .background(Norte.background.ignoresSafeArea())
        .task { await coordinator.start(modelContext: nil) }
    }
}

struct iOSOnboardingView: View {
    var retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color(hex: "7C5CFF"))
            Text("O Norte precisa do seu calendário")
                .font(.system(size: 17, weight: .semibold))
            Text("Sua agenda e suas tarefas vêm do calendário do sistema. Se a conta Google ainda não estiver no iPhone, adicione em Ajustes → Apps → Calendário → Contas.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Autorizar acesso") { retry() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
