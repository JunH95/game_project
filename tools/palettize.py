#!/usr/bin/env python3
"""AI 로 뽑은 그림을 광물 안료 팔레트로 강제 매핑한다.

    python3 tools/palettize.py assets/sprites/gods/*.png
    python3 tools/palettize.py in.png --out out.png --shades 4

## 왜 필요한가
AI 이미지 생성의 유일하고 치명적인 약점은 **여러 장의 톤이 흔들리는 것**이다. 신 9종을
따로 뽑으면 채도·색조가 제각각이라 한 게임처럼 보이지 않는다. 그림 자체는 잘 뽑으므로,
색만 사후에 가둔다 — Blender 리그가 렌더 톤을 고정하는 것과 같은 원리를 결과물에 적용한다.

## 어떻게
단순 최근접 색 매핑은 쓰면 안 된다. 팔레트가 5색뿐이라 얼굴이 통째로 붉어지거나 하얘진다.
대신 기본색마다 **먹·호분과 섞은 명도 단계**를 파생시켜 램프를 만들고 거기에 매핑한다.
그러면 형태(명암 구조)는 남고 색만 팔레트 안에 갇힌다.

거리는 사람 눈에 맞춰 초록에 가중치를 크게 준다(단순 RGB 거리는 밝기 차이를 과소평가한다).
디더링은 하지 않는다 — 무신도는 평면 채색 양식이라 점을 흩뿌리면 양식이 깨진다.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pnglite  # noqa: E402

# vision.md 4절 광물 안료. tools/blender/rig.py 와 같은 값이어야 렌더와 그림이 한 세트가 된다.
BASE = {
    "jusa": "#B3352A",       # 주사홍
    "guncheong": "#25407A",  # 군청
    "geumbak": "#D9A441",    # 금박
    "meok": "#1B1B24",       # 먹
    "hobun": "#F2EDE3",      # 호분
}
## 명도 램프의 양 끝. 어두운 쪽은 먹, 밝은 쪽은 호분으로 끌어당긴다.
DARK = BASE["meok"]
LIGHT = BASE["hobun"]

## 이 알파 아래는 배경으로 보고 완전히 지운다. AI 누끼 결과에 남는 반투명 테를 정리한다.
ALPHA_CUTOFF = 40

## 사람 눈의 채널 민감도. 초록을 크게 보지 않으면 명암 구조가 뭉개진다.
WEIGHTS = (0.30, 0.59, 0.11)

## 채도 보존 가중치. 이게 없으면 밝기만 맞추다 원색이 전부 회색으로 눌린다 —
## 팔레트에 없는 색(보라·청록)일수록 중간 회색이 "가장 가까운" 답이 되기 때문이다.
## 원본이 쨍하면 팔레트에서도 쨍한 색을 고르게 만든다.
##
## 튜닝 이력: 0 이면 전부 회색으로 눌리고, 2.6 이면 반대로 살빛까지 원색으로 튄다.
## 1.2 에서 얼굴은 살빛(호분-금박 혼합)을 지키면서 옷·배경만 팔레트 색을 잡았다.
CHROMA_WEIGHT = 1.2


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def build_ramp(shades):
    """기본 5색에서 명도 단계를 파생시킨 확장 팔레트.

    shades 는 기본색 하나당 단계 수. 3이면 어둡게/그대로/밝게, 5면 더 촘촘해진다.
    적을수록 판판해져 양식이 강해지고, 많을수록 원본 형태가 잘 남는다.
    """
    dark, light = hex_to_rgb(DARK), hex_to_rgb(LIGHT)
    ramp = []
    for name, value in BASE.items():
        rgb = hex_to_rgb(value)
        if name in ("meok", "hobun"):
            # 먹과 호분은 램프의 양 끝 자체라 파생시키면 회색 계단만 늘어난다.
            ramp.append(rgb)
            continue
        for step in range(shades):
            t = step / max(1, shades - 1)  # 0 = 가장 어둡게, 1 = 가장 밝게
            if t < 0.5:
                ramp.append(mix(dark, rgb, t * 2.0))
            else:
                ramp.append(mix(rgb, light, (t - 0.5) * 2.0))
    # 중간 회색 두 단계만. 많이 두면 채도 있는 픽셀까지 전부 회색으로 빨려 든다.
    for step in (1, 2):
        ramp.append(mix(dark, light, step / 3.0))
    # 같은 색이 여러 번 나오면 탐색만 느려진다.
    return sorted(set(ramp))


def chroma(rgb):
    """채도 대용값. HSV 로 바꾸지 않는 이유는 순서만 맞으면 되기 때문이다."""
    return max(rgb) - min(rgb)


def nearest(ramp, rgb):
    source_chroma = chroma(rgb)
    best = None
    best_dist = None
    for candidate in ramp:
        dist = sum(WEIGHTS[i] * (candidate[i] - rgb[i]) ** 2 for i in range(3))
        dist += CHROMA_WEIGHT * (chroma(candidate) - source_chroma) ** 2
        if best_dist is None or dist < best_dist:
            best_dist = dist
            best = candidate
    return best


def palettize(path, out_path, shades):
    width, height, rows = pnglite.read_png(path)
    ramp = build_ramp(shades)
    # 같은 색이 수없이 반복되므로 한 번 고른 답은 기억한다. 없으면 픽셀마다 램프를 다 훑는다.
    cache = {}
    out_rows = []
    for row in rows:
        line = bytearray(row)
        for x in range(width):
            i = x * pnglite.BPP
            alpha = line[i + 3]
            if alpha < ALPHA_CUTOFF:
                line[i:i + 4] = b"\x00\x00\x00\x00"
                continue
            key = bytes(line[i:i + 3])
            mapped = cache.get(key)
            if mapped is None:
                mapped = nearest(ramp, (line[i], line[i + 1], line[i + 2]))
                cache[key] = mapped
            line[i], line[i + 1], line[i + 2] = mapped
            # 반투명 가장자리는 양식에 없다. 남기면 게임 안에서 뿌옇게 번져 보인다.
            line[i + 3] = 255
        out_rows.append(bytes(line))
    pnglite.write_png(out_path, width, height, out_rows)
    print("%-42s → %-42s  팔레트 %d색 · 원본 %d색" % (
        os.path.basename(path), os.path.basename(out_path), len(ramp), len(cache)))


def main():
    parser = argparse.ArgumentParser(description="그림을 광물 안료 팔레트로 강제 매핑한다.")
    parser.add_argument("images", nargs="+", help="입력 PNG (8비트 RGBA)")
    parser.add_argument("--out", help="출력 경로. 여러 장이면 무시하고 제자리에서 덮어쓴다")
    parser.add_argument("--shades", type=int, default=4,
                        help="기본색당 명도 단계. 적을수록 판판해진다 (기본 4)")
    args = parser.parse_args()

    if args.shades < 2:
        parser.error("--shades 는 2 이상이어야 한다(1이면 명도 구조가 통째로 사라진다)")

    failures = 0
    for path in args.images:
        out_path = args.out if (args.out and len(args.images) == 1) else path
        try:
            palettize(path, out_path, args.shades)
        except (OSError, ValueError) as error:
            print("실패 %s: %s" % (path, error), file=sys.stderr)
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
