import CoreGraphics
import Foundation

struct MergeGraph {
    var nodes: [GraphNode]
    var edges: [GraphEdge]

    static let empty = MergeGraph(nodes: [], edges: [])

    var nodeIDs: Set<String> { Set(nodes.map(\.id)) }

    func node(id: String) -> GraphNode? {
        nodes.first { $0.id == id }
    }

    func layoutPositions() -> [String: CGPoint] {
        guard !nodes.isEmpty else { return [:] }

        var children: [String: [String]] = [:]
        var outgoing = Set<String>()
        for edge in edges {
            children[edge.to, default: []].append(edge.from)
            outgoing.insert(edge.from)
        }

        for id in children.keys {
            children[id]?.sort { lhs, rhs in
                switch (node(id: lhs)?.kind, node(id: rhs)?.kind) {
                case let (.pullRequest(a), .pullRequest(b)):
                    return a.updatedAt > b.updatedAt
                case let (.branch(_, a), .branch(_, b)):
                    return a.localizedStandardCompare(b) == .orderedAscending
                case (.pullRequest, _):
                    return true
                default:
                    return false
                }
            }
        }

        let roots = nodes.map(\.id).filter { !outgoing.contains($0) }
            .sorted { lhs, rhs in
                rank(lhs) < rank(rhs)
            }

        var depth: [String: Int] = [:]
        var visiting = Set<String>()
        func measureDepth(_ id: String, current: Int) {
            guard visiting.insert(id).inserted else { return }
            depth[id] = max(depth[id] ?? 0, current)
            for child in children[id] ?? [] {
                measureDepth(child, current: current + 1)
            }
            visiting.remove(id)
        }
        for root in roots {
            measureDepth(root, current: 0)
        }
        let maxDepth = depth.values.max() ?? 0

        var positions: [String: CGPoint] = [:]
        var top = GraphLayout.padding
        for root in roots {
            top += place(
                root,
                top: top,
                originX: GraphLayout.padding,
                maxDepth: maxDepth,
                depth: depth,
                children: children,
                positions: &positions
            )
            top += GraphLayout.forestGap
        }

        return positions
    }

    static func build(from pullRequests: [PullRequest], query: String = "") -> MergeGraph {
        let unique = uniqued(pullRequests)
        guard !unique.isEmpty else { return .empty }

        var headIndex: [String: PullRequest] = [:]
        for pullRequest in unique {
            guard !pullRequest.headRefName.isEmpty else { continue }
            headIndex[refKey(repository: pullRequest.repository, ref: pullRequest.headRefName)] = pullRequest
        }

        var parent: [String: String] = [:]
        var branchNodes: [String: GraphNode] = [:]

        for pullRequest in unique {
            let base = pullRequest.baseRefName.isEmpty ? "staging" : pullRequest.baseRefName
            let key = refKey(repository: pullRequest.repository, ref: base)
            if let target = headIndex[key], target.id != pullRequest.id {
                parent[pullRequest.id] = target.id
            } else {
                let branchID = GraphNode.branchID(repository: pullRequest.repository, name: base)
                if branchNodes[branchID] == nil {
                    branchNodes[branchID] = GraphNode.branch(
                        repository: pullRequest.repository,
                        name: base,
                        emphasizeStaging: base == "staging"
                    )
                }
                parent[pullRequest.id] = branchID
            }
        }

        let matched = unique.filter { $0.matches(query) }
        var keep = Set(matched.map(\.id))
        for pullRequest in matched {
            var current = parent[pullRequest.id]
            while let id = current {
                keep.insert(id)
                current = parent[id]
            }
        }

        let visiblePRs = unique.filter { keep.contains($0.id) }
        let nodes = visiblePRs.map(GraphNode.pullRequest)
            + branchNodes.values.filter { keep.contains($0.id) }
        let edges = visiblePRs.compactMap { pullRequest -> GraphEdge? in
            guard let target = parent[pullRequest.id], keep.contains(target) else { return nil }
            return GraphEdge(from: pullRequest.id, to: target)
        }

        return MergeGraph(nodes: nodes, edges: edges)
    }

    private func rank(_ id: String) -> (Int, String, String) {
        switch node(id: id)?.kind {
        case let .branch(repository, name):
            let staging = name == "staging" ? 0 : 1
            return (staging, repository, name)
        case let .pullRequest(pullRequest):
            return (2, pullRequest.repository, String(pullRequest.number))
        case nil:
            return (3, "", id)
        }
    }

    private func place(
        _ id: String,
        top: CGFloat,
        originX: CGFloat,
        maxDepth: Int,
        depth: [String: Int],
        children: [String: [String]],
        positions: inout [String: CGPoint]
    ) -> CGFloat {
        let node = node(id: id)
        let size = node.map { CGSize(width: $0.width, height: $0.height) } ?? GraphLayout.prSize
        let column = CGFloat(maxDepth - (depth[id] ?? 0))
        let x = originX + column * GraphLayout.columnWidth + size.width / 2
        let kids = children[id] ?? []

        if kids.isEmpty {
            positions[id] = CGPoint(x: x, y: top + size.height / 2)
            return size.height + GraphLayout.vGap
        }

        var y = top
        for child in kids {
            y += place(
                child,
                top: y,
                originX: originX,
                maxDepth: maxDepth,
                depth: depth,
                children: children,
                positions: &positions
            )
        }

        let occupied = y - top
        positions[id] = CGPoint(x: x, y: top + occupied / 2)
        return max(occupied, size.height + GraphLayout.vGap)
    }

    private static func uniqued(_ pullRequests: [PullRequest]) -> [PullRequest] {
        var seen = Set<String>()
        var ordered: [PullRequest] = []
        for pullRequest in pullRequests {
            if seen.insert(pullRequest.id).inserted {
                ordered.append(pullRequest)
            }
        }
        return ordered
    }

    private static func refKey(repository: String, ref: String) -> String {
        "\(repository)#\(ref)"
    }
}

struct GraphNode: Identifiable, Equatable {
    enum Kind: Equatable {
        case pullRequest(PullRequest)
        case branch(repository: String, name: String)
    }

    var id: String
    var kind: Kind
    var width: CGFloat
    var height: CGFloat

    var pullRequest: PullRequest? {
        if case let .pullRequest(pullRequest) = kind {
            return pullRequest
        }
        return nil
    }

    static func pullRequest(_ pullRequest: PullRequest) -> GraphNode {
        GraphNode(
            id: pullRequest.id,
            kind: .pullRequest(pullRequest),
            width: GraphLayout.prSize.width,
            height: GraphLayout.prSize.height
        )
    }

    static func branch(repository: String, name: String, emphasizeStaging: Bool) -> GraphNode {
        GraphNode(
            id: branchID(repository: repository, name: name),
            kind: .branch(repository: repository, name: name),
            width: emphasizeStaging ? 168 : 156,
            height: GraphLayout.branchSize.height
        )
    }

    static func branchID(repository: String, name: String) -> String {
        "branch:\(repository):\(name)"
    }
}

struct GraphEdge: Identifiable, Equatable, Hashable {
    var from: String
    var to: String
    var id: String { "\(from)->\(to)" }
}

enum GraphLayout {
    static let prSize = CGSize(width: 220, height: 58)
    static let branchSize = CGSize(width: 156, height: 34)
    static let columnWidth: CGFloat = 252
    static let vGap: CGFloat = 18
    static let forestGap: CGFloat = 48
    static let padding: CGFloat = 28
}
