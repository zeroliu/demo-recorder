# Timeline schema

`video_pipeline.py compose` accepts a JSON document with the final `width`,
`height`, `fps`, and an ordered `segments` array.

## Video segment

```json
{
  "input": "/tmp/before.mp4",
  "start": 10.5,
  "duration": 3.0,
  "focus": {
    "x": 0.64,
    "y": 0.13,
    "width": 0.36,
    "height": 0.36,
    "tweenSeconds": 1.0
  },
  "fadeIn": 0.0,
  "fadeOut": 0.3,
  "highlights": [
    {
      "x": 0.02,
      "y": 0.18,
      "width": 0.96,
      "height": 0.42,
      "start": 1.5,
      "end": 3.0,
      "color": "red"
    }
  ],
  "masks": [
    {
      "x": 0.0,
      "y": 0.0,
      "width": 0.2,
      "height": 0.08,
      "start": 0.0,
      "end": 3.0
    }
  ]
}
```

All rectangles are normalized from `0` to `1`. `focus` coordinates refer to
the fitted source frame. Highlight and mask coordinates refer to the final
output frame. Timings are relative to the segment.

`focus` smoothly zooms from the whole frame to the requested region using
cubic ease-in-out. Omit it to keep the fitted whole frame.

Masks are opaque black and must cover sensitive content throughout every frame
where it appears. Highlights are borders; use them sparingly for the active
control or final result.

## Transition card

```json
{
  "color": "#101820",
  "duration": 1.6
}
```

Add a centered caption over the card during the later caption-rendering step,
for example “Newer build · same steps, corrected ownership.”

## Complete before/after skeleton

```json
{
  "width": 1920,
  "height": 1172,
  "fps": 30,
  "segments": [
    {
      "input": "/tmp/before.mp4",
      "start": 10.5,
      "duration": 3.0,
      "focus": {
        "x": 0.64,
        "y": 0.13,
        "width": 0.36,
        "height": 0.36,
        "tweenSeconds": 1.0
      }
    },
    {
      "input": "/tmp/before.mp4",
      "start": 33.5,
      "duration": 3.0,
      "fadeOut": 0.3
    },
    {
      "color": "#101820",
      "duration": 1.6
    },
    {
      "input": "/tmp/after.mp4",
      "start": 5.2,
      "duration": 3.0,
      "fadeIn": 0.3,
      "focus": {
        "x": 0.64,
        "y": 0.13,
        "width": 0.36,
        "height": 0.36,
        "tweenSeconds": 1.0
      }
    },
    {
      "input": "/tmp/after.mp4",
      "start": 23.0,
      "duration": 4.0
    }
  ]
}
```
