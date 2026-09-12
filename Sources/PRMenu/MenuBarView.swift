import AppKit
import Combine
import SwiftUI

struct MenuBarView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if state.showsSettings {
                SettingsView(state: state)
            } else {
                pullRequestList
            }

            Divider()

            footer
        }
        .frame(width: 420, height: 540)
        .task {
            await state.refresh()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            Task { await state.refresh() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Pull Requests")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                Task { await state.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(state.isLoading ? 360 : 0))
                    .animation(
                        state.isLoading
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: state.isLoading
                    )
            }
            .buttonStyle(.plain)
            .disabled(state.isLoading)
            .help("Refresh")

            Button {
                state.showsSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .zIndex(1)
    }

    private var pullRequestList: some View {
        VStack(spacing: 0) {
            if let errorMessage = state.errorMessage, !state.hasAnyPullRequests {
                StatusPane(
                    title: "Couldn’t load pull requests",
                    message: errorMessage,
                    systemImage: "exclamationmark.triangle"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if let errorMessage = state.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6)
                        }

                        ForEach(PullRequestSection.allCases) { section in
                            SectionView(section: section, state: state)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var footer: some View {
        HStack {
            Text(footerLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .zIndex(1)
    }

    private var footerLabel: String {
        if let lastRefreshed = state.lastRefreshed {
            let time = lastRefreshed.formatted(date: .omitted, time: .shortened)
            if state.snapshot.viewerLogin.isEmpty {
                return "Updated \(time)"
            }
            return "@\(state.snapshot.viewerLogin) · \(time)"
        }
        if state.isLoading {
            return "Loading…"
        }
        return "Not signed in"
    }
}

private struct SectionView: View {
    var section: PullRequestSection
    var state: AppState

    var body: some View {
        let pullRequests = state.snapshot.pullRequests(in: section)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(section.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(pullRequests.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)

            if pullRequests.isEmpty {
                Text(section.emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                ForEach(pullRequests) { pullRequest in
                    PullRequestRow(
                        pullRequest: pullRequest,
                        onOpen: { state.open(pullRequest) },
                        onCopy: { state.copyLink(pullRequest) }
                    )
                }
            }
        }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
