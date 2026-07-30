#!/bin/zsh
set -euo pipefail

if [[ $# -ne 3 || "$3" != "--confirmed-public" ]]; then
  print -u2 "usage: upload-r2.sh FILE OBJECT_KEY --confirmed-public"
  exit 2
fi

video=$1
key=$2
[[ -f "$video" ]] || { print -u2 "video not found: $video"; exit 1; }
[[ "$key" =~ ^[A-Za-z0-9._/-]+$ && "$key" != /* && "$key" != *..* ]] || {
  print -u2 "object key must be a safe relative path"
  exit 1
}
for dependency in wrangler curl shasum ffprobe; do
  command -v "$dependency" >/dev/null || {
    print -u2 "missing dependency: $dependency"
    exit 1
  }
done
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
  -of default=nw=1 "$video" >/dev/null

account_id=${SCREEN_RECORDING_CF_ACCOUNT_ID:-07d4d534b0c386f2545619e6efb5e6f0}
bucket=${SCREEN_RECORDING_R2_BUCKET:-zeroliu-pr-demos}
public_base=${SCREEN_RECORDING_R2_PUBLIC_BASE:-https://pub-d0d5db63b5e446cc848d32b65229d622.r2.dev}
url="${public_base%/}/$key"

CLOUDFLARE_ACCOUNT_ID="$account_id" wrangler r2 object put "$bucket/$key" \
  --remote \
  --file "$video" \
  --content-type video/mp4 \
  --cache-control public,max-age=3600 \
  --force >&2

download=$(mktemp "${TMPDIR:-/tmp}/screen-recording-upload.XXXXXX.mp4")
trap 'rm -f "$download"' EXIT
curl -fsSL "$url" -o "$download"
[[ "$(shasum -a 256 "$video" | awk '{print $1}')" == \
  "$(shasum -a 256 "$download" | awk '{print $1}')" ]] || {
  print -u2 "public object does not match the uploaded video"
  exit 1
}
print -r -- "$url"
