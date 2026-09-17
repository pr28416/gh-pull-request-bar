import AppKit
import SwiftUI

struct MergeGraphView: View {
    var pullRequests: [PullRequest]
    var query: String
    var onOpen: (PullRequest) -> Void

    @State private var graph = MergeGraph.empty
    @State private var positions: [String: CGPoint] = [:]
    @State private var zoom: CGFloat = 1
    @State private var zoomAtPinchStart: CGFloat = 1
    @State private var draggingID: String?
    @State private var dragStart: CGPoint = .zero
    @State private var centerGeneration = 0
    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        VStack(spacing: 0) {
            if graph.nodes.isEmpty {
                Text(query.isEmpty ? "No pull requests to show." : "No pull requests match “\(query)”.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                canvas
            }
        }
        .overlay(alignment: .bottomTrailing) {
            controls
                .padding(10)
        }
        .onAppear { rebuild(resetPositions: true) }
        .onChange(of: query) { _, _ in
            rebuild(resetPositions: true)
        }
        .onChange(of: graphSignature) { _, _ in
            rebuild(resetPositions: false)
        }
    }

    private var graphSignature: String {
        pullRequests.map { "\($0.id):\($0.baseRefName):\($0.headRefName):\($0.title)" }.joined(separator: ",")
    }

