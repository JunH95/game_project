# 아트 생성 프롬프트 팩

이 문서는 **AI 이미지 생성으로 게임 아트를 뽑을 때 쓰는 프롬프트 정본**이다.
톤은 `vision.md` 4절(어둡고 신령하되 무겁지만은 않게, 현대 각색 우선)을 따른다.

## 0. 이걸 왜 문서로 두는가

같은 프롬프트로 뽑아야 9신·적·무기가 **한 화면에서 한 세트로 보인다.** 신마다 다른 프롬프트로
따로 뽑으면 선 굵기·채도·시점이 제각각이라 게임이 아니라 이미지 모음이 된다.
그래서 **스타일 앵커(§1)는 절대 고치지 말고**, 피사체 문장(§3~)만 바꾼다.

스타일을 바꾸고 싶으면 §1을 고치고 **전부 다시 뽑는다.** 일부만 다시 뽑지 않는다.

---

## 1. 스타일 앵커 (모든 프롬프트 앞에 그대로 붙인다)

```
Korean shamanic scroll painting (musindo) style, reimagined for a modern video game.
Flat mineral-pigment color blocks with bold ink outlines, minimal gradient shading.
Strict frontal iconic composition, symmetrical, hieratic stillness.
Palette limited to: cinnabar red #B3352A, ultramarine #25407A, gold leaf #D9A441,
ink black #1B1B24, shell white #F2EDE3. Aged hanji paper texture in the pigment.
Dark, numinous, slightly eerie but not gory. Clean silhouette readable at small size.
Centered subject, plain transparent background, no scenery, no text, no signature.
```

### 네거티브 프롬프트 (지원하는 도구에서만)

```
photorealistic, 3d render, anime, chibi, western fantasy, cel shading, soft airbrush,
busy background, landscape, drop shadow, watermark, signature, text, letters, calligraphy,
extra limbs, blurry, low contrast, pastel colors, neon, cluttered composition
```

> `calligraphy`를 뺀 이유가 궁금할 수 있는데 — 부적(§5)만은 획이 필요하다.
> 부적 프롬프트에서는 네거티브에서 `calligraphy, text, letters`를 **빼고** 돌린다.

---

## 2. 출력 규격 · 파일 배치

| 종류 | 캔버스 | 배경 | 저장 경로 | 물리는 곳 |
|---|---|---|---|---|
| 신 초상 | 768×768 | 투명 PNG | `assets/sprites/gods/<id>.png` | `data/gods/<id>.tres` → `icon` |
| 적 | 512×512 | 투명 PNG | `assets/sprites/enemies/<id>.png` | `data/enemies/<id>.tres` → `texture` |
| 플레이어 | 512×512 | 투명 PNG | `assets/sprites/actors/player.png` | `player.tscn` → `texture` |
| 부적 투사체 | 256×256 | 투명 PNG | `assets/sprites/actors/bujeok.png` | `bujeok.tscn` → `texture` |
| 넋 조각(XP) | 256×256 | 투명 PNG | `assets/sprites/actors/xp_gem.png` | `xp_gem.tscn` → `texture` |

**크기는 신경 쓰지 않아도 된다.** `PlaceholderArt.draw_texture_centered()`가 액터 반지름에 맞춰
긴 변을 자동으로 줄인다(적은 `radius × 2.6`, 플레이어는 `RADIUS × 3.0`). 원점은 항상 그림 중앙이므로
피벗 설정도 필요 없다 — **피사체를 캔버스 정중앙에** 두기만 하면 된다.

**방향 규약**: 부적은 `rotation`이 진행 방향을 맡으므로 그림에서 **코끝이 오른쪽(+X)** 을 향해야 한다.
급살 원귀도 마찬가지로 오른쪽을 보게 뽑는다. 나머지는 정면.

**Godot 임포트**: 도형 시절 톤을 유지하려면 부드럽게(기본 `Filter` 켜짐) 두는 게 낫다.
픽셀 아트로 갈 거면 임포트 탭에서 `Filter` 끄고 `Mipmaps` 끈다. `.import` 파일은 커밋한다.

