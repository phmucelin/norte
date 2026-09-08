import SwiftUI
import NorteKit

struct TaskCardView: View {
    let task: NorteTask

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.context.color)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 8)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(task.urgency.color)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    Text(task.context.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(task.context.color)

                    if let deadline = task.deadline {
                        let relative = DeadlineFormatter.relative(deadline)
                        Text(relative.text)
                            .font(.system(size: 11, weight: relative.isOverdue ? .semibold : .regular))
                            .foregroundStyle(relative.isOverdue ? Color(hex: "FF453A") : Norte.secondaryText)
                    }

                    if task.recurrence != .none {
                        Image(systemName: "repeat")
                            .font(.system(size: 9))
                            .foregroundStyle(Norte.secondaryText)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.07))
        )
    }
}
