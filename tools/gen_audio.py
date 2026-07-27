#!/usr/bin/env python3
"""플레이스홀더 효과음·BGM을 합성해 assets/audio/ 에 WAV 로 쓴다.

CC0 클립을 받아올 수 없는 환경이라 직접 만든다. 무속 타악(징·장구·방울)의 성질을
흉내낸 것이라 톤은 얼추 맞고, 나중에 진짜 에셋으로 갈아 끼울 때 코드는 바꾸지 않는다
(design.md 9절 — AudioManager 는 키만 안다).

실행: python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def write_wav(name: str, samples, loop: bool = False) -> None:
    path = os.path.join(OUT_DIR, name)
    peak = max(1e-9, max(abs(s) for s in samples))
    # 클리핑 없이 여유를 두고 정규화한다.
    gain = 0.82 / peak
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(frames)
    print("  %-22s %6.2fs%s" % (name, len(samples) / RATE, "  (loop)" if loop else ""))


def env(i: int, n: int, attack: float, decay: float) -> float:
    """짧은 어택 + 지수 감쇠. 타악은 어택이 거의 없어야 때리는 느낌이 난다."""
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = math.exp(-t / decay)
    return a * d


def noise_burst(dur: float, decay: float, lowpass: float = 0.5):
    """필터링한 노이즈. 베기·바람 소리의 몸통."""
    n = int(RATE * dur)
    out = []
    prev = 0.0
    for i in range(n):
        raw = random.uniform(-1.0, 1.0)
        prev = prev + (raw - prev) * lowpass
        out.append(prev * env(i, n, 0.001, decay))
    return out


def partials(dur: float, freqs, amps, decays, attack: float = 0.002):
    """비조화 배음 합성. 징·종처럼 배음이 정수배가 아닌 금속성 소리에 쓴다."""
    n = int(RATE * dur)
    out = [0.0] * n
    for f, a, d in zip(freqs, amps, decays):
        w = 2.0 * math.pi * f / RATE
        for i in range(n):
            out[i] += a * math.sin(w * i) * env(i, n, attack, d)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def sweep(dur: float, f0: float, f1: float, decay: float, attack: float = 0.002):
    """주파수가 미끄러지는 톤. 픽업·레벨업의 '올라가는' 느낌."""
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        phase += 2.0 * math.pi * f / RATE
        out.append(math.sin(phase) * env(i, n, attack, decay))
    return out


def build() -> None:
    random.seed(20260722)  # 재생성해도 같은 소리가 나오도록
    os.makedirs(OUT_DIR, exist_ok=True)
    print("효과음 합성 →", OUT_DIR)

    # 작두 베기: 짧은 쇳소리 + 바람. 자주 나므로 짧고 건조하게.
    write_wav("sfx_jakdu_swing.wav", mix(
        noise_burst(0.16, 0.045, lowpass=0.35),
        partials(0.16, [1850, 2600], [0.30, 0.18], [0.035, 0.025]),
    ))

    # 타격: 둔탁한 몸통 + 살짝의 금속. 처치보다 가벼워야 한다.
    write_wav("sfx_hit.wav", mix(
        partials(0.12, [180, 260], [0.55, 0.30], [0.045, 0.030]),
        noise_burst(0.08, 0.020, lowpass=0.25),
    ))

    # 치명: 타격보다 밝고 길게. 금색 번쩍임과 짝이 맞아야 한다.
    write_wav("sfx_crit.wav", mix(
        partials(0.34, [520, 1180, 1790, 2630], [0.42, 0.30, 0.20, 0.12],
                 [0.16, 0.12, 0.09, 0.06]),
        noise_burst(0.10, 0.025, lowpass=0.45),
    ))

    # 처치: 넋이 흩어지는 소리. 낮게 깔렸다가 사라진다.
    write_wav("sfx_enemy_die.wav", mix(
        partials(0.30, [140, 210, 330], [0.50, 0.28, 0.16], [0.10, 0.08, 0.05]),
        noise_burst(0.22, 0.075, lowpass=0.18),
    ))

    # XP 젬: 짧고 맑은 방울. 초당 여러 번 나므로 아주 짧게.
    write_wav("sfx_pickup.wav", sweep(0.10, 880, 1460, 0.035))

    # 레벨업: 방울 두 번 + 여운. 판이 멈추는 순간이라 조금 길어도 된다.
    write_wav("sfx_level_up.wav", mix(
        sweep(0.55, 660, 990, 0.22),
        [0.0] * int(RATE * 0.09) + sweep(0.46, 990, 1320, 0.20),
        partials(0.6, [1320, 1980], [0.16, 0.10], [0.25, 0.18], attack=0.004),
    ))

    # 신 선택 확정: 낮은 징 한 번. 무게를 준다.
    write_wav("sfx_god_pick.wav", partials(
        0.9, [196, 293, 445, 611, 892], [0.50, 0.30, 0.22, 0.14, 0.09],
        [0.42, 0.30, 0.22, 0.16, 0.10], attack=0.004))

    # 합 성립: 징 + 상승 스윕. 이 게임에서 가장 기분 좋아야 하는 소리.
    write_wav("sfx_synergy.wav", mix(
        partials(1.2, [147, 221, 330, 494, 740], [0.46, 0.30, 0.24, 0.16, 0.10],
                 [0.55, 0.40, 0.30, 0.22, 0.14], attack=0.003),
        [0.0] * int(RATE * 0.05) + sweep(0.7, 440, 1320, 0.30),
    ))

    # 작두타기 발동: 큰 징. 강림의 순간.
    write_wav("sfx_taegi.wav", mix(
        partials(1.6, [110, 165, 247, 370, 555, 831],
                 [0.52, 0.34, 0.26, 0.18, 0.12, 0.08],
                 [0.75, 0.55, 0.42, 0.30, 0.20, 0.13], attack=0.003),
        noise_burst(0.35, 0.10, lowpass=0.12),
    ))

    # 피격: 탁한 저음. 아프다는 신호라 듣기 좋으면 안 된다.
    write_wav("sfx_player_hurt.wav", mix(
        partials(0.22, [98, 143], [0.55, 0.32], [0.075, 0.050]),
        noise_burst(0.14, 0.035, lowpass=0.10),
    ))

    # 관문 클리어 / 사망
    write_wav("sfx_gate_clear.wav", mix(
        partials(1.4, [262, 392, 523, 784], [0.42, 0.32, 0.24, 0.15],
                 [0.60, 0.45, 0.34, 0.22], attack=0.005),
        [0.0] * int(RATE * 0.18) + sweep(0.9, 523, 1046, 0.38),
    ))
    write_wav("sfx_player_die.wav", mix(
        partials(1.8, [131, 98, 73], [0.50, 0.34, 0.22], [0.80, 0.60, 0.45], attack=0.006),
        noise_burst(0.9, 0.30, lowpass=0.08),
    ))

    _build_bgm()


def _build_bgm() -> None:
    """앰비언트 루프. 8초 드론 + 느린 북. 이어 붙였을 때 튐이 없도록 루프 길이에 맞춰
    주파수를 정수 주기로 고른다."""
    dur = 8.0
    n = int(RATE * dur)
    out = [0.0] * n

    # 드론: 루프 경계에서 위상이 맞도록 주기 수를 정수로 잡는다.
    for cycles, amp in ((int(55 * dur), 0.30), (int(82.5 * dur), 0.18), (int(110 * dur), 0.12)):
        w = 2.0 * math.pi * cycles / n
        for i in range(n):
            out[i] += amp * math.sin(w * i)

    # 느린 진폭 흔들림(숨). 이것도 루프에 딱 맞게.
    for i in range(n):
        out[i] *= 0.72 + 0.28 * math.sin(2.0 * math.pi * 2 * i / n)

    # 북: 2초마다 한 번. 마지막 타는 루프 끝을 넘지 않게 여유를 둔다.
    for beat in range(4):
        start = int(RATE * 2.0 * beat)
        hit = partials(0.9, [62, 93, 140], [0.60, 0.30, 0.16], [0.22, 0.15, 0.10])
        for i, s in enumerate(hit):
            if start + i < n:
                out[start + i] += s * 0.55

    write_wav("bgm_gate_loop.wav", out, loop=True)


if __name__ == "__main__":
    build()
