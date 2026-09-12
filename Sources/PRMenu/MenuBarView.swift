import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var state: AppState
    @State private var listContentHeight: CGFloat = 0

    private let panelWidth: CGFloat = 420
    private let panelMaxHeight: CGFloat = 540
    private let headerReserve: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if state.showsSettings {
                SettingsView(state: state)
            } else {
                pullRequestList
            }
        }
        .frame(width: panelWidth)
        .frame(maxHeight: panelMaxHeight, alignment: .top)
        .fixedSize()
        .onAppear {
            state.setPanelVisible(true)
        }
        .onDisappear {
            state.setPanelVisible(false)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if state.showsSettings {
                Button {
                    state.showsSettings = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Pull Requests")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .help("Back")
            } else {
                Text("Pull Requests")
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer(minLength: 8)

            Button {
                Task { await state.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolEffect(.rotate.clockwise, options: .repeating, isActive: state.isLoading)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Refresh")

            GitHubUserChip(snapshot: state.snapshot) {
                state.showsSettings.toggle()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .zIndex(1)
    }

    private var pullRequestList: some View {
        VStack(spacing: 0) {
            if state.isLoading, !state.hasAnyPullRequests {
                StatusPane(
                    title: "Loading pull requests",
                    message: "Fetching created, assigned, and review-requested PRs.",
                    systemImage: "arrow.triangle.pull"
                )
            } else if let errorMessage = state.errorMessage, !state.hasAnyPullRequests {
                StatusPane(
                    title: "Couldn’t load pull requests",
                    message: errorMessage,
                    systemImage: "exclamationmark.triangle"
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let errorMessage = state.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6)
                        }

                        ForEach(visibleSections) { section in
                            SectionView(section: section, state: state)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: ListHeightKey.self, value: proxy.size.height)
                        }
                    }
                }
                .onPreferenceChange(ListHeightKey.self) { listContentHeight = $0 }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(max(listContentHeight, 1), panelMaxHeight - headerReserve))
            }
        }
    }

    private var visibleSections: [PullRequestSection] {
        PullRequestSection.allCases.filter { section in
            !section.hidesWhenEmpty || !state.snapshot.pullRequests(in: section).isEmpty
        }
    }
}

private struct GitHubUserChip: View {
    var snapshot: PullRequestSnapshot
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    private var label: String {
        let name = snapshot.viewerDisplayName
        return name.isEmpty ? "Settings" : name
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = snapshot.viewerAvatarURL.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholder
                }
            }
            .frame(width: 18, height: 18)
            .clipShape(Circle())
        } else {
            placeholder
                .frame(width: 18, height: 18)
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
    }
}

private struct SectionView: View {
    var section: PullRequestSection
    var state: AppState

    var body: some View {
        let groups = state.snapshot.groupedPullRequests(in: section)
        let totalCount = groups.recent.count + groups.older.count
        let showsOlder = state.expandedOlderSections.contains(section)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(section.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(totalCount)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)

            if totalCount == 0 {
                Text(section.emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                ForEach(groups.recent) { pullRequest in
                    row(pullRequest)
                }

                if !groups.older.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.toggleOlder(in: section)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .rotationEffect(.degrees(showsOlder ? 90 : 0))
                            Text("More")
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                            Text("\(groups.older.count)")
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        showsOlder
                            ? "Hide \(groups.older.count) older pull requests"
                            : "Show \(groups.older.count) older pull requests"
                    )

                    if showsOlder {
                        ForEach(groups.older) { pullRequest in
                            row(pullRequest)
                        }
                    }
                }
            }
        }
    }

    private func row(_ pullRequest: PullRequest) -> some View {
        PullRequestRow(
            pullRequest: pullRequest,
            onOpen: { state.open(pullRequest) },
            onCopy: { state.copyLink(pullRequest) }
        )
    }
}

private struct StatusPane: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

private struct ListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
