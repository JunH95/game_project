"""적 스프라이트를 렌더한다.

    blender -b -P tools/blender/render_enemies.py

세 종이 **형태로** 갈려야 한다(design.md 9-1). 난전에서는 색을 볼 겨를이 없고 실루엣만
읽히기 때문이다. 그래서 크기가 아니라 윤곽을 다르게 만든다 —
흘러내리는 것 / 찌르는 것 / 뭉친 것.

카메라는 살짝 위에서 내려다본다. 정수직이면 정수리만 보여 무엇인지 알 수 없고,
정면이면 위에서 내려다보는 판과 어긋난다.

`faces_movement` 인 적(급살)은 게임에서 진행 방향으로 회전하므로 **오른쪽(+X)** 을 보게 찍는다.
"""

import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

SIZE = 512
SEED = 20260727
## 카메라를 수직에서 얼마나 눕히는지. 0 이면 정수리만 보여 무엇인지 알 수 없다.
## 위에서 내려다보는 판이지만 캐릭터는 거의 정면으로 그리는 것이 이 장르의 관례다 —
## 실루엣이 세로로 서야 8px 짜리로 줄어들어도 종류가 읽힌다.
TILT = 62.0


def _sphere(x, y, z, radius, mat, squash=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=(x, y, z), segments=20, ring_count=12)
    obj = bpy.context.object
    obj.scale = squash
    # 각진 면이 보이면 저해상도 스프라이트에서 지저분해진다. 부드럽게 처리한다.
    bpy.ops.object.shade_smooth()
    return rig.paint(obj, mat)


