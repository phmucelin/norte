import SwiftUI
import SwiftData
import NorteKit

/// Criação e edição de tarefa. Com `task == nil`, cria uma nova.
struct TaskEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let task: NorteTask?
    var onSave: () -> Void = {}

    @State private var title = ""
    @State private var context: TaskContext = .iaSolutions
    @State private var urgency: Urgency = .media
    @State private var status: TaskStatus = .todo
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var deadlineIsAllDay = true
    @State private var recurrence: Recurrence = .none
    @State private var notes = ""

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
        .onAppear(perform: load)
    }

    private func load() {
        guard let task else { return }
        title = task.title
        context = task.context
        urgency = task.urgency
        status = task.status
        hasDeadline = task.deadline != nil
        deadline = task.deadline ?? deadline
        deadlineIsAllDay = task.deadlineIsAllDay
        recurrence = task.recurrence
        notes = task.notes
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let effectiveRecurrence = hasDeadline ? recurrence : .none
        if let task {
            let wasDone = task.status == .done
            task.title = trimmed
            task.context = context
            task.urgency = urgency
            task.status = status
            task.deadline = hasDeadline ? deadline : nil
            task.deadlineIsAllDay = deadlineIsAllDay
            task.recurrence = effectiveRecurrence
            task.notes = notes
            if status == .done && !wasDone {
                RecurrenceEngine.spawnNextIfNeeded(completed: task, in: modelContext)
            }
        } else {
            let newTask = NorteTask(
                title: trimmed, context: context, urgency: urgency, status: status,
                deadline: hasDeadline ? deadline : nil,
                deadlineIsAllDay: deadlineIsAllDay,
                recurrence: effectiveRecurrence, notes: notes
            )
            modelContext.insert(newTask)
            if status == .done {
                RecurrenceEngine.spawnNextIfNeeded(completed: newTask, in: modelContext)
            }
        }
        try? modelContext.save()
        onSave()
        dismiss()
    }
}
