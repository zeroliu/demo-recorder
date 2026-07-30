# Demo Recorder

A macOS CLI for recording one exact application window with:

- a recorder-owned cursor and click pulse that work with automated clicks;
- timed subtitle cards; and
- a reusable caption-free master for quick wording revisions.

Requires macOS 15 or newer, Xcode/Swift 6, and Screen Recording permission.

## Install the latest release

```bash
curl -fL \
  https://github.com/zeroliu/demo-recorder/releases/latest/download/demo-recorder-macos-universal.tar.gz \
  -o /tmp/demo-recorder.tar.gz
curl -fL \
  https://github.com/zeroliu/demo-recorder/releases/latest/download/demo-recorder-macos-universal.tar.gz.sha256 \
  -o /tmp/demo-recorder.tar.gz.sha256
(cd /tmp && shasum -a 256 -c demo-recorder.tar.gz.sha256)
tar -xzf /tmp/demo-recorder.tar.gz -C /usr/local/bin
```

The archive contains a universal `demo-recorder` binary for Apple Silicon and
Intel Macs. The `releases/latest/download` URLs always resolve to the newest
published version.

## Build

```bash
swift build -c release
```

The CLI is then available at `.build/release/DemoRecorder`.

## Recording SOP

### 1. Select the exact window

```bash
.build/release/DemoRecorder list --app Obsidian
```

Use the reported window ID. This avoids accidentally recording whichever
window happens to be focused.

### 2. Measure the automation viewport

Record the pixel width and height of the screenshot used to drive the UI.
Marker coordinates must come from that same screenshot.

### 3. Record a caption-free master

```bash
.build/release/DemoRecorder record \
  --app Obsidian \
  --window-id 81 \
  --output /tmp/demo-master.mp4 \
  --events /tmp/demo-events.ndjson
```

Wait for `Ready for markers`, then perform the demo. Press Return when done.

Immediately before each automated click, add a marker using the same
coordinates and viewport dimensions as the UI automation:

```bash
.build/release/DemoRecorder mark \
  --events /tmp/demo-events.ndjson \
  --x 500 --y 300 \
  --viewport-width 1258 --viewport-height 769
```

The event log stores normalized positions, so the cursor and pulse remain
aligned when the captured window is downscaled.

### 4. Add editable subtitles

Create a caption document:

```json
{
  "captions": [
    {
      "start": 0.25,
      "end": 2.0,
      "text": "Draft text stays with this chat input.",
      "label": "BEFORE",
      "tone": "before",
      "placement": "bottom"
    }
  ]
}
```

Use `"placement": "center"` for a chapter or version-transition card. Omitting
the field keeps the default bottom placement.

Render the final video from the caption-free master:

```bash
.build/release/DemoRecorder render \
  --input /tmp/demo-master.mp4 \
  --output /tmp/demo-final.mp4 \
  --captions /tmp/demo-captions.json
```

Revise the JSON and render another output to change subtitles without
re-recording.

## Timing guidance

- Rehearse the UI sequence before recording.
- Mark each click immediately before performing it.
- Use short, deliberate pauses rather than waiting for narration.
- Stop manually after the final settled state to avoid a long trailing hold.
- Inspect the local MP4 before uploading or replacing a PR demo.

`--duration SECONDS` is available for unattended recordings. Manual stopping is
usually more reliable when UI automation or permission prompts may add latency.
