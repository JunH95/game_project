"""저승 바닥 타일을 렌더한다. 이음새가 수학적으로 맞는다.

    blender -b -P tools/blender/render_tiles.py

이음새를 맞추는 방법: 셀 하나의 내용물을 만든 뒤 **3×3 으로 실제 복제**하고 가운데 셀만
찍는다. 셀 경계를 걸친 돌은 반대편 이웃 복제본에 그대로 나타나므로, 이어 붙였을 때
어긋날 수가 없다. AI 이미지 생성이 타일셋에서 실패하는 지점이 정확히 여기다 —
모델은 어느 변이 어느 변과 맞아야 하는지 알지 못한다.

수치는 전부 시드 고정이라 몇 번을 돌려도 같은 그림이 나온다(재현 가능해야 커밋할 값이 된다).
"""

import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

CELL = 2.0
SIZE = 512
SEED = 20260727


def _ngon(name, x, y, radius, sides, rot, z, mat):
    bpy.ops.mesh.primitive_circle_add(
        vertices=sides, radius=radius, fill_type="NGON", location=(x, y, z))
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (0.0, 0.0, rot)
    return rig.paint(obj, mat)


def _base_plane(mat, z=0.0):
    # 셀보다 넉넉히 크게 깔아야 3×3 복제 없이도 바탕에 구멍이 나지 않는다.
    bpy.ops.mesh.primitive_plane_add(size=CELL * 4.0, location=(0.0, 0.0, z))
    return rig.paint(bpy.context.object, mat)


def _tile_copies(objects):
    """셀 내용물을 3×3 으로 복제한다. 이것이 이음새를 보장하는 전부다."""
    for dx in (-CELL, 0.0, CELL):
        for dy in (-CELL, 0.0, CELL):
            if dx == 0.0 and dy == 0.0:
                continue
            for obj in objects:
                copy = obj.copy()
                copy.data = obj.data
                copy.location = (obj.location.x + dx, obj.location.y + dy, obj.location.z)
                bpy.context.scene.collection.objects.link(copy)


def _jittered_grid(rng, count, spread):
    """격자에 흔들림을 준 좌표. 완전 무작위로 뿌리면 뭉치고 빈 곳이 생긴다."""
    step = CELL / count
    for i in range(count):
        for j in range(count):
            x = -CELL / 2.0 + step * (i + 0.5) + rng.uniform(-spread, spread)
            y = -CELL / 2.0 + step * (j + 0.5) + rng.uniform(-spread, spread)
            yield x, y


def build_stone(rng):
    """저승 돌바닥. 관문 공통 기본 타일."""
    _base_plane(rig.flat_material("base", rig.MEOK))
    stone_a = rig.flat_material("stone_a", rig.MEOK_LIGHT)
    stone_b = rig.flat_material("stone_b", "#3A3A4E")
    made = []
    for idx, (x, y) in enumerate(_jittered_grid(rng, 4, 0.10)):
        mat = stone_a if rng.random() < 0.65 else stone_b
        made.append(_ngon("stone%d" % idx, x, y, rng.uniform(0.20, 0.27),
                          rng.choice((5, 6, 6, 7)), rng.uniform(0.0, 3.14), 0.02, mat))
    return made


def build_crack(rng):
    """균열 바닥. 아래에서 주사홍 빛이 샌다 — 화탕 관문(design.md 5-2)의 바닥."""
    _base_plane(rig.flat_material("glow", rig.JUSA), z=0.0)
    crust = rig.flat_material("crust", rig.MEOK)
    made = []
    # 큼직한 판을 벌어지게 깔면 그 틈이 균열이 된다. 선을 그리는 것보다 자연스럽다.
    for idx, (x, y) in enumerate(_jittered_grid(rng, 3, 0.16)):
        made.append(_ngon("crust%d" % idx, x, y, rng.uniform(0.34, 0.42),
                          rng.choice((5, 6, 7)), rng.uniform(0.0, 3.14), 0.02, crust))
    return made


def build_brick(rng):
    """전돌(방전) 바닥. 관아·시왕전 실내용 — 규칙적이라 야외와 대비된다."""
    _base_plane(rig.flat_material("mortar", rig.MEOK))
    face = rig.flat_material("brick", "#33333F")
    made = []
    rows, cols = 4, 2
    h, w = CELL / rows, CELL / cols
    for r in range(rows):
        # 켜마다 반 장씩 어긋나게 쌓는다. 나란히 쌓으면 벽이 아니라 격자로 보인다.
        offset = (w * 0.5) if r % 2 else 0.0
        for c in range(cols + 1):
            x = -CELL / 2.0 + w * c + offset - w * 0.5
            y = -CELL / 2.0 + h * (r + 0.5)
            bpy.ops.mesh.primitive_plane_add(size=1.0, location=(x, y, 0.02))
            obj = bpy.context.object
            obj.scale = (w * 0.46, h * 0.42, 1.0)
            made.append(rig.paint(obj, face))
    return made


def build_water(rng):
    """삼도천 물바닥. 군청 위에 옅은 넋빛이 어린다."""
    _base_plane(rig.flat_material("deep", "#101830"))
    mid = rig.flat_material("mid", rig.GUNCHEONG)
    lit = rig.flat_material("lit", rig.GUNCHEONG_LIGHT)
    made = []
    for idx, (x, y) in enumerate(_jittered_grid(rng, 5, 0.14)):
        mat = lit if rng.random() < 0.28 else mid
        obj = _ngon("wave%d" % idx, x, y, rng.uniform(0.16, 0.30),
                    rng.choice((6, 7, 8)), rng.uniform(0.0, 3.14), 0.02, mat)
        # 가로로 눌러 물결처럼 흐르게 한다. 동그라미만 있으면 자갈로 보인다.
        obj.scale = (1.0, rng.uniform(0.34, 0.5), 1.0)
        made.append(obj)
    return made


TILES = {
    "ground_stone": build_stone,
    "ground_crack": build_crack,
    "ground_brick": build_brick,
    "ground_water": build_water,
}


def main():
    out_dir = os.path.join(rig.project_root(), "assets", "sprites", "tiles")
    for name, builder in TILES.items():
        rig.reset_scene()
        # 타일에서 테두리 선은 반드시 끈다 — 셀마다 먹선이 생겨 격자가 드러난다.
        rig.setup_render(size=SIZE, samples=16, ink=1.1, ink_border=False)
        rig.ortho_camera(scale=CELL, tilt_deg=0.0)
        _tile_copies(builder(random.Random(SEED)))
        rig.render_to(os.path.join(out_dir, "%s.png" % name))


main()
