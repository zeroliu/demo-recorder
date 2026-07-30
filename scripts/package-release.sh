#!/bin/zsh
set -euo pipefail

project_dir=${0:a:h:h}
dist_dir="$project_dir/dist"
archive="$project_dir/demo-recorder-macos-universal.tar.gz"

cd "$project_dir"
swift build -c release --arch arm64 --arch x86_64

mkdir -p "$dist_dir"
cp .build/apple/Products/Release/DemoRecorder "$dist_dir/demo-recorder"
tar -czf "$archive" -C "$dist_dir" demo-recorder
shasum -a 256 "$archive" |
  sed 's#  .*/#  #' > "$archive.sha256"

file "$dist_dir/demo-recorder"
shasum -a 256 -c "$archive.sha256"
