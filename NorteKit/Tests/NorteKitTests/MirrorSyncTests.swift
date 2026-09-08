import Testing
import Foundation
@testable import NorteKit

@Suite("MirrorPlanner")
struct MirrorSyncTests {
    let deadline = Date(timeIntervalSince1970: 1_760_000_000)
    let otherDeadline = Date(timeIntervalSince1970: 1_760_086_400)

    func snapshot(
        id: UUID = UUID(),
        title: String = "Entregar relatório",
        urgency: Urgency = .alta,
        status: TaskStatus = .doing,
        context: TaskContext = .nathPereira,
        deadline: Date?,
        isAllDay: Bool = false
    ) -> TaskSnapshot {
        TaskSnapshot(id: id, title: title, urgency: urgency, status: status,
                     context: context, deadline: deadline, deadlineIsAllDay: isAllDay)
    }

    func mirror(_ eventID: String, taskID: UUID, title: String = "🔴 Entregar relatório",
                deadline: Date, isAllDay: Bool = false, status: TaskStatus? = .doing,
                context: TaskContext? = .nathPereira) -> MirrorItem {
        MirrorItem(eventID: eventID, taskID: taskID, title: title,
                   deadline: deadline, isAllDay: isAllDay, status: status, context: context)
    }

    @Test func taskWithDeadlineAndNoMirrorIsCreated() {
        let task = snapshot(deadline: deadline)
        let actions = MirrorPlanner.plan(tasks: [task], existing: [])
        #expect(actions == [.create(taskID: task.id, title: "🔴 Entregar relatório",
                                    deadline: deadline, isAllDay: false, status: .doing,
                                    context: .nathPereira)])
    }

    @Test func taskWithoutDeadlineProducesNothing() {
        let actions = MirrorPlanner.plan(tasks: [snapshot(deadline: nil)], existing: [])
        #expect(actions.isEmpty)
    }

    @Test func unchangedMirrorProducesNothing() {
        let task = snapshot(deadline: deadline)
        let existing = mirror("ev1", taskID: task.id, deadline: deadline)
        #expect(MirrorPlanner.plan(tasks: [task], existing: [existing]).isEmpty)
    }

    @Test func driftedTitleOrDeadlineIsUpdated() {
        let task = snapshot(urgency: .media, deadline: otherDeadline)
        let existing = mirror("ev1", taskID: task.id, deadline: deadline)
        let actions = MirrorPlanner.plan(tasks: [task], existing: [existing])
        #expect(actions == [.update(eventID: "ev1", title: "🟡 Entregar relatório",
                                    deadline: otherDeadline, isAllDay: false, status: .doing,
                                    context: .nathPereira)])
    }

    @Test func statusDriftUpdatesMirror() {
        let task = snapshot(status: .doing, deadline: deadline)
        let existing = mirror("ev1", taskID: task.id, deadline: deadline, status: .todo)
        let actions = MirrorPlanner.plan(tasks: [task], existing: [existing])
        #expect(actions == [.update(eventID: "ev1", title: "🔴 Entregar relatório",
                                    deadline: deadline, isAllDay: false, status: .doing,
                                    context: .nathPereira)])
    }

    @Test func doneTaskDeletesItsMirror() {
        let task = snapshot(status: .done, deadline: deadline)
        let existing = mirror("ev1", taskID: task.id, deadline: deadline)
        #expect(MirrorPlanner.plan(tasks: [task], existing: [existing]) == [.delete(eventID: "ev1")])
    }

    @Test func removedDeadlineDeletesMirror() {
        let task = snapshot(deadline: nil)
        let existing = mirror("ev1", taskID: task.id, deadline: deadline)
        #expect(MirrorPlanner.plan(tasks: [task], existing: [existing]) == [.delete(eventID: "ev1")])
    }

    @Test func orphanEventIsDeleted() {
        let existing = mirror("ghost", taskID: UUID(), title: "🔴 Antiga", deadline: deadline)
        #expect(MirrorPlanner.plan(tasks: [], existing: [existing]) == [.delete(eventID: "ghost")])
    }

    @Test func duplicateMirrorsKeepFirstDeleteRest() {
        let task = snapshot(deadline: deadline)
        let keep = mirror("ev1", taskID: task.id, deadline: deadline)
        let dup = mirror("ev2", taskID: task.id, deadline: deadline)
        #expect(MirrorPlanner.plan(tasks: [task], existing: [keep, dup]) == [.delete(eventID: "ev2")])
    }

    @Test func planIsIdempotentAfterApplying() {
        let task = snapshot(deadline: deadline)
        let created = MirrorItem(eventID: "novo", taskID: task.id,
                                 title: MirrorPlanner.mirrorTitle(for: task),
                                 deadline: deadline, isAllDay: false,
                                 status: task.status, context: task.context)
        #expect(MirrorPlanner.plan(tasks: [task], existing: [created]).isEmpty)
    }
}
