import Foundation

enum SnapshotCache {
    private static let version = 5

    static func load() -> (snapshot: PullRequestSnapshot, lastRefreshed: Date)? {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            guard payload.version == version else { return nil }
            return (payload.snapshot, payload.lastRefreshed)
        } catch {
            return nil
        }
    }

    static func save(snapshot: PullRequestSnapshot, lastRefreshed: Date) {
        guard let url = fileURL else { return }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let payload = Payload(
                version: version,
                lastRefreshed: lastRefreshed,
                snapshot: snapshot
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PR Menu", isDirectory: true)
            .appendingPathComponent("snapshot.json")
    }
}

private struct Payload: Codable {
    var version: Int
    var lastRefreshed: Date
    var snapshot: PullRequestSnapshot
}
