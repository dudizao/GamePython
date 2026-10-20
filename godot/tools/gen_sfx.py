#!/usr/bin/env python3
"""Gera os efeitos sonoros e a música (síntese simples, chiptune) em assets/audio/*.wav.
Uso: python3 tools/gen_sfx.py   (roda a partir da pasta godot/)
Os arquivos gerados podem ser trocados por sons profissionais com o mesmo nome."""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
random.seed(7)


def env(n, attack=0.005, release=0.05, i=0):
    t = i / SR
    dur = n / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (dur - t) / release) if release > 0 else 1.0
    return max(0.0, min(a, r))


def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "tri":
        return 4 * abs(p - 0.5) - 1
    if kind == "saw":
        return 2 * p - 1
    return 0.0


def tone(freq, dur, kind="square", vol=0.5, attack=0.004, release=0.06, f_end=None, vib=0.0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq if f_end is None else freq + (f_end - freq) * (i / n)
        if vib:
            f *= 1 + 0.03 * math.sin(2 * math.pi * vib * i / SR)
        phase += f / SR
        out.append(osc(kind, phase) * vol * env(n, attack, release, i))
    return out


def noise(dur, vol=0.5, attack=0.002, release=0.08, lowpass=1.0):
    n = int(SR * dur)
    out = []
    last = 0.0
    for i in range(n):
        x = random.uniform(-1, 1)
        last = last + lowpass * (x - last)
        out.append(last * vol * env(n, attack, release, i))
    return out


def silence(dur):
    return [0.0] * int(SR * dur)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def cat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def at(track, offset):
    return silence(offset) + track


def save(name, samples, peak=0.85):
    m = max(1e-6, max(abs(s) for s in samples))
    scale = min(1.0, peak / m) if m > peak else 1.0
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    return path


def note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def arp(notes, step, kind="square", vol=0.4, rel=0.08):
    return cat(*[tone(note(n), step, kind, vol, release=rel) for n in notes])


def build():
    os.makedirs(OUT, exist_ok=True)
    save("click", tone(900, 0.05, "square", 0.3, release=0.03))
    rattle = []
    for k in range(7):
        rattle += noise(0.035, 0.7, lowpass=0.6) + silence(0.02 + 0.01 * k)
    save("dice", rattle + tone(520, 0.08, "tri", 0.4))
    save("step", tone(140, 0.07, "sine", 0.7, release=0.05, f_end=90))
    save("hit", mix(noise(0.12, 0.8, lowpass=0.5), tone(160, 0.16, "sine", 0.8, f_end=70)))
    save("magic", mix(tone(500, 0.35, "sine", 0.4, f_end=1500, vib=18), tone(750, 0.35, "tri", 0.25, f_end=2000, vib=12)))
    save("dodge", noise(0.2, 0.5, attack=0.05, release=0.15, lowpass=0.18))
    save("heal", arp([72, 76, 79, 84], 0.07, "sine", 0.5, 0.1))
    save("potion", cat(tone(300, 0.05, "sine", 0.5, f_end=600), tone(450, 0.05, "sine", 0.5, f_end=800), tone(600, 0.08, "sine", 0.5, f_end=1000)))
    save("pickup", arp([79, 84], 0.06, "square", 0.35))
    save("trophy", arp([72, 76, 79, 84, 88], 0.08, "square", 0.4) )
    save("equip", mix(tone(620, 0.09, "tri", 0.5, release=0.06), at(tone(940, 0.12, "tri", 0.4, release=0.08), 0.05)))
    save("card", arp([84, 88, 91], 0.05, "tri", 0.4, 0.1))
    save("trap_set", cat(tone(220, 0.04, "square", 0.4), silence(0.05), tone(180, 0.06, "square", 0.4)))
    save("trap_trigger", mix(noise(0.08, 0.9, lowpass=0.8), tone(700, 0.3, "saw", 0.5, f_end=120)))
    save("battle_start", mix(tone(110, 0.45, "saw", 0.5, f_end=220, release=0.15), tone(165, 0.45, "saw", 0.3, f_end=330, release=0.15)))
    save("death", mix(tone(400, 0.6, "saw", 0.5, f_end=60, release=0.2), noise(0.25, 0.3, lowpass=0.3)))
    save("level_up", arp([67, 72, 76, 79, 84, 88], 0.07, "square", 0.4, 0.1))
    save("victory", cat(arp([72, 72, 72, 76], 0.12, "square", 0.45), arp([79, 76, 79, 84], 0.16, "square", 0.45, 0.2)))
    save("defeat", cat(arp([69, 66, 62, 57], 0.2, "tri", 0.5, 0.2)))
    save("ring_warning", cat(tone(660, 0.14, "square", 0.4), tone(520, 0.14, "square", 0.4), tone(660, 0.14, "square", 0.4), tone(520, 0.14, "square", 0.4)))
    save("ring_close", mix(noise(0.8, 0.8, attack=0.05, release=0.4, lowpass=0.05), tone(55, 0.8, "sine", 0.9, f_end=35, release=0.3)))
    save("undead", mix(tone(300, 0.8, "tri", 0.5, f_end=110, vib=7, release=0.3), tone(305, 0.8, "sine", 0.3, f_end=112, vib=5, release=0.3)))
    save("turn", cat(tone(880, 0.08, "sine", 0.4, release=0.07), tone(1175, 0.14, "sine", 0.4, release=0.12)))
    save("flee", cat(tone(500, 0.05, "square", 0.3), tone(420, 0.05, "square", 0.3), tone(340, 0.05, "square", 0.3), tone(260, 0.08, "square", 0.3)))
    save("error", tone(160, 0.14, "square", 0.35, release=0.1))
    # --- dados: chocalho, batidas, mão, comemorações ---
    save("rattle", dice_rattle())
    for k, (f0, f1) in enumerate([(430, 260), (520, 300), (380, 230)]):
        save("clack%d" % (k + 1), mix(noise(0.03, 0.9, attack=0.0005, release=0.025, lowpass=0.75),
                                      tone(f0, 0.07, "tri", 0.7, release=0.06, f_end=f1),
                                      tone(f0 * 2.3, 0.02, "square", 0.25, release=0.015)))
    save("whoosh", cat(noise(0.28, 0.45, attack=0.09, release=0.19, lowpass=0.22)))
    save("settle", mix(noise(0.05, 0.3, release=0.04, lowpass=0.4), tone(180, 0.09, "sine", 0.4, release=0.08, f_end=110)))
    save("double_gold", mix(arp([79, 84, 88, 91, 96], 0.07, "square", 0.35, 0.12),
                            at(arp([91, 96, 100, 103], 0.06, "sine", 0.3, 0.2), 0.12)))
    save("double_one", cat(tone(220, 0.16, "saw", 0.45, release=0.1, f_end=180), tone(165, 0.16, "saw", 0.45, release=0.1, f_end=120),
                           mix(tone(98, 0.4, "saw", 0.5, release=0.3, f_end=60), noise(0.2, 0.25, lowpass=0.2))))
    save("music", music())


def dice_rattle():
    """Chocalho de dados na mão: cliques curtos, mais densos no meio (envelope em arco)."""
    total = 0.5
    out = [0.0] * int(SR * total)
    n = 34
    for i in range(n):
        t = random.uniform(0.02, total - 0.04)
        env_amp = math.sin(math.pi * t / total) ** 0.8
        f = random.uniform(900, 2600)
        click = mix(tone(f, 0.014, "square", 0.28, attack=0.0005, release=0.012),
                    noise(0.012, 0.35, attack=0.0003, release=0.01, lowpass=0.8))
        start = int(SR * t)
        for j, v in enumerate(click):
            if start + j < len(out):
                out[start + j] += v * env_amp
    return out


def music():
    bpm = 112
    beat = 60.0 / bpm
    # Am - F - C - G, quatro vezes (16 compassos de 4 tempos)
    chords = [(57, [69, 72, 76]), (53, [65, 69, 72]), (48, [67, 72, 76]), (55, [67, 71, 74])]
    melody = [76, 79, 81, 79, 76, 74, 72, 74]
    bars = 16
    total = int(SR * beat * 4 * bars)
    out = [0.0] * total
    pos = 0
    for b in range(bars):
        bass_n, tri = chords[b % 4]
        for q in range(4):  # baixo em colcheias
            for h in range(2):
                t = tone(note(bass_n - 12 + (7 if h and q % 2 else 0)), beat / 2 * 0.9, "tri", 0.45, release=0.05)
                start = pos + int(SR * (q * beat + h * beat / 2))
                for i, v in enumerate(t):
                    out[start + i] += v
        for q in range(8):  # arpejo
            n = tri[q % 3] + (12 if (q // 3) % 2 else 0)
            t = tone(note(n), beat / 2 * 0.8, "square", 0.12, release=0.06)
            start = pos + int(SR * (q * beat / 2))
            for i, v in enumerate(t):
                out[start + i] += v
        if b >= 4:  # melodia entra no 5º compasso
            for q in range(4):
                n = melody[(b * 4 + q) % len(melody)]
                t = tone(note(n), beat * 0.9, "sine", 0.18, release=0.12, vib=5)
                start = pos + int(SR * q * beat)
                for i, v in enumerate(t):
                    out[start + i] += v
        for q in range(8):  # chimbal suave
            t = noise(0.03, 0.12, release=0.02, lowpass=0.9)
            start = pos + int(SR * (q * beat / 2))
            for i, v in enumerate(t):
                out[start + i] += v
        pos += int(SR * beat * 4)
    return out[:total]


if __name__ == "__main__":
    build()
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)) // 1024, "KB")
