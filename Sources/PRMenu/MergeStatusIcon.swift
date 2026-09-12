import AppKit
import SwiftUI

struct MergeStatusIcon: View {
    var status: MergeStatus

    var body: some View {
        Image(nsImage: status.templateImage)
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .frame(width: 14, height: 14)
            .foregroundStyle(status.color)
            .accessibilityHidden(true)
    }
}

private extension MergeStatus {
    var color: Color {
        switch self {
        case .open:
            return Color(light: NSColor(srgbRed: 26 / 255, green: 127 / 255, blue: 55 / 255, alpha: 1),
                         dark: NSColor(srgbRed: 63 / 255, green: 185 / 255, blue: 80 / 255, alpha: 1))
        case .draft:
            return Color(light: NSColor(srgbRed: 89 / 255, green: 99 / 255, blue: 110 / 255, alpha: 1),
                         dark: NSColor(srgbRed: 139 / 255, green: 148 / 255, blue: 158 / 255, alpha: 1))
        case .closed:
            return Color(light: NSColor(srgbRed: 209 / 255, green: 36 / 255, blue: 47 / 255, alpha: 1),
                         dark: NSColor(srgbRed: 248 / 255, green: 81 / 255, blue: 73 / 255, alpha: 1))
        case .merged:
            return Color(light: NSColor(srgbRed: 130 / 255, green: 80 / 255, blue: 223 / 255, alpha: 1),
                         dark: NSColor(srgbRed: 163 / 255, green: 113 / 255, blue: 247 / 255, alpha: 1))
        case .mergeQueue:
            return Color(light: NSColor(srgbRed: 154 / 255, green: 103 / 255, blue: 0 / 255, alpha: 1),
                         dark: NSColor(srgbRed: 210 / 255, green: 167 / 255, blue: 44 / 255, alpha: 1))
        }
    }

    var templateImage: NSImage {
        switch self {
        case .open, .draft:
            return Self.pullRequestImage
        case .closed:
            return Self.closedImage
        case .merged:
            return Self.mergedImage
        case .mergeQueue:
            return Self.mergeQueueImage
        }
    }

    private static let pullRequestImage = image("M1.5 3.25a2.25 2.25 0 1 1 3 2.122v5.256a2.251 2.251 0 1 1-1.5 0V5.372A2.25 2.25 0 0 1 1.5 3.25Zm5.677-.177L9.573.677A.25.25 0 0 1 10 .854V2.5h1A2.5 2.5 0 0 1 13.5 5v5.628a2.251 2.251 0 1 1-1.5 0V5a1 1 0 0 0-1-1h-1v1.646a.25.25 0 0 1-.427.177L7.177 3.427a.25.25 0 0 1 0-.354ZM3.75 2.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm0 9.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm8.25.75a.75.75 0 1 0 1.5 0 .75.75 0 0 0-1.5 0Z")
    private static let closedImage = image("M3.25 1A2.25 2.25 0 0 1 4 5.372v5.256a2.251 2.251 0 1 1-1.5 0V5.372A2.251 2.251 0 0 1 3.25 1Zm9.5 5.5a.75.75 0 0 1 .75.75v3.378a2.251 2.251 0 1 1-1.5 0V7.25a.75.75 0 0 1 .75-.75Zm-2.03-5.273a.75.75 0 0 1 1.06 0l.97.97.97-.97a.748.748 0 0 1 1.265.332.75.75 0 0 1-.205.729l-.97.97.97.97a.751.751 0 0 1-.018 1.042.751.751 0 0 1-1.042.018l-.97-.97-.97.97a.749.749 0 0 1-1.275-.326.749.749 0 0 1 .215-.734l.97-.97-.97-.97a.75.75 0 0 1 0-1.06ZM2.5 3.25a.75.75 0 1 0 1.5 0 .75.75 0 0 0-1.5 0ZM3.25 12a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm9.5 0a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Z")
    private static let mergedImage = image("M5.45 5.154A4.25 4.25 0 0 0 9.25 7.5h1.378a2.251 2.251 0 1 1 0 1.5H9.25A5.734 5.734 0 0 1 5 7.123v3.505a2.25 2.25 0 1 1-1.5 0V5.372a2.25 2.25 0 1 1 1.95-.218ZM4.25 13.5a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Zm8.5-4.5a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5ZM5 3.25a.75.75 0 1 0 0 .005V3.25Z")
    private static let mergeQueueImage = image("M3.75 4.5a1.25 1.25 0 1 0 0-2.5 1.25 1.25 0 0 0 0 2.5ZM3 7.75a.75.75 0 0 1 1.5 0v2.878a2.251 2.251 0 1 1-1.5 0Zm.75 5.75a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Zm5-7.75a1.25 1.25 0 1 1-2.5 0 1.25 1.25 0 0 1 2.5 0Zm5.75 2.5a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-1.5 0a.75.75 0 1 0-1.5 0 .75.75 0 0 0 1.5 0Z")

    static func image(_ path: String) -> NSImage {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path fill="black" d="\(path)"/></svg>
        """
        let image = NSImage(data: Data(svg.utf8)) ?? NSImage(size: NSSize(width: 16, height: 16))
        image.isTemplate = true
        return image
    }
}

private extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        )
    }
}
