#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

swift build -c release

bin_path="$(swift build -c release --show-bin-path)"
executable="$bin_path/PRMenu"

if [[ ! -x "$executable" ]]; then
  echo "Build succeeded but $executable is missing." >&2
  exit 1
fi

app="$root/dist/PR Menu.app"
contents="$app/Contents"
macos="$contents/MacOS"

rm -rf "$app"
mkdir -p "$macos"

cp "$executable" "$macos/PRMenu"
cp "$root/Resources/Info.plist" "$contents/Info.plist"
printf 'APPL????' > "$contents/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - --identifier com.pranavramesh.prmenu "$app" >/dev/null
fi

echo "Built $app"
