#!/usr/bin/env python3
"""타일 PNG 의 이음새를 검사한다. Godot·PIL·numpy 없이 표준 라이브러리만으로 돈다.

    python3 tools/check_tiles.py

이어 붙였을 때 왼쪽 끝 열과 오른쪽 끝 열이(위/아래 행도) 맞아야 격자가 드러나지 않는다.
눈으로는 몇 픽셀짜리 어긋남을 놓치는데, 게임에서는 화면 가득 반복되므로 바로 보인다.

렌더가 3×3 복제 방식이라 원리상 이음새는 맞다. 이 스크립트는 그 전제가 깨졌을 때
(카메라 스케일이 셀 크기와 어긋나는 등) 조용히 넘어가지 않게 막는 안전망이다.
"""

import os
import struct
import sys
import zlib

## 인접 픽셀 채널 차이가 이 값을 넘으면 "경계"로 센다. 렌더 노이즈는 이보다 훨씬 작다.
TOLERANCE = 24
## 이음새는 절대값으로 재면 안 된다 — 이어 붙였을 때 끝 열과 첫 열은 같은 픽셀이 아니라
## **인접한** 픽셀이라, 대비가 강한 타일(균열·전돌)은 정상인데도 크게 다르다.
## 그래서 이음새의 불연속을 **그림 내부의 인접 열 불연속**과 견준다. 내부보다 유난히
## 튀지 않으면 이어 붙였을 때 격자가 보이지 않는다.
SEAM_FACTOR = 2.5
## 내부 대비가 거의 없는 밋밋한 타일에서 배수가 무의미해지는 것을 막는 하한.
MIN_FLOOR = 0.02


def read_png(path):
    """8비트 RGBA·무인터레이스 PNG 를 (width, height, rows) 로 읽는다.

    Blender 가 내보내는 형식만 다룬다. 다른 형식이면 조용히 통과시키지 않고 에러를 낸다.
    """
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
    stride = width * 4
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


def _unfilter(filter_type, line, previous, stride):
    """PNG 행 필터를 되돌린다. 필터는 압축률을 위한 것이라 반드시 풀어야 픽셀이 나온다."""
    bpp = 4
    if filter_type == 0:
        return
    for i in range(stride):
        left = line[i - bpp] if i >= bpp else 0
        up = previous[i]
        if filter_type == 1:
            line[i] = (line[i] + left) & 0xFF
        elif filter_type == 2:
            line[i] = (line[i] + up) & 0xFF
        elif filter_type == 3:
            line[i] = (line[i] + ((left + up) >> 1)) & 0xFF
        elif filter_type == 4:
            upper_left = previous[i - bpp] if i >= bpp else 0
            line[i] = (line[i] + _paeth(left, up, upper_left)) & 0xFF
        else:
            raise ValueError("알 수 없는 PNG 필터 %d" % filter_type)


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def _mismatch_ratio(pairs):
    """(픽셀A, 픽셀B) 쌍 중 허용 오차를 넘는 비율."""
    if not pairs:
        return 0.0
    bad = 0
    for left, right in pairs:
        if max(abs(l - r) for l, r in zip(left, right)) > TOLERANCE:
            bad += 1
    return bad / len(pairs)


def _column_pair(rows, x_left, x_right):
    return [(row[x_left * 4:x_left * 4 + 4], row[x_right * 4:x_right * 4 + 4])
            for row in rows]


def _row_pair(rows, width, y_top, y_bottom):
    top, bottom = rows[y_top], rows[y_bottom]
    return [(bottom[x * 4:x * 4 + 4], top[x * 4:x * 4 + 4]) for x in range(width)]


## 기준선을 뽑을 내부 표본 수. 적게 잡으면 표본이 전부 단색 안쪽에 걸려 기준이 0 이 되고,
## 그러면 정상 타일도 실패로 나온다.
BASELINE_SAMPLES = 32


def _interior_baseline(samples):
    """내부 인접 쌍들의 불연속 평균. 이 그림이 원래 얼마나 들쭉날쭉한지의 기준."""
    ratios = [_mismatch_ratio(pairs) for pairs in samples]
    return sum(ratios) / len(ratios) if ratios else 0.0


def check(path):
    width, height, rows = read_png(path)

    # 이음새: 마지막 열 옆에 첫 열이, 마지막 행 아래에 첫 행이 온다.
    h_seam = _mismatch_ratio(_column_pair(rows, width - 1, 0))
    v_seam = _mismatch_ratio(_row_pair(rows, width, 0, height - 1))

    # 기준선: 그림 내부를 고르게 훑어 같은 방식으로 잰다.
    xs = [max(1, min(width - 2, width * i // (BASELINE_SAMPLES + 1)))
          for i in range(1, BASELINE_SAMPLES + 1)]
    ys = [max(1, min(height - 2, height * i // (BASELINE_SAMPLES + 1)))
          for i in range(1, BASELINE_SAMPLES + 1)]
    h_base = _interior_baseline([_column_pair(rows, x, x + 1) for x in xs])
    v_base = _interior_baseline([_row_pair(rows, width, y, y + 1) for y in ys])

    h_limit = max(h_base * SEAM_FACTOR, MIN_FLOOR)
    v_limit = max(v_base * SEAM_FACTOR, MIN_FLOOR)
    ok = h_seam <= h_limit and v_seam <= v_limit
    print("%-18s %dx%d  가로 %5.2f%% (기준 %5.2f%%)  세로 %5.2f%% (기준 %5.2f%%)  %s" % (
        os.path.basename(path), width, height,
        h_seam * 100, h_limit * 100, v_seam * 100, v_limit * 100,
        "OK" if ok else "SEAM"))
    return ok


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    tile_dir = os.path.join(root, "assets", "sprites", "tiles")
    if not os.path.isdir(tile_dir):
        print("타일 폴더가 없다: %s" % tile_dir)
        return 1
    names = sorted(n for n in os.listdir(tile_dir) if n.endswith(".png"))
    if not names:
        print("검사할 타일이 없다.")
        return 1
    failures = 0
    for name in names:
        if not check(os.path.join(tile_dir, name)):
            failures += 1
    print("\n%d개 검사 · 이음새 실패 %d개" % (len(names), failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