---

## 3. 신 초상 (몸주 3 + 모시는 신 3)

3택1·몸주 선택 UI에 뜬다. **상반신 위주**로 뽑아야 작은 버튼 안에서 얼굴이 읽힌다.

### 작도대신 — 金 · 작두

```
<스타일 앵커>
A shaman deity standing barefoot upon the upturned blades of two ceremonial fodder
knives (jakdu). White ritual robe with a cinnabar sash, sleeves flaring. Face calm and
unblinking, eyes rimmed in gold. Cold steel-white aura, metal element. Blades gleam
beneath the feet. Upper body composition.
```

### 최영장군 — 火 · 언월도

```
<스타일 앵커>
A general deity in lacquered scale armor, holding a crescent-moon glaive (eonwoldo)
upright. Fierce bearded face, wide-set glaring eyes, cinnabar war banner behind the
shoulders. Embers and heat-shimmer, fire element. Upper body composition.
```

### 칠성신 — 水 · 부적

```
<스타일 앵커>
A star deity robed in deep ultramarine, the seven stars of the Big Dipper burning in an
arc above the head. Serene androgynous face, hands folded holding a paper talisman.
Cool water element, faint mist. Upper body composition.
```

### 산신 — 木

```
<스타일 앵커>
An old mountain deity with a long white beard, seated with one hand resting on the head
of a stylized tiger. Green-brown robe, pine branches, wood element. Kindly but remote
expression. Upper body composition.
```

### 월광보살 — 水

```
<스타일 앵커>
A moonlight bodhisattva, luminous pale face lit from below, a full moon disc as halo
behind the head. Flowing ultramarine and shell-white robes, crescent ornaments.
Half-lidded serene eyes, water element. Upper body composition.
```

### 신장 — 土

```
<스타일 앵커>
A guardian general deity in heavy earth-brown armor, arms crossed, commanding lesser
spirits. Broad square face, thick brows, stone-like stillness, earth element.
Small subdued wisps kneeling at the base. Upper body composition.
```

> 로스터 확장(9몸주) 때 여기에 계속 추가한다. `design.md` 3-4의 신이 늘면 이 절도 같이 는다.

---

## 4. 적

### 추격 원귀 (`chaser`) — 실루엣 `wraith`

```
<스타일 앵커>
A restless vengeful spirit (wonhon). Pale round head with two hollow glowing eyes,
no legs — the body dissolves downward into a tapering smear of dark red smoke.
Long unbound black hair. Cinnabar-red dominant. Small, readable at 16 pixels.
```

### 급살 원귀 (`rusher`) — 실루엣 `rusher` · **오른쪽을 향하게**

```
<스타일 앵커>
A lunging spirit shaped like an arrowhead, streaking to the right, body stretched by
speed into a thin wedge with a trailing orange smear. Sharp, aggressive, almost no mass.
Facing right. Small, readable at 12 pixels.
```

### 업덩이 (`tank`) — 실루엣 `hulk`

```
<스타일 앵커>
A heavy lumpen mass of accumulated karma, dark maroon, formed of fused overlapping
bodies. Cracks across the surface leak cinnabar light from within. Slow, immovable,
oppressive. Small sunken glowing eyes near the top. Readable at 32 pixels.
```

---

## 5. 소품

### 부적 투사체 — **코끝이 오른쪽**, 네거티브에서 `calligraphy, text, letters` 제거

```
<스타일 앵커>
A single Korean paper talisman (bujeok): a narrow strip of yellow mulberry paper
covered in vermilion brushed sigil strokes. Flying horizontally to the right, edges
curling from the wind, faint gold trail behind. Isolated object.
```

### 넋 조각 (XP)

```
<스타일 앵커>
A small faceted shard of soul-light, pale cyan and translucent, floating. Sharp
diamond silhouette with an inner glow. Isolated object, no background.
```

### 플레이어 (바리)

