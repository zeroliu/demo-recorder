#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  print -u2 "usage: prepend-pr-video.sh PR_URL VIDEO_URL [LABEL]"
  exit 2
fi

pr=$1
video_url=$2
label=${3:-Watch the walkthrough}
[[ "$video_url" == https://* ]] || {
  print -u2 "video URL must use HTTPS"
  exit 1
}
command -v gh >/dev/null || { print -u2 "missing dependency: gh"; exit 1; }

body=$(gh pr view "$pr" --json body --jq .body)
if [[ "$body" == *"$video_url"* ]]; then
  print -r -- "$pr already contains $video_url"
  exit 0
fi

body_file=$(mktemp "${TMPDIR:-/tmp}/screen-recording-pr.XXXXXX.md")
trap 'rm -f "$body_file"' EXIT
{
  print "## Demo"
  print
  print "**$label:** [Watch video]($video_url)"
  print
  print -r -- "$body"
} > "$body_file"
gh pr edit "$pr" --body-file "$body_file"
