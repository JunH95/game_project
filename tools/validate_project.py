#!/usr/bin/env python3
"""저승·바리데기 정적 검증기 — Godot 없이 손으로 쓴 씬/리소스/스크립트의 취약점을 잡는다.

원격 세션처럼 에디터 없이 파일만 작성하면 Godot 이 저장할 때 자동으로 지켜 주는 규칙이
깨진다. 실제로 겪은 사고를 그대로 검사 항목으로 만들었다.

잡는 것
  1. ext_resource 경로 존재
  2. ExtResource/SubResource id 정의 여부
  3. .tscn/.tres 태그 순서 — ext_resource 는 sub_resource·node 보다 먼저 와야 한다
     (player.tscn 이 이걸 어겨 씬 전체가 로드 실패했다)
  4. .tres 가 쓰는 속성이 스크립트 클래스에 @export 로 선언돼 있는지
     (EnemyData.element 가 선언 없이 .tres 에만 있어 전투 중 크래시가 났다)
  5. autoload·main_scene 경로 존재
  6. GDScript 괄호 균형, 공백 들여쓰기(Godot 관례는 탭)

못 잡는 것: 런타임 로직, GDScript 타입 추론 오류, Godot API 오용.
그건 헤드리스 실행으로 잡는다:
  godot --headless --path <프로젝트> --quit-after 600
"""
import io
import os
import re
import sys
import glob

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# 이 파일은 <프로젝트>/tools/ 에 있으므로 상위가 프로젝트 루트다. 경로를 박아두면 다른 PC 에서 죽는다.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SKIP_DIRS = ("addons", ".godot", ".git")

# Resource 가 기본으로 갖는 속성. .tres 에 나와도 스크립트 선언을 요구하지 않는다.
BUILTIN_RESOURCE_PROPS = {
    "script", "resource_name", "resource_local_to_scene", "resource_path", "metadata",
}

errors: list[str] = []
warns: list[str] = []


def rel(path: str) -> str:
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def res_to_path(res: str) -> str:
    return os.path.join(ROOT, res[len("res://"):].replace("/", os.sep))


def walk(pattern: str) -> list[str]:
    out = []
    for f in glob.glob(os.path.join(ROOT, pattern), recursive=True):
        if any(f"{os.sep}{d}{os.sep}" in f or f.endswith(f"{os.sep}{d}") for d in SKIP_DIRS):
            continue
        out.append(f)
    return sorted(out)


def exported_properties(gd_path: str) -> set[str]:
    """스크립트가 @export 로 노출한 속성 이름 + 부모 클래스에서 물려받은 것."""
    props: set[str] = set()
    seen: set[str] = set()
    current = gd_path
    while current and os.path.exists(current) and current not in seen:
        seen.add(current)
        text = io.open(current, encoding="utf-8").read()
        for m in re.finditer(r"^@export[^\n]*\n\s*var\s+(\w+)", text, re.M):
            props.add(m.group(1))
        for m in re.finditer(r"^@export[\w_]*(?:\([^)]*\))?\s+var\s+(\w+)", text, re.M):
            props.add(m.group(1))
        # extends 가 스크립트 경로면 따라 올라간다(내장 타입이면 멈춘다).
        ext = re.search(r'^extends\s+"([^"]+)"', text, re.M)
        current = res_to_path(ext.group(1)) if ext and ext.group(1).startswith("res://") else None
    return props


def check_tag_order(path: str, text: str) -> None:
    """ext_resource 가 sub_resource/node 뒤에 오면 Godot 이 파일 전체를 못 읽는다."""
    first_sub = None
    first_node = None
    for m in re.finditer(r"^\[(\w+)", text, re.M):
        tag = m.group(1)
        line = text[: m.start()].count("\n") + 1
        if tag == "sub_resource" and first_sub is None:
            first_sub = line
        elif tag == "node" and first_node is None:
            first_node = line
        elif tag == "ext_resource":
            if first_sub is not None:
                errors.append(
                    f"{rel(path)}:{line}: ext_resource 가 sub_resource(={first_sub}행) 뒤에 있다 "
                    f"— 파일 전체가 로드 실패한다. 위로 옮길 것")
            elif first_node is not None:
                errors.append(
                    f"{rel(path)}:{line}: ext_resource 가 node(={first_node}행) 뒤에 있다 "
                    f"— 파일 전체가 로드 실패한다. 위로 옮길 것")


