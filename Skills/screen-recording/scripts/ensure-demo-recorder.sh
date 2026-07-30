#!/bin/zsh
set -euo pipefail

if [[ -n "${DEMO_RECORDER_BIN:-}" && -x "$DEMO_RECORDER_BIN" ]]; then
  print -r -- "$DEMO_RECORDER_BIN"
  exit 0
fi

if installed=$(command -v demo-recorder 2>/dev/null); then
  print -r -- "$installed"
  exit 0
fi

install_root=${SCREEN_RECORDING_HOME:-"$HOME/.local/share/screen-recording"}
binary="$install_root/bin/demo-recorder"
if [[ -x "$binary" && "${SCREEN_RECORDING_REFRESH:-0}" != "1" ]]; then
  print -r -- "$binary"
  exit 0
fi

[[ "$(uname -s)" == "Darwin" ]] || {
  print -u2 "demo-recorder requires macOS"
  exit 1
}
for dependency in curl shasum tar; do
  command -v "$dependency" >/dev/null || {
    print -u2 "missing dependency: $dependency"
    exit 1
  }
done

release_base=https://github.com/zeroliu/demo-recorder/releases/latest/download
archive_name=demo-recorder-macos-universal.tar.gz
download_dir=$(mktemp -d "${TMPDIR:-/tmp}/demo-recorder.XXXXXX")
trap 'rm -rf "$download_dir"' EXIT

curl -fsSL "$release_base/$archive_name" -o "$download_dir/$archive_name"
curl -fsSL "$release_base/$archive_name.sha256" -o "$download_dir/$archive_name.sha256"
(cd "$download_dir" && shasum -a 256 -c "$archive_name.sha256") >&2
tar -xzf "$download_dir/$archive_name" -C "$download_dir"

mkdir -p "$install_root/bin"
install -m 755 "$download_dir/demo-recorder" "$binary"
print -r -- "$binary"
