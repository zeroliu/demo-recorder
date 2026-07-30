---
name: screen-recording
description: Record, edit, inspect, compress, and publicly share polished macOS product walkthrough videos. Use for bug reproductions with before-and-after builds, feature demonstrations, click-focused UI walkthroughs, demo videos for GitHub pull requests, or requests to upload a screen recording to Cloudflare R2.
---

# Screen Recording

Produce one concise video that explains the behavior, not merely the clicks.
Use Demo Recorder for exact-window capture and the bundled helpers for
composition, inspection, compression, R2 upload, and optional PR attachment.

## 1. Bootstrap

Resolve the skill directory from this `SKILL.md`; never assume the current
working directory. Run:

```bash
DEMO_RECORDER=$("<skill-dir>/scripts/ensure-demo-recorder.sh")
```

The helper checks configured and installed binaries first. If none exists, it
downloads and checksum-verifies the latest universal macOS release from
`zeroliu/demo-recorder`.

Require macOS 15+, `ffmpeg`, `ffprobe`, and an unlocked, awake desktop.
`caffeinate -dimsu` may keep the display and session awake during automation,
but it cannot record a manually locked login session.

## 2. Choose the story

For a bug, record the same shortest reproduction twice:

1. Before: establish the input, reproduce the trigger, and hold on the failure.
2. After: repeat the trigger and hold on the corrected result.

For a feature, record one coherent walkthrough:

1. Establish why or where the feature is used.
2. Demonstrate the primary path.
3. Include one or two relevant boundaries or edge cases when they add confidence.
4. Hold briefly on the settled result.

Minimize dead time between actions. Leave time only when the UI must settle or
a caption needs roughly one to three seconds to be read.

## 3. Prepare a safe exact-window capture

- Close, crop, or mask tokens, personal data, private repository names,
  notifications, unrelated tabs or sidebars, note titles, and account details.
- Prefer a dedicated test account, vault, project, or fixture.
- List windows and select the exact stable ID:

```bash
"$DEMO_RECORDER" list --app Obsidian
```

- Never fall back to whole-screen capture when the requested window is unclear.
- Rehearse the path once before recording.
- Record a caption-free master. Supply an event log when automation can report
  click coordinates; this hides the native pointer and renders one consistent
  cursor plus click pulse:

```bash
"$DEMO_RECORDER" record \
  --app Obsidian \
  --window-id 81 \
  --output /tmp/feature-master.mp4 \
  --events /tmp/feature-events.ndjson
```

Immediately before each automated click, mark coordinates from the same
viewport used by the automation:

```bash
"$DEMO_RECORDER" mark \
  --events /tmp/feature-events.ndjson \
  --x 500 --y 300 \
  --viewport-width 1258 --viewport-height 769
```

Do not add a second synthetic cursor when the source already contains one.

## 4. Compose and narrate

Read [references/timeline-schema.md](references/timeline-schema.md) before
building a timeline. Use normalized rectangles so zooms and masks survive
resolution changes.

```bash
"<skill-dir>/scripts/video_pipeline.py" compose \
  --spec /tmp/timeline.json \
  --output /tmp/composed-master.mp4
```

Use cubic ease-in-out tweening for focused zooms. Place highlights around the
result or active control, not around every click. For before/after videos, add
a short dark card between versions, then place a centered caption over it.

Write captions as a concise human explanation:

- Start with reproduction or context: “Type a draft, then switch backends.”
- State the causal idea only when it helps: “That switch replaced the draft's owner.”
- Name the visible result: “The unsent draft disappeared.”
- For the newer build, repeat the same steps, explain the fix briefly, and show
  the corrected result.

Keep each cue to one quickly readable sentence. Avoid announcing mechanical
actions already obvious on screen.

Read [references/caption-schema.md](references/caption-schema.md), then render
captions after stitching so their timestamps use the final timeline:

```bash
"$DEMO_RECORDER" render \
  --input /tmp/composed-master.mp4 \
  --output /tmp/narrated.mp4 \
  --captions /tmp/captions.json
```

In a sandboxed macOS agent, AVFoundation export may fail with `-11800` and
underlying OSStatus `-12903`. Retry the identical offline render with approved
macOS media execution; do not rewrite the input or bypass caption inspection.

## 5. Inspect before publication

Generate contact sheets and inspect every page:

```bash
"<skill-dir>/scripts/video_pipeline.py" storyboard \
  --input /tmp/narrated.mp4 \
  --output-dir /tmp/narrated-storyboard
```

Check the full sequence, not only a poster frame:

- correct app/window and version;
- no secrets or personal data;
- one cursor only and aligned click pulses;
- smooth zoom starts and landings;
- vertically centered, readable captions;
- clear before/after transition;
- no long waits, accidental cuts, or missing settled result.

If sensitive content is visible, add an opaque timed mask in the timeline and
re-render. Never upload first and plan to redact later.

## 6. Compress and publish

Create a web-friendly H.264 MP4:

```bash
"<skill-dir>/scripts/video_pipeline.py" compress \
  --input /tmp/narrated.mp4 \
  --output /tmp/narrated-web.mp4
```

Compare duration, resolution, and size with `ffprobe`, then inspect the
compressed storyboard again. Once public safety is confirmed, upload:

```bash
PUBLIC_URL=$("<skill-dir>/scripts/upload-r2.sh" \
  /tmp/narrated-web.mp4 \
  project/pr-123/demo.mp4 \
  --confirmed-public)
```

The configured R2 bucket is public. Treat the returned URL as world-readable.
The uploader verifies the downloaded bytes against the local file.

Return the public URL to the user.

## 7. Optional PR attachment

Only when the user explicitly asks and supplies a PR URL, prepend the video:

```bash
"<skill-dir>/scripts/prepend-pr-video.sh" \
  "https://github.com/owner/repo/pull/123" \
  "$PUBLIC_URL" \
  "Watch the walkthrough"
```

Preserve the existing PR description. Do not create a draft review or use a
browser for this update.
