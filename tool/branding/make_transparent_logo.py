#!/usr/bin/env python3
"""Derive a transparent-background copy of the official RCBFlow logo.

The official artwork (assets/branding/rcbflow_icon.png) is an opaque RGB PNG:
a rounded tile on a near-black square. This script leaves the original file
untouched and writes an RGBA copy where only the near-black surround that is
connected to the image border becomes transparent. Pixels inside the tile are
copied byte-for-byte; the 1-2 px anti-aliased ring at the tile edge gets a
partial alpha estimated from the adjacent tile colour, so the edge stays smooth.

No third-party packages are required (stdlib only).

Usage:
    python3 tool/branding/make_transparent_logo.py \
        assets/branding/rcbflow_icon.png \
        assets/branding/rcbflow_logo_transparent.png
"""

import struct
import sys
import zlib
from collections import deque

# A surround pixel is "near black" when no channel exceeds this value.
# The measured surround never exceeds 14; the tile edge starts well above 40.
BACKGROUND_MAX_CHANNEL = 24


def read_png(path):
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG file")
    pos, idat = 8, b""
    width = height = color_type = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        ctype = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        if ctype == b"IHDR":
            width, height, depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            if depth != 8 or interlace != 0 or color_type not in (2, 6):
                raise ValueError("only 8-bit non-interlaced RGB/RGBA supported")
        elif ctype == b"IDAT":
            idat += chunk
        pos += 12 + length

    bpp = 3 if color_type == 2 else 4
    stride = width * bpp
    raw = zlib.decompress(idat)
    pixels = []  # list of [r, g, b, a]
    prev = bytearray(stride)
    p = 0
    for _ in range(height):
        ftype = raw[p]
        line = bytearray(raw[p + 1 : p + 1 + stride])
        p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if ftype == 1:
                line[x] = (line[x] + a) & 0xFF
            elif ftype == 2:
                line[x] = (line[x] + b) & 0xFF
            elif ftype == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 0xFF
            elif ftype == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 0xFF
        for x in range(width):
            o = x * bpp
            alpha = line[o + 3] if bpp == 4 else 255
            pixels.append([line[o], line[o + 1], line[o + 2], alpha])
        prev = line
    return width, height, pixels


def write_png(path, width, height, pixels):
    stride = width * 4
    out = bytearray()
    prev = bytearray(stride)
    for y in range(height):
        row = bytearray()
        for x in range(width):
            row.extend(pixels[y * width + x])
        # Paeth filter for every row: simple and compresses well for artwork.
        filtered = bytearray(stride)
        for i in range(stride):
            a = row[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
            pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
            filtered[i] = (row[i] - pred) & 0xFF
        out.append(4)
        out.extend(filtered)
        prev = row

    def chunk(ctype, body):
        crc = zlib.crc32(ctype + body) & 0xFFFFFFFF
        return struct.pack(">I", len(body)) + ctype + body + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", zlib.compress(bytes(out), 9)))
        f.write(chunk(b"IEND", b""))


def main(src, dst):
    width, height, px = read_png(src)
    total = width * height

    def is_dark(i):
        r, g, b, _ = px[i]
        return max(r, g, b) <= BACKGROUND_MAX_CHANNEL

    # 1. Flood-fill the near-black surround from the image border.
    background = bytearray(total)
    queue = deque()
    for x in range(width):
        for y in (0, height - 1):
            i = y * width + x
            if not background[i] and is_dark(i):
                background[i] = 1
                queue.append(i)
    for y in range(height):
        for x in (0, width - 1):
            i = y * width + x
            if not background[i] and is_dark(i):
                background[i] = 1
                queue.append(i)
    while queue:
        i = queue.popleft()
        x, y = i % width, i // width
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                j = ny * width + nx
                if not background[j] and is_dark(j):
                    background[j] = 1
                    queue.append(j)

    def neighbours(i, radius):
        x, y = i % width, i // width
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                nx, ny = x + dx, y + dy
                if (dx or dy) and 0 <= nx < width and 0 <= ny < height:
                    yield ny * width + nx

    # 2. Edge ring = tile pixels touching the background.
    edge = bytearray(total)
    for i in range(total):
        if not background[i] and any(background[j] for j in neighbours(i, 1)):
            edge[i] = 1

    # 3. Build output: background transparent, edge ring partially transparent,
    #    everything else copied unchanged.
    out = [list(p) for p in px]
    for i in range(total):
        if background[i]:
            out[i] = [0, 0, 0, 0]
        elif edge[i]:
            inner = [
                px[j]
                for j in neighbours(i, 2)
                if not background[j] and not edge[j]
            ]
            if not inner:
                continue
            ref = [sum(p[k] for p in inner) / len(inner) for k in range(3)]
            ref_max = max(ref)
            cur_max = max(px[i][:3])
            alpha = 1.0 if ref_max <= 0 else min(1.0, cur_max / ref_max)
            # The edge pixel was composited over black, so its true colour is
            # approximately the neighbouring tile colour.
            out[i] = [round(ref[0]), round(ref[1]), round(ref[2]), round(alpha * 255)]

    write_png(dst, width, height, out)
    cleared = sum(background)
    print(
        f"{width}x{height}: {cleared} surround px transparent "
        f"({100 * cleared / total:.1f}%), {sum(edge)} edge px anti-aliased -> {dst}"
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