def check_resource_refs(path: str, text: str) -> None:
    defined: set[str] = set()
    for m in re.finditer(r"\[ext_resource ([^\]]*)\]", text):
        attrs = m.group(1)
        idm = re.search(r'id="([^"]+)"', attrs)
        pathm = re.search(r'path="(res://[^"]+)"', attrs)
        if idm:
            defined.add(idm.group(1))
        if pathm and not os.path.exists(res_to_path(pathm.group(1))):
            errors.append(f"{rel(path)}: ext_resource 경로 없음 -> {pathm.group(1)}")
    for m in re.finditer(r'\[sub_resource [^\]]*id="([^"]+)"', text):
        defined.add(m.group(1))
    for m in re.finditer(r'(?:ExtResource|SubResource)\("([^"]+)"\)', text):
        if m.group(1) not in defined:
            errors.append(f"{rel(path)}: 정의 안 된 리소스 id 참조 -> {m.group(1)}")


def check_tres_properties(path: str, text: str) -> None:
    """.tres 가 쓰는 속성이 스크립트에 선언돼 있는지. 선언이 없으면 로드는 조용히 넘어가고
    실행 중에 터진다 — 가장 잡기 어려운 부류라 여기서 막는다."""
    header = re.search(r"\[gd_resource ([^\]]*)\]", text)
    if not header or 'script_class="' not in header.group(1):
        return
    script_ref = re.search(r'\[ext_resource type="Script" path="(res://[^"]+)"', text)
    if not script_ref:
        return
    gd_path = res_to_path(script_ref.group(1))
    if not os.path.exists(gd_path):
        return
    props = exported_properties(gd_path)
    if not props:
        return
    body = text.split("[resource]", 1)
    if len(body) < 2:
        return
    for m in re.finditer(r"^(\w+)\s*=", body[1], re.M):
        name = m.group(1)
        if name in BUILTIN_RESOURCE_PROPS or name in props:
            continue
        errors.append(
            f"{rel(path)}: '{name}' 속성이 {os.path.basename(gd_path)} 에 @export 로 선언돼 있지 않다 "
            f"— 실행 중 접근하면 크래시한다")


def main() -> int:
    scenes = walk("**/*.tscn")
    resources = walk("**/*.tres")
    scripts = walk("**/*.gd")

    for path in scenes + resources:
        text = io.open(path, encoding="utf-8").read()
        check_tag_order(path, text)
        check_resource_refs(path, text)
    for path in resources:
        check_tres_properties(path, io.open(path, encoding="utf-8").read())

    for path in scripts:
        text = io.open(path, encoding="utf-8").read()
        for open_ch, close_ch in (("(", ")"), ("[", "]"), ("{", "}")):
            if text.count(open_ch) != text.count(close_ch):
                errors.append(f"{rel(path)}: 괄호 불균형 '{open_ch}{close_ch}' "
                              f"({text.count(open_ch)} vs {text.count(close_ch)})")
        for i, line in enumerate(text.splitlines(), 1):
            if line[:1] == " " and line.strip():
                warns.append(f"{rel(path)}:{i}: 공백 들여쓰기(Godot 관례는 탭)")
                break

    project_godot = os.path.join(ROOT, "project.godot")
    if os.path.exists(project_godot):
        pg = io.open(project_godot, encoding="utf-8").read()
        section = re.search(r"\[autoload\](.*?)(\n\[|\Z)", pg, re.S)
        if section:
            for line in section.group(1).strip().splitlines():
                if "=" not in line:
                    continue
                name, value = line.split("=", 1)
                target = value.strip().strip('"').lstrip("*")
                if target.startswith("res://") and not os.path.exists(res_to_path(target)):
                    errors.append(f"[autoload] {name.strip()} -> 파일 없음: {target}")
        main_scene = re.search(r'run/main_scene="([^"]+)"', pg)
        if main_scene and not os.path.exists(res_to_path(main_scene.group(1))):
            errors.append(f"[main_scene] 없음: {main_scene.group(1)}")

    print(f"검사: 씬 {len(scenes)} · 리소스 {len(resources)} · 스크립트 {len(scripts)}")
    print(f"\n오류 {len(errors)}건")
    for e in errors:
        print("  X", e)
    print(f"경고 {len(warns)}건")
    for w in warns:
        print("  !", w)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
