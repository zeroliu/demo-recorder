# Caption schema

Demo Recorder accepts a JSON object containing a `captions` array:

```json
{
  "captions": [
    {
      "start": 0.0,
      "end": 2.5,
      "text": "Type a draft, then switch backends without sending.",
      "label": "REPRO",
      "tone": "before",
      "placement": "bottom"
    },
    {
      "start": 8.5,
      "end": 10.1,
      "text": "Newer build · same steps, corrected ownership.",
      "label": "AFTER",
      "tone": "after",
      "placement": "center"
    }
  ]
}
```

## Fields

- `start`: Required nonnegative timestamp in seconds on the final stitched video.
- `end`: Required timestamp greater than `start`.
- `text`: Required single, quickly readable sentence.
- `label`: Optional compact badge such as `REPRO`, `BUG`, `FIX`, or `RESULT`.
- `tone`: Optional `neutral`, `before`, or `after`. These render blue, red, and
  green accents respectively.
- `placement`: Optional `bottom` or `center`. Omission defaults to `bottom`;
  reserve `center` for chapter or version-transition cards.

Only one caption should be active at a time. Use one to three seconds per cue
depending on sentence length, and inspect the rendered glyph alignment rather
than trusting timestamps alone.