    private var canvas: some View {
        GeometryReader { geo in
            let pad = CGSize(width: geo.size.width / 2, height: geo.size.height / 2)
            let size = CGSize(
                width: canvasSize.width + pad.width * 2,
                height: canvasSize.height + pad.height * 2
            )

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    GridBackground()
                        .frame(width: size.width, height: size.height)

                    Canvas { context, _ in
                        for edge in graph.edges {
                            guard let from = positions[edge.from],
                                  let to = positions[edge.to],
                                  let fromNode = graph.node(id: edge.from),
                                  let toNode = graph.node(id: edge.to)
                            else { continue }
                            drawEdge(
                                context: context,
                                from: displayPoint(from, pad: pad),
                                to: displayPoint(to, pad: pad),
                                fromSize: CGSize(width: fromNode.width, height: fromNode.height),
                                toSize: CGSize(width: toNode.width, height: toNode.height)
                            )
                        }
                    }
                    .frame(width: size.width, height: size.height)

                    ForEach(graph.nodes) { node in
                        let point = displayPoint(positions[node.id] ?? .zero, pad: pad)
                        GraphNodeView(node: node)
                            .frame(width: node.width, height: node.height)
                            .position(point)
                            .gesture(nodeDrag(node))
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
            }
            .scrollPosition($scrollPosition)
            .background(Color(nsColor: .windowBackgroundColor))
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        zoom = min(1.8, max(0.35, zoomAtPinchStart * value.magnification))
                    }
                    .onEnded { _ in
                        zoomAtPinchStart = zoom
                    }
            )
            .task(id: centerGeneration) {
                await centerOnStaging(visible: geo.size, pad: pad)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Button {
                zoom = max(0.35, zoom - 0.1)
                zoomAtPinchStart = zoom
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom out")

            Text("\(Int((zoom * 100).rounded()))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 36)

            Button {
                zoom = min(1.8, zoom + 0.1)
                zoomAtPinchStart = zoom
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom in")

            Button("Reset") {
                rebuild(resetPositions: true)
                zoom = 1
                zoomAtPinchStart = 1
            }
            .help("Reset layout")
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var canvasSize: CGSize {
        var maxX: CGFloat = 400
        var maxY: CGFloat = 240
        for node in graph.nodes {
            guard let point = positions[node.id] else { continue }
            maxX = max(maxX, point.x + node.width / 2 + GraphLayout.padding)
            maxY = max(maxY, point.y + node.height / 2 + GraphLayout.padding)
        }
        return CGSize(width: maxX, height: maxY)
    }

    private var focusNodeID: String? {
        let staging = graph.nodes.filter { node in
            if case let .branch(_, name) = node.kind {
                return name == "staging"
            }
            return false
        }
        if staging.count == 1 {
            return staging[0].id
        }
        if staging.count > 1 {
            let incoming = Dictionary(grouping: graph.edges, by: \.to).mapValues(\.count)
            return staging.max { (incoming[$0.id] ?? 0) < (incoming[$1.id] ?? 0) }?.id
        }
        return graph.nodes.first { node in
            if case .branch = node.kind { return true }
            return false
        }?.id
    }

    private func displayPoint(_ point: CGPoint, pad: CGSize) -> CGPoint {
        CGPoint(x: point.x + pad.width, y: point.y + pad.height)
    }

    private func nodeDrag(_ node: GraphNode) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let distance = hypot(value.translation.width, value.translation.height)
                if draggingID != node.id {
                    guard distance >= 4 else { return }
                    draggingID = node.id
                    dragStart = positions[node.id] ?? .zero
                }
                positions[node.id] = CGPoint(
                    x: dragStart.x + value.translation.width / zoom,
                    y: dragStart.y + value.translation.height / zoom
                )
            }
            .onEnded { _ in
                let wasDragging = draggingID == node.id
                draggingID = nil
                if !wasDragging {
                    open(node)
                }
            }
    }

    private func open(_ node: GraphNode) {
        switch node.kind {
        case let .pullRequest(pullRequest):
            onOpen(pullRequest)
        case let .branch(repository, name):
            let path = name
                .split(separator: "/")
                .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
                .joined(separator: "/")
            if let url = URL(string: "https://github.com/\(repository)/tree/\(path)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func rebuild(resetPositions: Bool) {
        graph = MergeGraph.build(from: pullRequests, query: query)
        let laidOut = graph.layoutPositions()
        if resetPositions || positions.isEmpty {
            positions = laidOut
            centerGeneration += 1
        } else {
            var next = positions.filter { graph.nodeIDs.contains($0.key) }
            for (id, point) in laidOut where next[id] == nil {
                next[id] = point
            }
            positions = next
        }
        draggingID = nil
    }

    @MainActor
    private func centerOnStaging(visible: CGSize, pad: CGSize) async {
        guard visible.width > 10, visible.height > 10 else { return }
        guard let id = focusNodeID, let staging = positions[id] else { return }
        try? await Task.sleep(for: .milliseconds(30))
        let point = displayPoint(staging, pad: pad)
        scrollPosition.scrollTo(
            x: max(0, point.x * zoom - visible.width / 2),
            y: max(0, point.y * zoom - visible.height / 2)
        )
    }

    private func drawEdge(
        context: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        fromSize: CGSize,
        toSize: CGSize
    ) {
        let start = CGPoint(x: from.x + fromSize.width / 2, y: from.y)
        let end = CGPoint(x: to.x - toSize.width / 2, y: to.y)
        let delta = end.x - start.x
        let control1 = CGPoint(x: start.x + delta * 0.45, y: start.y)
        let control2 = CGPoint(x: end.x - delta * 0.45, y: end.y)

        var stem = Path()
        stem.move(to: start)
        stem.addCurve(to: end, control1: control1, control2: control2)

        context.stroke(
            stem,
            with: .color(.secondary.opacity(0.65)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )

        let angle = atan2(end.y - control2.y, end.x - control2.x)
        let arrow: CGFloat = 7
        var head = Path()
        head.move(to: end)
        head.addLine(to: CGPoint(
            x: end.x - arrow * cos(angle - .pi / 6),
            y: end.y - arrow * sin(angle - .pi / 6)
        ))
        head.move(to: end)
        head.addLine(to: CGPoint(
            x: end.x - arrow * cos(angle + .pi / 6),
            y: end.y - arrow * sin(angle + .pi / 6)
        ))
        context.stroke(
            head,
            with: .color(.secondary.opacity(0.8)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
    }
}

private struct GraphNodeView: View {
    var node: GraphNode

    var body: some View {
        switch node.kind {
        case let .pullRequest(pullRequest):
            HStack(spacing: 8) {
                MergeStatusIcon(status: pullRequest.displayStatus)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pullRequest.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text("#\(pullRequest.number)  →  \(pullRequest.baseRefName)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }

        case let .branch(_, name):
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 11, weight: .semibold))
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(name == "staging" ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                name == "staging"
                    ? Color(red: 63 / 255, green: 185 / 255, blue: 80 / 255).opacity(0.2)
                    : Color.primary.opacity(0.06),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        name == "staging"
                            ? Color(red: 63 / 255, green: 185 / 255, blue: 80 / 255).opacity(0.55)
                            : Color.primary.opacity(0.12),
                        lineWidth: 1
                    )
            }
        }
    }
}

private struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(.primary.opacity(0.05)), lineWidth: 1)
        }
    }
}
