#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
svg="$root/Resources/AppIcon.svg"
iconset="$root/Resources/AppIcon.iconset"
icns="$root/Resources/AppIcon.icns"

if [[ ! -f "$svg" ]]; then
  echo "Missing $svg" >&2
  exit 1
fi

rm -rf "$iconset"
mkdir -p "$iconset"

swift - "$svg" "$iconset" <<'SWIFT'
import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fputs("usage: generate-icon.swift <svg> <iconset>\n", stderr)
    exit(1)
}

let svgURL = URL(fileURLWithPath: arguments[1])
let iconsetURL = URL(fileURLWithPath: arguments[2])

guard let source = NSImage(contentsOf: svgURL) else {
    fputs("Could not load \(svgURL.path)\n", stderr)
    exit(1)
}

let slices: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for slice in slices {
    let pixelSize = slice.size
    let canvas = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    canvas.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    canvas.unlockFocus()

    guard let tiff = canvas.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("Could not encode \(slice.name)\n", stderr)
        exit(1)
    }

    try png.write(to: iconsetURL.appendingPathComponent(slice.name))
}
SWIFT

iconutil --convert icns --output "$icns" "$iconset"
rm -rf "$iconset"
echo "Wrote $icns"
