#!/usr/bin/env python3
"""저승·바리데기 경량 프로젝트 검증기 (실제 Godot 없이 손수 쓴 씬/스크립트의 취약점 검사).

잡는 것: .tscn 의 ext_resource 경로 존재 여부, ExtResource/SubResource id 참조 해결,
GDScript 괄호 균형·공백 들여쓰기(탭 권장 위반). 못 잡는 것: 런타임 로직·Godot API 오용.
"""
import os, re, sys, glob

ROOT = "/home/user/game_project"
errors, warns = [], []


def res_to_path(res: str) -> str:
    return os.path.join(ROOT, res[len("res://"):])


# --- GDScript 라이트 린트 ---
for gd in sorted(glob.glob(ROOT + "/**/*.gd", recursive=True)):
    if "/addons/" in gd:
        continue
    text = open(gd, encoding="utf-8").read()
    for o, c in (("(", ")"), ("[", "]"), ("{", "}")):
        if text.count(o) != text.count(c):
            errors.append(f"{gd}: 괄호 불균형 '{o}{c}' ({text.count(o)} vs {text.count(c)})")
    for i, line in enumerate(text.splitlines(), 1):
        if line[:1] == " " and line.strip():
            warns.append(f"{gd}:{i}: 공백 들여쓰기 발견(Godot 관례=탭)")
            break

# --- .tscn 리소스 배선 검사 ---
for tscn in sorted(glob.glob(ROOT + "/**/*.tscn", recursive=True)):
    if "/addons/" in tscn:
        continue
    text = open(tscn, encoding="utf-8").read()
    defined = set()
    for m in re.finditer(r"\[ext_resource ([^\]]*)\]", text):
        attrs = m.group(1)
        idm = re.search(r'id="([^"]+)"', attrs)
        pathm = re.search(r'path="(res://[^"]+)"', attrs)
        if idm:
            defined.add(idm.group(1))
        if pathm and not os.path.exists(res_to_path(pathm.group(1))):
            errors.append(f"{tscn}: ext_resource 경로 없음 -> {pathm.group(1)}")
    for m in re.finditer(r'\[sub_resource [^\]]*id="([^"]+)"', text):
        defined.add(m.group(1))
    for m in re.finditer(r'(?:ExtResource|SubResource)\("([^"]+)"\)', text):
        if m.group(1) not in defined:
            errors.append(f"{tscn}: 정의 안 된 리소스 id 참조 -> {m.group(1)}")

# --- .tres 리소스 검사(있으면) ---
for tres in sorted(glob.glob(ROOT + "/data/**/*.tres", recursive=True)):
    text = open(tres, encoding="utf-8").read()
    defined = set()
    for m in re.finditer(r"\[ext_resource ([^\]]*)\]", text):
        idm = re.search(r'id="([^"]+)"', m.group(1))
        pathm = re.search(r'path="(res://[^"]+)"', m.group(1))
        if idm:
            defined.add(idm.group(1))
        if pathm and not os.path.exists(res_to_path(pathm.group(1))):
            errors.append(f"{tres}: ext_resource 경로 없음 -> {pathm.group(1)}")
    for m in re.finditer(r'(?:ExtResource|SubResource)\("([^"]+)"\)', text):
        if m.group(1) not in defined and not re.search(rf'id="{re.escape(m.group(1))}"', text):
            errors.append(f"{tres}: 정의 안 된 리소스 id 참조 -> {m.group(1)}")

print(f"검사: {len(glob.glob(ROOT+'/**/*.gd', recursive=True))} gd / "
      f"{len(glob.glob(ROOT+'/**/*.tscn', recursive=True))} tscn / "
      f"{len(glob.glob(ROOT+'/data/**/*.tres', recursive=True))} tres")
print(f"\nERRORS: {len(errors)}")
for e in errors:
    print("  ✗", e)
print(f"WARNINGS: {len(warns)}")
for w in warns:
    print("  !", w)
sys.exit(1 if errors else 0)
