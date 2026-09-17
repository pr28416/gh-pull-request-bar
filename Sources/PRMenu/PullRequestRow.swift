import AppKit
import SwiftUI

struct PullRequestRow: View {
    var pullRequest: PullRequest
    var onOpen: () -> Void
    var onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pullRequest.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Text(pullRequest.repository)
                        Text("·")
                        HStack(spacing: 3) {
                            MergeStatusIcon(status: displayStatus)
                            Text("#" + String(pullRequest.number))
                        }
                        Text("·")
                        Text(pullRequest.updatedAt.relativeLabel)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    Spacer(minLength: 6)

                    if pullRequest.hasDiff {
                        DiffStatView(
                            additions: pullRequest.additions,
                            deletions: pullRequest.deletions
                        )
                    }

                    CheckStatusView(summary: pullRequest.checks, compact: true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .contextMenu {
            Button("Open in Browser", action: onOpen)
            Button("Copy Link", action: onCopy)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var displayStatus: MergeStatus {
        pullRequest.displayStatus
    }

    private var accessibilityLabel: String {
        var parts = [
            displayStatus.accessibilityLabel,
            pullRequest.title,
            "\(pullRequest.repository) #\(pullRequest.number)",
        ]
        if pullRequest.hasDiff {
            parts.append("+\(pullRequest.additions.formatted()) -\(pullRequest.deletions.formatted())")
        }
        if pullRequest.checks.hasChecks {
            parts.append("\(pullRequest.checks.passed) of \(pullRequest.checks.total) checks passed")
        }
        return parts.joined(separator: ", ")
    }
}

private struct DiffStatView: View {
    var additions: Int
    var deletions: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Text("+\(additions.formatted())")
                .foregroundStyle(additionColor)
            Text("-\(deletions.formatted())")
                .foregroundStyle(deletionColor)
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("+\(additions.formatted()) minus \(deletions.formatted())")
    }

    private var additionColor: Color {
        colorScheme == .dark
            ? Color(red: 63 / 255, green: 185 / 255, blue: 80 / 255)
            : Color(red: 26 / 255, green: 127 / 255, blue: 55 / 255)
    }

    private var deletionColor: Color {
        colorScheme == .dark
            ? Color(red: 248 / 255, green: 81 / 255, blue: 73 / 255)
            : Color(red: 207 / 255, green: 34 / 255, blue: 46 / 255)
    }
}

private extension Date {
    var relativeLabel: String {
        let seconds = Int(Date().timeIntervalSince(self))
        if seconds < 60 {
            return "now"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }

        let days = hours / 24
        if days < 14 {
            return "\(days)d"
        }

        return formatted(.dateTime.month(.abbreviated).day())
    }
}
