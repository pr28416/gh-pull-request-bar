import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var snapshot = PullRequestSnapshot.empty
    var isLoading = false
    var errorMessage: String?
    var lastRefreshed: Date?
    var tokenSource: TokenSource = .missing
    var showsSettings = false

    var uniqueCount: Int { snapshot.uniqueCount }
    var openAuthoredCount: Int { snapshot.openAuthoredCount }

    var hasAnyPullRequests: Bool {
        snapshot.hasAnyPullRequests
    }

    private var didStart = false
    private var inFlightRefresh: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private var isPanelOpen = false

    private init() {
        if let cached = SnapshotCache.load() {
            snapshot = cached.snapshot
            lastRefreshed = cached.lastRefreshed
        }
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await AppState.shared.refresh(quiet: true)
            }
        }

        pollingTask = Task { [weak self] in
            await self?.refresh(quiet: AppState.shared.hasAnyPullRequests)
            while !Task.isCancelled {
                await self?.waitForNextPoll()
                guard !Task.isCancelled else { return }
                await self?.refresh(quiet: true)
            }
        }
    }

    func setPanelVisible(_ visible: Bool) {
        let opened = visible && !isPanelOpen
        isPanelOpen = visible
        if opened {
            Task { await refresh(quiet: true) }
        }
    }

    func refresh(quiet: Bool = false) async {
        if let inFlightRefresh {
            await inFlightRefresh.value
            return
        }

        let task = Task { await performRefresh(quiet: quiet) }
        inFlightRefresh = task
        await task.value
        inFlightRefresh = nil
    }

    func refreshIfStale() async {
        if let lastRefreshed, Date().timeIntervalSince(lastRefreshed) < 20 {
            return
        }
        await refresh(quiet: hasAnyPullRequests)
    }

    private func waitForNextPoll() async {
        let started = Date()
        while !Task.isCancelled {
            let interval = isPanelOpen ? 8.0 : 60.0
            if Date().timeIntervalSince(started) >= interval {
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func performRefresh(quiet: Bool) async {
        let showSpinner = !(quiet && hasAnyPullRequests)
        if showSpinner {
            isLoading = true
        }

        defer { isLoading = false }

        let resolved = await Task.detached {
            TokenStore.resolve()
        }.value

        guard let resolved else {
            tokenSource = .missing
            errorMessage = GitHubClientError.missingToken.localizedDescription
            if !hasAnyPullRequests {
                showsSettings = true
            }
            return
        }

        tokenSource = resolved.source

        do {
            let next = try await GitHubClient.fetch(token: resolved.token)
            snapshot = next
            lastRefreshed = Date()
            errorMessage = nil
            SnapshotCache.save(snapshot: next, lastRefreshed: lastRefreshed ?? Date())
        } catch {
            if !hasAnyPullRequests {
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveToken(_ token: String) throws {
        try TokenStore.save(token)
        showsSettings = false
    }

    func clearSavedToken() {
        TokenStore.delete()
        tokenSource = TokenStore.resolve()?.source ?? .missing
    }

    func open(_ pullRequest: PullRequest) {
        guard let url = URL(string: pullRequest.url) else { return }
        NSWorkspace.shared.open(url)
    }

    func copyLink(_ pullRequest: PullRequest) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pullRequest.url, forType: .string)
    }
}
