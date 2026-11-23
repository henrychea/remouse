#!/usr/bin/env python3
import subprocess
import sys

WIDTH = 2400
HEIGHT = 1200
CHANNELS = 3
STRIDE = WIDTH * CHANNELS
BAND_TOP = 988
SHADOW_SOURCE = 1052
TAIL_TOP = 1136
SHIFT = SHADOW_SOURCE - BAND_TOP
SOURCE_STRIP = 20


def number(value, label):
    try:
        return int(value)
    except ValueError:
        print(f"{label} must be an integer, got {value!r}")
        sys.exit(1)


def copy_band(buffer, destination_top, source_top, rows, x0, x1):
    offset = x0 * CHANNELS
    length = (x1 - x0) * CHANNELS
    for step in range(rows):
        source = (source_top + step) * STRIDE + offset
        destination = (destination_top + step) * STRIDE + offset
        buffer[destination:destination + length] = buffer[source:source + length]


def tile_rows(buffer, top, bottom, x0, x1, source_x):
    offset = x0 * CHANNELS
    length = (x1 - x0) * CHANNELS
    strip = SOURCE_STRIP * CHANNELS
    copies = -(-length // strip)
    for row in range(top, bottom):
        base = row * STRIDE
        sample = bytes(buffer[base + source_x * CHANNELS:base + source_x * CHANNELS + strip])
        buffer[base + offset:base + offset + length] = (sample * copies)[:length]


def fix_frame(buffer, fill_x0, fill_x1, source_x):
    copy_band(buffer, BAND_TOP, SHADOW_SOURCE, TAIL_TOP - BAND_TOP, fill_x0, fill_x1)
    tile_rows(buffer, TAIL_TOP, HEIGHT, fill_x0, fill_x1, source_x)


def process(source, target, fill_x0, fill_x1, source_x):
    decoder = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-i", source, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE,
    )
    encoder = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{WIDTH}x{HEIGHT}", "-framerate", "30", "-i", "-",
         "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "10",
         "-pix_fmt", "yuv420p", "-y", target],
        stdin=subprocess.PIPE,
    )
    if decoder.stdout is None or encoder.stdin is None:
        print("could not open ffmpeg pipes")
        sys.exit(1)
    size = STRIDE * HEIGHT
    frames = 0
    while True:
        raw = decoder.stdout.read(size)
        if len(raw) < size:
            break
        buffer = bytearray(raw)
        fix_frame(buffer, fill_x0, fill_x1, source_x)
        encoder.stdin.write(buffer)
        frames += 1
    encoder.stdin.close()
    decoder.wait()
    encoder.wait()
    print(f"{target}: {frames} frames (band shifted up {SHIFT}px, fill x {fill_x0}-{fill_x1})")


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("usage: fixband.py <in.mov> <out.mov> <fillX0> <fillX1> [sourceX]")
        sys.exit(1)
    strip_x = number(sys.argv[5], "sourceX") if len(sys.argv) > 5 else 1640
    process(sys.argv[1], sys.argv[2], number(sys.argv[3], "fillX0"), number(sys.argv[4], "fillX1"), strip_x)