def _cone(x, y, z, radius, depth, mat, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cone_add(radius1=radius, depth=depth, location=(x, y, z), vertices=16)
    obj = bpy.context.object
    obj.rotation_euler = rot
    return rig.paint(obj, mat)


def build_wraith(rng):
    """추격 원귀 — 아래로 흘러내리는 넋. 발이 없어야 떠 있는 것으로 읽힌다.

    세로로 길게 세운다. 동글게 뭉치면 원귀가 아니라 인형이 된다.
    """
    body = rig.flat_material("body", "#D92929")
    dark = rig.flat_material("dark", "#7E1818")
    deep = rig.flat_material("deep", "#4A0E0E")
    eye = rig.flat_material("eye", "#FFEDB8")

    # 자락: 아래로 퍼지는 원뿔. 뒤집으면 위가 벌어져 속이 보이는 그릇이 된다.
    _cone(0.0, 0.0, -0.75, 0.72, 2.1, dark)
    # 어깨 — 자락보다 어두워야 그 앞에 있는 것으로 읽힌다.
    _sphere(0.0, -0.10, 0.10, 0.52, deep, squash=(1.15, 0.7, 0.72))
    # 머리. 어깨보다 밝게 해서 얼굴에 시선이 가게 한다.
    _sphere(0.0, -0.16, 0.62, 0.40, body, squash=(1.0, 0.86, 1.12))
    # 움푹한 눈구멍 위에 빛나는 눈. 두 점만 있어도 노려보는 것이 된다.
    for side in (-1.0, 1.0):
        _sphere(0.16 * side, -0.44, 0.66, 0.11, deep, squash=(1.3, 0.6, 1.0))
        _sphere(0.16 * side, -0.50, 0.66, 0.075, eye)
    # 자락 끝의 해진 조각. 밑단이 곧게 잘리면 혼이 아니라 원뿔로 보인다.
    for i in range(7):
        angle = math.tau * i / 7.0 + rng.uniform(-0.25, 0.25)
        _cone(math.cos(angle) * 0.52, math.sin(angle) * 0.30, -1.85,
              rng.uniform(0.11, 0.20), rng.uniform(0.7, 1.3), deep,
              rot=(math.pi + rng.uniform(-0.3, 0.3), 0.0, angle))


def build_rusher(rng):
    """급살 원귀 — 오른쪽으로 찌르는 화살촉. 질량이 거의 없어야 빨라 보인다."""
    body = rig.flat_material("body", "#FA7333")
    dark = rig.flat_material("dark", "#A24B21")

    # 앞으로 길게 누운 원뿔이 코가 된다. +X 를 향한다.
    _cone(0.30, 0.0, 0.0, 0.46, 2.0, dark, rot=(0.0, math.pi * 0.5, 0.0))
    # 뒤로 뻗은 날개. 속도를 형태로 보여 준다.
    for side in (-1.0, 1.0):
        _cone(-0.70, 0.0, 0.34 * side, 0.18, 1.2, dark,
              rot=(0.0, math.pi * 0.5, 0.0))
    # 중심의 밝은 심지. 코보다 짧고 얇아야 안쪽에 있는 것으로 읽힌다.
    _cone(0.44, -0.05, 0.0, 0.22, 1.5, body, rot=(0.0, math.pi * 0.5, 0.0))


def build_hulk(rng):
    """업(業)덩이 — 뭉쳐 굳은 죄업. 육중하고 느린 것이 실루엣에서 보여야 한다."""
    dark = rig.flat_material("dark", "#450E12")
    body = rig.flat_material("body", "#73171F")
    ember = rig.flat_material("ember", rig.JUSA)
    eye = rig.flat_material("eye", "#8C4147")

    # 겹친 덩어리가 먼저다. 발광구를 크게 깔면 덩어리를 통째로 덮어 그냥 공이 된다.
    # 좌우 대칭으로 놓으면 클로버처럼 보인다 — 크기와 위치를 일부러 어긋나게 둔다.
    lumps = [(0.00, 0.00, -0.34, 0.74), (-0.52, -0.08, 0.02, 0.46),
             (0.38, -0.06, -0.14, 0.40), (0.14, 0.12, -0.66, 0.42),
             (-0.26, 0.16, 0.36, 0.36), (0.46, 0.14, 0.34, 0.26),
             (-0.12, -0.22, 0.44, 0.40), (0.62, -0.02, -0.52, 0.24)]
    for i, (x, y, z, r) in enumerate(lumps):
        _sphere(x, y, z, r, body if i % 2 else dark,
                squash=(rng.uniform(0.95, 1.2), rng.uniform(0.8, 0.95),
                        rng.uniform(0.78, 0.98)))
    # 덩어리 틈으로만 새는 빛. 작게 여러 개 둬야 "안에 갇힌 것"으로 읽힌다.
    for i in range(5):
        angle = math.tau * i / 5.0 + 0.4
        _sphere(math.cos(angle) * 0.52, -0.30, math.sin(angle) * 0.48, 0.16, ember)
    # 위쪽에 파묻힌 눈
    for side in (-1.0, 1.0):
        _sphere(0.20 * side, -0.42, 0.58, 0.11, eye)


## (빌더, 카메라 폭, 카메라 높이 보정). 폭은 모델이 프레임에 다 들어가게 잡는다 —
## 잘리면 게임에서 발이 없는 것처럼 보인다.
ENEMIES = {
    "chaser": (build_wraith, 3.8, -0.55),
    "rusher": (build_rusher, 2.8, 0.0),
    "tank": (build_hulk, 3.0, 0.0),
}


def main():
    out_dir = os.path.join(rig.project_root(), "assets", "sprites", "enemies")
    for name, (builder, scale, y_shift) in ENEMIES.items():
        rig.reset_scene()
        rig.setup_render(size=SIZE, samples=20, ink=2.2)
        camera = rig.ortho_camera(scale=scale, tilt_deg=TILT)
        # 세로로 긴 모델은 프레임 가운데가 몸통이 아니라 얼굴이 되게 카메라를 내린다.
        camera.location.z += y_shift
        builder(random.Random(SEED))
        rig.render_to(os.path.join(out_dir, "%s.png" % name))


main()
