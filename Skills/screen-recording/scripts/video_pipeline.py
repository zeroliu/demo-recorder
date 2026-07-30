#!/usr/bin/env python3
import argparse
import json
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


def fail(message):
    raise SystemExit(message)


def tool(name):
    path = shutil.which(name)
    if not path:
        fail(f"missing dependency: {name}")
    return path


def run(command):
    print("+ " + shlex.join(str(item) for item in command), file=sys.stderr)
    subprocess.run([str(item) for item in command], check=True)


def number(value, name, minimum=0):
    if not isinstance(value, (int, float)) or value < minimum:
        fail(f"{name} must be a number >= {minimum}")
    return value


def rect(value, name):
    if not isinstance(value, dict):
        fail(f"{name} must be an object")
    values = [number(value.get(key), f"{name}.{key}") for key in ("x", "y", "width", "height")]
    x, y, width, height = values
    if width <= 0 or height <= 0 or x + width > 1 or y + height > 1:
        fail(f"{name} must fit inside normalized bounds")
    return values


def color(value, name):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9#@.]+", value):
        fail(f"{name} is not a safe ffmpeg color")
    return value


def enabled(item, duration):
    start = number(item.get("start", 0), "overlay.start")
    end = number(item.get("end", duration), "overlay.end")
    if end <= start or end > duration:
        fail("overlay timing must fit inside its segment")
    return f":enable='between(t\\,{start:g}\\,{end:g})'"


def overlays(filters, segment, duration, width):
    for mask in segment.get("masks", []):
        x, y, w, h = rect(mask, "mask")
        filters.append(
            f"drawbox=x=iw*{x:g}:y=ih*{y:g}:w=iw*{w:g}:h=ih*{h:g}"
            f":color=black:t=fill{enabled(mask, duration)}"
        )
    for highlight in segment.get("highlights", []):
        x, y, w, h = rect(highlight, "highlight")
        stroke = max(4, round(width / 480))
        tone = color(highlight.get("color", "yellow"), "highlight.color")
        filters.append(
            f"drawbox=x=iw*{x:g}:y=ih*{y:g}:w=iw*{w:g}:h=ih*{h:g}"
            f":color={tone}:t={stroke}{enabled(highlight, duration)}"
        )


def segment_filter(segment, input_index, label, width, height, fps):
    duration = number(segment.get("duration"), f"segments[{label}].duration", 0.001)
    frames = max(1, round(duration * fps))
    filters = []
    if "input" in segment:
        path = Path(segment["input"]).expanduser()
        if not path.is_file():
            fail(f"input not found: {path}")
        start = number(segment.get("start", 0), "segment.start")
        first = round(start * fps)
        filters.extend(
            [
                f"[{input_index}:v]fps={fps}",
                f"trim=start_frame={first}:end_frame={first + frames}",
                "setpts=PTS-STARTPTS",
                f"scale={width}:{height}:force_original_aspect_ratio=decrease",
                f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:black",
            ]
        )
        if focus := segment.get("focus"):
            x, y, w, h = rect(focus, "focus")
            target = min(1 / w, 1 / h)
            tween_frames = max(1, round(number(focus.get("tweenSeconds", 1), "focus.tweenSeconds") * fps))
            progress = f"min(on/{tween_frames}\\,1)"
            eased = f"({progress}*{progress}*(3-2*{progress}))"
            zoom = f"1+{target - 1:g}*{eased}"
            center_x, center_y = x + w / 2, y + h / 2
            pan_x = f"max(0\\,min(iw-iw/zoom\\,iw*{center_x:g}-iw/(2*zoom)))"
            pan_y = f"max(0\\,min(ih-ih/zoom\\,ih*{center_y:g}-ih/(2*zoom)))"
            filters.append(
                f"zoompan=z='{zoom}':x='{pan_x}':y='{pan_y}':d=1:s={width}x{height}:fps={fps}"
            )
    else:
        tone = color(segment.get("color", "black"), "segment.color")
        filters.append(f"color=c={tone}:s={width}x{height}:r={fps}:d={duration:g}")

    if fade_in := segment.get("fadeIn"):
        filters.append(f"fade=t=in:st=0:d={number(fade_in, 'fadeIn'):g}")
    if fade_out := segment.get("fadeOut"):
        fade_out = number(fade_out, "fadeOut")
        filters.append(f"fade=t=out:st={max(0, duration - fade_out):g}:d={fade_out:g}")
    overlays(filters, segment, duration, width)
    filters.extend([f"trim=end_frame={frames}", "setpts=PTS-STARTPTS", "setsar=1"])
    return ",".join(filters) + f"[s{label}]", duration


