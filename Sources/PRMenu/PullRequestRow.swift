import AppKit
import SwiftUI

struct PullRequestRow: View {
    var pullRequest: PullRequest
    var onOpen: () -> Void
    var onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pullRequest.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 5) {
                        Text(pullRequest.repository)
                        Text("·")
                        Text("#" + String(pullRequest.number))
                        Text("·")
                        Text(pullRequest.updatedAt.relativeLabel)
                        if pullRequest.isDraft {
                            Text("Draft")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .overlay(
                                    Capsule().strokeBorder(Color.secondary.opacity(0.45), lineWidth: 1)
                                )
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                CheckStatusView(summary: pullRequest.checks)
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

    private var accessibilityLabel: String {
        var parts = [
            pullRequest.title,
            "\(pullRequest.repository) #\(pullRequest.number)",
        ]
        if pullRequest.checks.hasChecks {
            parts.append("\(pullRequest.checks.passed) of \(pullRequest.checks.total) checks passed")
        }
        return parts.joined(separator: ", ")
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
