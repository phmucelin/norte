import SwiftUI
import SwiftData
import NorteKit

/// Criação e edição de tarefa. Com `task == nil`, cria uma nova.
struct TaskEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let task: NorteTask?
    var onSave: () -> Void = {}

    @State private var title: String
    @State private var context: TaskContext
    @State private var urgency: Urgency
    @State private var status: TaskStatus
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var deadlineIsAllDay: Bool
    @State private var recurrence: Recurrence
    @State private var notes: String

    /// Popula os campos já na construção (não no `.onAppear`, que em sheet no
    /// macOS pode não disparar — o que deixava a edição abrir com os defaults).
    init(task: NorteTask?, onSave: @escaping () -> Void = {}) {
        self.task = task
        self.onSave = onSave
        let fallbackDeadline = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        _title = State(initialValue: task?.title ?? "")
        _context = State(initialValue: task?.context ?? .iaSolutions)
        _urgency = State(initialValue: task?.urgency ?? .media)
        _status = State(initialValue: task?.status ?? .todo)
        _hasDeadline = State(initialValue: task?.deadline != nil)
        _deadline = State(initialValue: task?.deadline ?? fallbackDeadline)
        _deadlineIsAllDay = State(initialValue: task?.deadlineIsAllDay ?? true)
        _recurrence = State(initialValue: task?.recurrence ?? .none)
        _notes = State(initialValue: task?.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(task == nil ? "Nova tarefa" : "Editar tarefa")
                .font(.system(size: 16, weight: .semibold))

            TextField("O que precisa ser feito?", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))

            Picker("Contexto", selection: $context) {
                ForEach(TaskContext.allCases) { context in
                    Text(context.displayName).tag(context)
                }
            }

            Picker("Urgência", selection: $urgency) {
                ForEach(Urgency.allCases) { urgency in
                    Text("\(urgency.emoji) \(urgency.displayName)").tag(urgency)
                }
            }
            .pickerStyle(.segmented)

            Picker("Coluna", selection: $status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }

            Toggle("Tem prazo", isOn: $hasDeadline)
            if hasDeadline {
                DatePicker("Prazo", selection: $deadline,
                           displayedComponents: deadlineIsAllDay ? [.date] : [.date, .hourAndMinute])
                Toggle("Dia inteiro", isOn: $deadlineIsAllDay)
                Picker("Repetir", selection: $recurrence) {
                    ForEach(Recurrence.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                if recurrence != .none {
                    Text("Ao concluir, a próxima ocorrência é criada automaticamente.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Notas")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextEditor(text: $notes)
                    .font(.system(size: 13))
                    .frame(height: 60)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                if let task {
                    Button("Apagar tarefa", role: .destructive) {
                        modelContext.delete(task)
                        try? modelContext.save()
                        onSave()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let effectiveRecurrence = hasDeadline ? recurrence : .none
        if let task {
            task.title = trimmed
            task.context = context
            task.urgency = urgency
            task.status = status
            task.deadline = hasDeadline ? deadline : nil
            task.deadlineIsAllDay = deadlineIsAllDay
            task.recurrence = effectiveRecurrence
            task.notes = notes
        } else {
            let newTask = NorteTask(
                title: trimmed, context: context, urgency: urgency, status: status,
                deadline: hasDeadline ? deadline : nil,
                deadlineIsAllDay: deadlineIsAllDay,
                recurrence: effectiveRecurrence, notes: notes
            )
            modelContext.insert(newTask)
        }
        try? modelContext.save()
        // A materialização da série recorrente (Option 2) acontece no
        // coordinator via onSave() → taskDidChange() → fillSeries().
        onSave()
        dismiss()
    }
}
