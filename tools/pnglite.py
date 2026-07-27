"""8비트 RGBA PNG 읽기/쓰기. 표준 라이브러리만 쓴다.

이 저장소의 도구는 Godot 없이 도는 것이 원칙이고(`validate_project.py` 와 같은 성격),
PIL·numpy 는 이 환경에 없다. 다루는 형식은 Blender 가 내보내는 것 하나뿐이라
범용 디코더가 아니라 딱 그것만 지원한다 — 다른 형식이면 조용히 넘기지 않고 에러를 낸다.
"""

import struct
import zlib

BPP = 4  # RGBA 8비트 고정


def read_png(path):
    """→ (width, height, rows). rows 는 행마다 RGBA 바이트열."""
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("%s: PNG 가 아니다" % path)

    pos = 8
    width = height = 0
    idat = bytearray()
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color_type = struct.unpack(">IIBB", body[:10])
            if depth != 8 or color_type != 6:
                raise ValueError("%s: 8비트 RGBA 가 아니다(depth=%d type=%d)"
                                 % (path, depth, color_type))
            if body[12] != 0:
                raise ValueError("%s: 인터레이스는 지원하지 않는다" % path)
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
        pos += 12 + length

    raw = zlib.decompress(bytes(idat))
    stride = width * BPP
    rows = []
    previous = bytearray(stride)
    pos = 0
    for _ in range(height):
        filter_type = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        _unfilter(filter_type, line, previous, stride)
        rows.append(bytes(line))
        previous = line
    return width, height, rows


def write_png(path, width, height, rows):
    """필터 없이(타입 0) 저장한다. 우리 그림은 평면 채색이라 zlib 만으로도 충분히 줄어든다."""
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw += row
    chunks = [
        _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
        _chunk(b"IDAT", zlib.compress(bytes(raw), 9)),
        _chunk(b"IEND", b""),
    ]
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        for chunk in chunks:
            handle.write(chunk)


def _chunk(kind, body):
    return (struct.pack(">I", len(body)) + kind + body
            + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))


def _unfilter(filter_type, line, previous, stride):
    """PNG 행 필터를 되돌린다. 필터는 압축률을 위한 것이라 반드시 풀어야 픽셀이 나온다."""
    if filter_type == 0:
        return
    for i in range(stride):
        left = line[i - BPP] if i >= BPP else 0
        up = previous[i]
        if filter_type == 1:
            line[i] = (line[i] + left) & 0xFF
        elif filter_type == 2:
            line[i] = (line[i] + up) & 0xFF
        elif filter_type == 3:
            line[i] = (line[i] + ((left + up) >> 1)) & 0xFF
        elif filter_type == 4:
            upper_left = previous[i - BPP] if i >= BPP else 0
            line[i] = (line[i] + _paeth(left, up, upper_left)) & 0xFF
        else:
            raise ValueError("알 수 없는 PNG 필터 %d" % filter_type)


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c