def compose(args):
    document = json.loads(Path(args.spec).read_text())
    width = int(number(document.get("width", 1920), "width", 2))
    height = int(number(document.get("height", 1080), "height", 2))
    fps = int(number(document.get("fps", 30), "fps", 1))
    segments = document.get("segments")
    if not isinstance(segments, list) or not segments:
        fail("segments must be a non-empty array")
    output = Path(args.output)
    if output.exists() and not args.force:
        fail(f"output exists: {output}")

    inputs, graph, labels = [], [], []
    input_index = 0
    for index, segment in enumerate(segments):
        if "input" in segment:
            inputs.extend(["-i", str(Path(segment["input"]).expanduser())])
            source_index = input_index
            input_index += 1
        else:
            source_index = None
        built, _ = segment_filter(segment, source_index, index, width, height, fps)
        graph.append(built)
        labels.append(f"[s{index}]")
    graph.append("".join(labels) + f"concat=n={len(labels)}:v=1:a=0[outv]")
    run(
        [tool("ffmpeg"), "-y" if args.force else "-n", "-hide_banner", "-loglevel", "error"]
        + inputs
        + [
            "-filter_complex",
            ";".join(graph),
            "-map",
            "[outv]",
            "-an",
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-crf",
            "18",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            output,
        ]
    )
    print(output)


def compress(args):
    output = Path(args.output)
    if output.exists() and not args.force:
        fail(f"output exists: {output}")
    scale = f"scale=w='min(iw\\,{args.max_width})':h=-2"
    run(
        [
            tool("ffmpeg"),
            "-y" if args.force else "-n",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            args.input,
            "-map",
            "0:v:0",
            "-an",
            "-vf",
            scale,
            "-c:v",
            "libx264",
            "-preset",
            "medium",
            "-crf",
            str(args.crf),
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            output,
        ]
    )
    print(output)


def storyboard(args):
    output = Path(args.output_dir)
    output.mkdir(parents=True, exist_ok=True)
    pattern = output / "storyboard-%03d.jpg"
    tile = f"fps=1/{args.interval},scale=480:-2,tile=4x3:nb_frames=12:padding=4:margin=4"
    run(
        [
            tool("ffmpeg"),
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            args.input,
            "-vf",
            tile,
            "-fps_mode",
            "vfr",
            pattern,
        ]
    )
    for path in sorted(output.glob("storyboard-*.jpg")):
        print(path)


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(required=True)
    compose_parser = commands.add_parser("compose")
    compose_parser.add_argument("--spec", required=True)
    compose_parser.add_argument("--output", required=True)
    compose_parser.add_argument("--force", action="store_true")
    compose_parser.set_defaults(handler=compose)
    compress_parser = commands.add_parser("compress")
    compress_parser.add_argument("--input", required=True)
    compress_parser.add_argument("--output", required=True)
    compress_parser.add_argument("--max-width", type=int, default=1920)
    compress_parser.add_argument("--crf", type=int, default=24)
    compress_parser.add_argument("--force", action="store_true")
    compress_parser.set_defaults(handler=compress)
    storyboard_parser = commands.add_parser("storyboard")
    storyboard_parser.add_argument("--input", required=True)
    storyboard_parser.add_argument("--output-dir", required=True)
    storyboard_parser.add_argument("--interval", type=float, default=1)
    storyboard_parser.set_defaults(handler=storyboard)
    args = parser.parse_args()
    args.handler(args)


if __name__ == "__main__":
    main()
