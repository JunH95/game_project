"""공용 렌더 리그. 모든 스프라이트가 같은 조건으로 렌더되게 하는 한 곳.

액터마다 카메라·조명·색을 따로 두면 톤이 반드시 어긋난다(게임 안에서 `PlaceholderArt` 로
팔레트를 모은 것과 같은 이유). AI 생성이 스프라이트 수십 장의 톤을 못 맞추는 것이
가장 큰 약점인데, 렌더는 그 문제가 원천적으로 없다 — 같은 리그를 쓰면 흔들릴 수가 없다.

쓰는 법:
    blender -b -P tools/blender/render_tiles.py

주의(이 환경의 함정):
- Cycles CPU 만 쓴다. Eevee/Workbench 는 GL 컨텍스트가 필요해 헤드리스에서 깨진다.
- Ubuntu 빌드에는 OpenImageDenoiser 가 없다. 디노이징을 켜면 렌더가 죽는다.
- 색관리를 Standard 로 두지 않으면 Filmic 이 채도를 깎아 팔레트가 어긋난다.
  머티리얼 색은 linear 로 넣어야 하므로 hex 를 반드시 `srgb()` 로 통과시킨다.
"""

import math
import os
import sys

import bpy

# vision.md 4절 광물 안료. 여기 없는 색은 쓰지 않는다 — 팔레트가 새면 톤이 무너진다.
JUSA = "#B3352A"        # 주사홍
GUNCHEONG = "#25407A"   # 군청
GEUMBAK = "#D9A441"     # 금박
MEOK = "#1B1B24"        # 먹
HOBUN = "#F2EDE3"       # 호분(백)

# 팔레트 사이를 메우는 중간톤. 원색만으로는 입체가 안 읽혀 명암 대신 쓴다.
MEOK_LIGHT = "#2E2E3D"
JUSA_DARK = "#6E2019"
GUNCHEONG_LIGHT = "#3A5A9E"


def srgb(hex_color: str, alpha: float = 1.0):
    """hex(sRGB) → Blender 가 기대하는 linear RGBA.

    Python 으로 넣는 색은 색 선택기와 달리 변환을 거치지 않는다. 그냥 넣으면
    렌더 결과가 지정한 색보다 밝고 뿌옇게 나온다.
    """
    hex_color = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(hex_color[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], alpha)


def reset_scene():
    """빈 씬에서 시작한다. 기본 큐브·램프가 남으면 렌더에 섞여 든다."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def setup_render(size: int = 512, samples: int = 24, ink: float = 1.6,
                 ink_border: bool = True):
    """Cycles CPU · 투명 배경 · Standard 색관리 · Freestyle 잉크 외곽선.

    ink 가 0 이면 외곽선을 끈다.
    ink_border 는 화면 가장자리에 선을 그을지다. 타일에서는 반드시 꺼야 한다 —
    켜면 셀 경계마다 먹선이 생겨 이어 붙였을 때 격자가 드러난다.
    """
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    # 이 빌드에는 디노이저가 없다. 켜 두면 렌더 자체가 실패한다.
    sc.cycles.use_denoising = False
    # 플랫 이미션이라 빛이 튈 곳이 없다. 바운스를 0 으로 두면 그만큼 빨라진다.
    sc.cycles.max_bounces = 0

    sc.render.film_transparent = True
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"

    # 게임 아트는 사진이 아니다. Filmic/AgX 는 채도를 깎아 지정한 팔레트를 어긋나게 한다.
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"

    # 무신도의 형식은 "굵은 먹선 + 평면 채색"이다. Freestyle 이 그 먹선을 낸다.
    sc.render.use_freestyle = bool(ink)
    if ink:
        view_layer = bpy.context.view_layer
        view_layer.freestyle_settings.as_render_pass = False
        # 공장 초기화 상태에는 linestyle 이 비어 있는 기본 LineSet 이 남아 있다.
        # 그대로 두면 스트로크 렌더 단계에서 Blender 가 죽는다(NoneType.use_chaining).
        linesets = view_layer.freestyle_settings.linesets
        while linesets:
            linesets.remove(linesets[0])
        lineset = linesets.new("ink")
        lineset.select_silhouette = True
        lineset.select_border = ink_border
        lineset.select_crease = True
        # 헤드리스에서는 linestyle 이 자동으로 붙지 않는다. 비워 두면 렌더 도중 죽는다.
        style = bpy.data.linestyles.new("ink_style")
        lineset.linestyle = style
        style.color = srgb(MEOK)[:3]
        style.thickness = ink
    return sc


def ortho_camera(scale: float, tilt_deg: float = 0.0, height: float = 20.0):
    """정사영 카메라. tilt_deg 0 이면 정수직(타일용), 키우면 캐릭터를 정면에 가깝게 본다.

    원근 카메라를 쓰지 않는 이유: 타일이 화면 가장자리에서 기울어 이음새가 깨지고,
    캐릭터도 위치에 따라 크기가 달라져 스프라이트로 쓸 수 없다.
    """
    sc = bpy.context.scene
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = scale
    cam = bpy.data.objects.new("Cam", data)
    sc.collection.objects.link(cam)

    pitch = math.radians(tilt_deg)
    cam.location = (0.0, -height * math.sin(pitch), height * math.cos(pitch))
    cam.rotation_euler = (pitch, 0.0, 0.0)
    sc.camera = cam
    return cam


def flat_material(name: str, hex_color: str, strength: float = 1.0):
    """평면 채색용 이미션 머티리얼. 그림자가 지지 않아 지정한 색이 그대로 나온다.

    입체는 명암이 아니라 형태와 외곽선으로 낸다 — 무신도가 그렇게 생겼고,
    작은 스프라이트에서는 그늘이 진흙처럼 뭉개진다.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    emission = nt.nodes.new("ShaderNodeEmission")
    emission.inputs[0].default_value = srgb(hex_color)
    emission.inputs[1].default_value = strength
    output = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emission.outputs[0], output.inputs[0])
    return mat


def paint(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def render_to(path: str):
    """절대경로로 저장한다. 부모 폴더가 없으면 만든다."""
    path = os.path.abspath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDERED %s" % path)
    return path


def project_root() -> str:
    """이 파일 기준 저장소 루트. blender 는 cwd 가 제각각이라 경로를 유추하지 않는다."""
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