```
<스타일 앵커>
A young shaman seen from a high top-down angle, standing upright. White ritual hanbok
with a cinnabar waist sash and ultramarine collar, small brass bells at the crown.
Compact readable silhouette, arms close to the body, no weapon in hand.
Facing the viewer. Readable at 24 pixels.
```

---

## 6. 도구별 요령

| 도구 | 강점 | 주의 |
|---|---|---|
| Midjourney | 무신도 질감·통일감이 가장 잘 나온다 | 투명 배경 불가 → 단색 배경으로 뽑고 따로 누끼 |
| Nano Banana (Gemini) | 투명 배경·수정 지시가 잘 먹는다 | 한 번에 여러 장 뽑으면 톤이 흔들린다 |
| DALL·E / GPT Image | 지시 이해가 정확, 투명 배경 가능 | 채도가 높게 나와 팔레트를 벗어나기 쉽다 |
| Stable Diffusion + LoRA | 9신 톤 통일에 가장 유리(같은 시드·LoRA) | 세팅 비용이 크다 |

**통일 요령 하나**: 먼저 작도대신 한 장을 마음에 들 때까지 뽑고, 그 이미지를 **레퍼런스로 물려서**
나머지를 뽑는다(`--cref` / 이미지 첨부). 프롬프트만으로 6장을 맞추는 것보다 훨씬 잘 붙는다.

**누끼**: 배경이 남으면 `rembg`(파이썬)나 도구 내장 배경 제거로 지운다. 가장자리에 흰 테가 남으면
게임 안에서 눈에 띈다 — 지우고 나서 어두운 배경에 얹어 확인한다.

---

## 6-1. 톤 통일은 눈이 아니라 코드로 — `tools/palettize.py`

AI 생성의 유일하고 치명적인 약점은 **여러 장의 톤이 흔들리는 것**이다. 9장을 따로 뽑으면
채도·색조가 제각각이라 한 게임처럼 보이지 않는다. 프롬프트로 맞추는 데는 한계가 있으므로
**색은 사후에 코드로 가둔다.**

```
python3 tools/palettize.py assets/sprites/gods/*.png
python3 tools/palettize.py one.png --out preview.png --shades 5
```

모든 픽셀을 광물 안료 팔레트로 매핑한다. 단순 최근접이 아니라 기본 5색에서 **명도 단계를
파생시킨 램프**에 매핑하므로 형태(명암 구조)는 남고 색만 팔레트 안에 갇힌다.
`--shades` 가 작을수록 판판해져 양식이 강해지고, 클수록 원본 형태가 잘 남는다(기본 4).

- 원본은 따로 보관해 두는 편이 좋다 — 제자리에서 덮어쓰므로 되돌릴 수 없다.
- 반투명 가장자리는 지운다. 누끼 잔여물이 게임 안에서 뿌옇게 번져 보이기 때문이다.
- 이 팔레트는 `tools/blender/rig.py` 와 같은 값이다. 그래야 렌더한 타일과 그린 초상이
  한 화면에서 한 세트로 보인다.

---

## 7. 적용 절차 (그림이 나온 뒤)

0. `python3 tools/palettize.py <파일>` 로 팔레트를 강제한다 (§6-1)
1. §2의 경로에 PNG 저장
2. Godot 을 열면 `.import` 가 생성된다 → **PNG 와 `.import` 를 같이 커밋**
3. 인스펙터에서 해당 `.tres`/`.tscn` 의 `texture`(신은 `icon`)에 물린다
4. 실행해서 크기·정렬 확인. 도형 시절과 크기가 크게 다르면 `radius` 가 아니라
   **그림 여백**을 의심한다(피사체가 캔버스에서 작게 잡힌 경우)

**코드는 건드리지 않는다.** `PlaceholderArt.draw_texture_centered()` 가 각 액터 `_draw()` 첫 줄에서
텍스처 유무를 보고 갈라주므로, 물리는 순간 도형이 자동으로 비켜난다. 한 종류만 먼저 교체해도 되고,
마음에 안 들면 `texture` 를 비우면 도형으로 되돌아온다.
