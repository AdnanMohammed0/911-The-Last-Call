"""Assemble a short gameplay capture teaser from real Godot frame sequences.

First capture each clip with capture_store.tscn and the clip_<name> preset.
Requires an ffmpeg executable; pass --ffmpeg if it is not on PATH.
"""

import argparse
import array
import math
from pathlib import Path
import random
import subprocess
import tempfile
import wave

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
TRAILER = ROOT / "marketing/steam/trailer"
CLIPS = ("station", "cad", "vsa", "farmhouse", "highway")
FRAME_RATE = 24
FRAME_COUNT = 72
SAMPLE_RATE = 48_000
DURATION = len(CLIPS) * FRAME_COUNT / FRAME_RATE + 3.0


def run(*parts: str) -> None:
    subprocess.run(parts, check=True)


def make_audio(path: Path) -> None:
    """Original low ambient hum and a restrained telephone pulse."""
    rng = random.Random(911)
    frames = array.array("h")
    previous_noise = 0.0
    for index in range(round(DURATION * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        previous_noise = previous_noise * 0.97 + noise * 0.03
        hum = 0.07 * math.sin(2 * math.pi * 55 * time)
        hum += 0.025 * math.sin(2 * math.pi * 82 * time)
        hum += 0.08 * previous_noise
        ring = 0.0
        if time < 6.0 and (time % 2.4) < 0.34:
            edge = min(1.0, (time % 2.4) * 15, (0.34 - time % 2.4) * 15)
            ring = 0.06 * max(0.0, edge) * (
                math.sin(2 * math.pi * 440 * time) + 0.45 * math.sin(2 * math.pi * 480 * time)
            )
        volume = min(1.0, time * 2.0, (DURATION - time) * 1.5)
        sample = max(-1.0, min(1.0, (hum + ring) * max(0.0, volume)))
        value = int(sample * 32767)
        frames.extend((value, value))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(frames.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", default="ffmpeg")
    args = parser.parse_args()
    TRAILER.mkdir(parents=True, exist_ok=True)
    for name in CLIPS:
        path = TRAILER / "frames" / name
        if len(list(path.glob("*.jpg"))) != FRAME_COUNT:
            raise SystemExit(f"Expected {FRAME_COUNT} captured frames in {path}")
    with tempfile.TemporaryDirectory(prefix="last_call_trailer_") as temp_name:
        temp = Path(temp_name)
        encoded: list[Path] = []
        for name in CLIPS:
            output = temp / f"{name}.mp4"
            run(
                args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                "-framerate", str(FRAME_RATE), "-i", str(TRAILER / "frames" / name / "%04d.jpg"),
                "-vf", "scale=1920:1080,format=yuv420p", "-r", "30",
                "-c:v", "h264_nvenc", "-b:v", "8M", "-an", str(output),
            )
            encoded.append(output)
        card = ImageOps.fit(
            Image.open(ROOT / "marketing/steam/capsules/main_capsule.jpg").convert("RGB"),
            (1920, 1080), Image.Resampling.LANCZOS,
        )
        card.save(temp / "end_card.jpg", quality=95)
        end_video = temp / "end_card.mp4"
        run(
            args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
            "-loop", "1", "-framerate", "30", "-t", "3", "-i", str(temp / "end_card.jpg"),
            "-vf", "format=yuv420p", "-r", "30", "-c:v", "h264_nvenc", "-b:v", "8M",
            "-an", str(end_video),
        )
        encoded.append(end_video)
        playlist = temp / "concat.txt"
        playlist.write_text("".join(f"file '{item.as_posix()}'\n" for item in encoded), encoding="utf-8")
        video = temp / "video.mp4"
        run(args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(playlist), "-c", "copy", str(video))
        audio = temp / "ambient.wav"
        make_audio(audio)
        output = TRAILER / "last_call_gameplay_teaser.mp4"
        run(
            args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(video), "-i", str(audio),
            "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
            "-shortest", str(output),
        )
        print(f"Built {output} ({output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
