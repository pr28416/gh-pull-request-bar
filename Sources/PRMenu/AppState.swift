import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var snapshot = PullRequestSnapshot(
        viewerLogin: "",
        created: [],
        assigned: [],
        reviewRequested: []
    )
    var isLoading = false
    var errorMessage: String?
    var lastRefreshed: Date?
    var tokenSource: TokenSource = .missing
    var showsSettings = false

    var uniqueCount: Int { snapshot.uniqueCount }

    var hasAnyPullRequests: Bool {
        uniqueCount > 0
    }

    private var inFlightRefresh: Task<Void, Never>?

    func refresh() async {
        if let inFlightRefresh {
            await inFlightRefresh.value
            return
        }

        let task = Task { await performRefresh() }
        inFlightRefresh = task
        await task.value
        inFlightRefresh = nil
    }

    private func performRefresh() async {
        guard let resolved = TokenStore.resolve() else {
            tokenSource = .missing
            errorMessage = GitHubClientError.missingToken.localizedDescription
            showsSettings = true
            return
        }

        tokenSource = resolved.source
        isLoading = true
        if tokenSource != .missing {
            errorMessage = nil
        }

        defer { isLoading = false }

        do {
            snapshot = try await GitHubClient.fetch(token: resolved.token)
            lastRefreshed = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
