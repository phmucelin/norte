import SwiftUI
import NorteKit

/// Cria ou edita um evento de calendário. Com `existing == nil` cria um novo no
/// dia indicado; caso contrário edita o evento informado (e permite apagá-lo).
struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let existing: CalendarEventData?
    /// `id` vem nil ao criar e preenchido ao editar.
    var onSave: (_ id: String?, _ title: String, _ context: TaskContext,
                 _ start: Date, _ end: Date, _ isAllDay: Bool, _ recurrence: Recurrence) -> Void
    var onDelete: (_ id: String) -> Void = { _ in }

    @State private var title: String
    @State private var context: TaskContext
    @State private var isAllDay: Bool
    @State private var start: Date
    @State private var end: Date
    @State private var recurrence: Recurrence

    init(day: Date,
         existing: CalendarEventData? = nil,
         onSave: @escaping (String?, String, TaskContext, Date, Date, Bool, Recurrence) -> Void,
         onDelete: @escaping (String) -> Void = { _ in }) {
        self.day = day
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete

        // Novo evento começa às 9h do dia selecionado, 1h de duração.
        let calendar = Calendar.current
        let base = calendar.date(bySettingHour: 9, minute: 0, second: 0,
                                 of: calendar.startOfDay(for: day)) ?? day
        _title = State(initialValue: existing?.title ?? "")
        _context = State(initialValue: existing.flatMap { TaskContext.from(displayName: $0.calendarTitle) } ?? .pessoal)
        _isAllDay = State(initialValue: existing?.isAllDay ?? false)
        _start = State(initialValue: existing?.start ?? base)
        _end = State(initialValue: existing?.end ?? base.addingTimeInterval(3600))
        _recurrence = State(initialValue: existing?.recurrence ?? .none)
    }

    private var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Editar evento" : "Novo evento")
                .font(.system(size: 16, weight: .semibold))

            TextField("Título do evento", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))

            // O calendário só é escolhido na criação; na edição o evento fica
            // no mesmo calendário (evita mover eventos de terceiros sem querer).
            if !isEditing {
                Picker("Agenda", selection: $context) {
                    ForEach(TaskContext.allCases) { context in
                        Text(context.displayName).tag(context)
                    }
                }
            }

            Toggle("Dia inteiro", isOn: $isAllDay)

            if !isAllDay {
                DatePicker("Início", selection: $start, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Fim", selection: $end, displayedComponents: [.date, .hourAndMinute])
            } else {
                DatePicker("Data", selection: $start, displayedComponents: [.date])
            }

            Picker("Repetir", selection: $recurrence) {
                ForEach(Recurrence.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            if recurrence != .none {
                Text("O evento se repete no calendário automaticamente.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack {
                if isEditing, let id = existing?.id {
                    Button("Apagar evento", role: .destructive) {
                        onDelete(id)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Salvar" : "Criar") {
                    onSave(existing?.id, title.trimmingCharacters(in: .whitespaces),
                           context, start, end, isAllDay, recurrence)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
