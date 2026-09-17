import Foundation

struct PullRequest: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let number: Int
    let title: String
    let url: String
    let isDraft: Bool
    let updatedAt: Date
    let repository: String
    let author: String
    let baseRefName: String
    let headRefName: String
    let additions: Int
    let deletions: Int
    let checks: CheckSummary
    let mergeStatus: MergeStatus

    var hasDiff: Bool { additions > 0 || deletions > 0 }

    var displayStatus: MergeStatus {
        if isDraft, mergeStatus == .open {
            return .draft
        }
        return mergeStatus
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }

        if title.localizedStandardContains(needle) { return true }
        if repository.localizedStandardContains(needle) { return true }
        if author.localizedStandardContains(needle) { return true }
        if baseRefName.localizedStandardContains(needle) { return true }
        if headRefName.localizedStandardContains(needle) { return true }
        if String(number).localizedStandardContains(needle) { return true }
        if "#\(number)".localizedStandardContains(needle) { return true }
        return false
    }
}

enum MergeStatus: String, Codable, Sendable {
    case open
    case draft
    case closed
    case merged
    case mergeQueue

    var accessibilityLabel: String {
        switch self {
        case .open:
            return "Open"
        case .draft:
            return "Draft"
        case .closed:
            return "Closed"
        case .merged:
            return "Merged"
        case .mergeQueue:
            return "On merge queue"
        }
    }
}

struct CheckSummary: Hashable, Sendable, Codable {
    var passed: Int
    var failed: Int
    var pending: Int

    var total: Int { passed + failed + pending }
    var hasChecks: Bool { total > 0 }
}

enum PullRequestSection: String, CaseIterable, Identifiable, Sendable {
    case created = "Created"
    case assigned = "Assigned"
    case reviewRequested = "Review requested"

    var id: String { rawValue }

    var emptyText: String {
        switch self {
        case .created:
            return "No open pull requests you created."
        case .assigned:
            return "No open pull requests assigned to you."
        case .reviewRequested:
            return "No pull requests waiting for your review."
        }
    }

    var hidesWhenEmpty: Bool {
        switch self {
        case .created:
            return false
        case .assigned, .reviewRequested:
            return true
        }
    }
}

struct PullRequestSnapshot: Sendable, Codable {
    var viewerLogin: String
    var viewerName: String?
    var viewerAvatarURL: String?
    var created: [PullRequest]
    var assigned: [PullRequest]
    var reviewRequested: [PullRequest]

    static let empty = PullRequestSnapshot(
        viewerLogin: "",
        viewerName: nil,
        viewerAvatarURL: nil,
        created: [],
        assigned: [],
        reviewRequested: []
    )

    var viewerDisplayName: String {
        if let viewerName, !viewerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewerName
        }
        return viewerLogin
    }

    var hasAnyPullRequests: Bool { uniqueCount > 0 }

    func pullRequests(in section: PullRequestSection) -> [PullRequest] {
        switch section {
        case .created:
            return created
        case .assigned:
            return assigned
        case .reviewRequested:
            return reviewRequested
        }
    }

    var uniqueCount: Int {
        Set(created.map(\.id) + assigned.map(\.id) + reviewRequested.map(\.id)).count
    }

    var uniquePullRequests: [PullRequest] {
        var seen = Set<String>()
        var ordered: [PullRequest] = []
        for pullRequest in created + assigned + reviewRequested {
            if seen.insert(pullRequest.id).inserted {
                ordered.append(pullRequest)
            }
        }
        return ordered
    }

    var openAuthoredCount: Int {
        created.filter { pullRequest in
            switch pullRequest.mergeStatus {
            case .open, .draft, .mergeQueue:
                return true
            case .closed, .merged:
                return false
            }
        }.count
    }
}

enum TokenSource: Equatable, Sendable {
    case keychain
    case githubCLI
    case missing
}

enum GitHubClientError: LocalizedError {
    case missingToken
    case httpStatus(Int, String)
    case graphQL([String])
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Add a GitHub token in Settings, or sign in with GitHub CLI (`gh auth login`)."
        case .httpStatus(let code, let body):
            if code == 401 {
                return "GitHub rejected the token. Update it in Settings or run `gh auth login`."
            }
            return "GitHub returned \(code): \(body)"
        case .graphQL(let messages):
            return messages.joined(separator: "\n")
        case .decoding(let error):
            return "Could not read GitHub’s response: \(error.localizedDescription)"
        }
    }
}
