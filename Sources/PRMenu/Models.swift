import Foundation

struct PullRequest: Identifiable, Hashable, Sendable {
    let id: String
    let number: Int
    let title: String
    let url: String
    let isDraft: Bool
    let updatedAt: Date
    let repository: String
    let author: String
    let checks: CheckSummary
}

struct CheckSummary: Hashable, Sendable {
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
}

struct PullRequestSnapshot: Sendable {
    var viewerLogin: String
    var created: [PullRequest]
    var assigned: [PullRequest]
    var reviewRequested: [PullRequest]

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
