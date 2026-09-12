import Foundation

enum GitHubClient {
    private static let endpoint = URL(string: "https://api.github.com/graphql")!

    private static let query = """
    query MenuBarPullRequests {
      viewer { login }
      created: search(query: "is:open is:pr archived:false author:@me sort:updated-desc", type: ISSUE, first: 40) {
        ...PRSearch
      }
      assigned: search(query: "is:open is:pr archived:false assignee:@me sort:updated-desc", type: ISSUE, first: 40) {
        ...PRSearch
      }
      reviewRequested: search(query: "is:open is:pr archived:false review-requested:@me sort:updated-desc", type: ISSUE, first: 40) {
        ...PRSearch
      }
    }

    fragment PRSearch on SearchResultItemConnection {
      nodes {
        ... on PullRequest {
          id
          number
          title
          url
          isDraft
          updatedAt
          author { login }
          repository { nameWithOwner }
          commits(last: 1) {
            nodes {
              commit {
                statusCheckRollup {
                  contexts {
                    checkRunCount
                    checkRunCountsByState { state count }
                    statusContextCount
                    statusContextCountsByState { state count }
                  }
                }
              }
            }
          }
        }
      }
    }
    """

    static func fetch(token: String) async throws -> PullRequestSnapshot {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PR-Menu", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GitHubClientError.httpStatus(status, String(body.prefix(280)))
        }

        let decoded: GraphQLResponse
        do {
            decoded = try JSONDecoder.github.decode(GraphQLResponse.self, from: data)
        } catch {
            throw GitHubClientError.decoding(error)
        }

        if let messages = decoded.errors?.map(\.message), !messages.isEmpty, decoded.data == nil {
            throw GitHubClientError.graphQL(messages)
        }

        guard let payload = decoded.data else {
            throw GitHubClientError.graphQL(["GitHub returned an empty response."])
        }

        return PullRequestSnapshot(
            viewerLogin: payload.viewer.login,
            created: payload.created.pullRequests,
            assigned: payload.assigned.pullRequests,
            reviewRequested: payload.reviewRequested.pullRequests
        )
    }
}

private struct GraphQLResponse: Decodable {
    var data: GraphQLData?
    var errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    var message: String
}

private struct GraphQLData: Decodable {
    var viewer: Viewer
    var created: SearchConnection
    var assigned: SearchConnection
    var reviewRequested: SearchConnection
}

private struct Viewer: Decodable {
    var login: String
}

private struct SearchConnection: Decodable {
    var nodes: [PullRequestNode?]

    var pullRequests: [PullRequest] {
        nodes.compactMap { $0?.asPullRequest() }
    }
}

private struct PullRequestNode: Decodable {
    var id: String
    var number: Int
    var title: String
    var url: String
    var isDraft: Bool?
    var updatedAt: Date
    var author: Actor?
    var repository: Repository
    var commits: CommitConnection?

    func asPullRequest() -> PullRequest {
        PullRequest(
            id: id,
            number: number,
            title: title,
            url: url,
            isDraft: isDraft ?? false,
            updatedAt: updatedAt,
            repository: repository.nameWithOwner,
            author: author?.login ?? "unknown",
            checks: commits?.summary ?? CheckSummary(passed: 0, failed: 0, pending: 0)
        )
    }
}

private struct Actor: Decodable {
    var login: String
}

private struct Repository: Decodable {
    var nameWithOwner: String
}

private struct CommitConnection: Decodable {
    var nodes: [CommitNode?]

    var summary: CheckSummary {
        nodes.compactMap { $0 }.first?.commit.statusCheckRollup?.contexts.summary
            ?? CheckSummary(passed: 0, failed: 0, pending: 0)
    }
}

private struct CommitNode: Decodable {
    var commit: Commit
}

private struct Commit: Decodable {
    var statusCheckRollup: StatusCheckRollup?
}

private struct StatusCheckRollup: Decodable {
    var contexts: CheckContexts
}

private struct CheckContexts: Decodable {
    var checkRunCountsByState: [StateCount]?
    var statusContextCountsByState: [StateCount]?

    var summary: CheckSummary {
        var passed = 0
        var failed = 0
        var pending = 0

        for item in checkRunCountsByState ?? [] {
            switch CheckBucket.forCheckRun(item.state) {
            case .passed:
                passed += item.count
            case .failed:
                failed += item.count
            case .pending:
                pending += item.count
            case .ignored:
                break
            }
        }

        for item in statusContextCountsByState ?? [] {
            switch CheckBucket.forStatusContext(item.state) {
            case .passed:
                passed += item.count
            case .failed:
                failed += item.count
            case .pending:
                pending += item.count
            case .ignored:
                break
            }
        }

        return CheckSummary(passed: passed, failed: failed, pending: pending)
    }
}

private struct StateCount: Decodable {
    var state: String
    var count: Int
}

private enum CheckBucket {
    case passed
    case failed
    case pending
    case ignored

    static func forCheckRun(_ state: String) -> CheckBucket {
        switch state {
        case "SUCCESS", "NEUTRAL":
            return .passed
        case "FAILURE", "ACTION_REQUIRED", "CANCELLED", "TIMED_OUT", "STARTUP_FAILURE":
            return .failed
        case "SKIPPED", "STALE":
            return .ignored
        case "IN_PROGRESS", "PENDING", "QUEUED", "WAITING", "COMPLETED":
            return .pending
        default:
            return .pending
        }
    }

    static func forStatusContext(_ state: String) -> CheckBucket {
        switch state {
        case "SUCCESS":
            return .passed
        case "FAILURE", "ERROR":
            return .failed
        case "PENDING", "EXPECTED":
            return .pending
        default:
            return .pending
        }
    }
}

private extension JSONDecoder {
    static let github: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseGitHubDate(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date: \(raw)"
            )
        }
        return decoder
    }()
}

private func parseGitHubDate(_ raw: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return fractional.date(from: raw) ?? standard.date(from: raw)
}
