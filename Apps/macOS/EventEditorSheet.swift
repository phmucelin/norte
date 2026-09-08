import SwiftUI
import NorteKit

/// Cria um evento de calendário no dia selecionado, num calendário de contexto.
struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let day: Date
    var onCreate: (_ title: String, _ context: TaskContext, _ start: Date, _ end: Date, _ isAllDay: Bool) -> Void

    @State private var title = ""
    @State private var context: TaskContext = .pessoal
    @State private var isAllDay = false
    @State private var start: Date
    @State private var end: Date

    init(day: Date,
         onCreate: @escaping (String, TaskContext, Date, Date, Bool) -> Void) {
        self.day = day
        self.onCreate = onCreate
        // Começa às 9h do dia selecionado, 1h de duração.
        let calendar = Calendar.current
        let base = calendar.date(bySettingHour: 9, minute: 0, second: 0,
                                 of: calendar.startOfDay(for: day)) ?? day
        _start = State(initialValue: base)
        _end = State(initialValue: base.addingTimeInterval(3600))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Novo evento")
                .font(.system(size: 16, weight: .semibold))

            TextField("Título do evento", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))

            Picker("Agenda", selection: $context) {
                ForEach(TaskContext.allCases) { context in
                    Text(context.displayName).tag(context)
                }
            }

            Toggle("Dia inteiro", isOn: $isAllDay)

            if !isAllDay {
                DatePicker("Início", selection: $start, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Fim", selection: $end, displayedComponents: [.date, .hourAndMinute])
            } else {
                DatePicker("Data", selection: $start, displayedComponents: [.date])
            }

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Criar") {
                    onCreate(title.trimmingCharacters(in: .whitespaces), context, start, end, isAllDay)
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
