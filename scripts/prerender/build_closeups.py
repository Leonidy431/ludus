"""The examine videos of episode 1 (TABOO 0.019, 0.020): voice, pack
sources and previews from the turntable frames and the chorus' lines.

For each examined thing of godot/data/pilot-1.json:

* its narrator's line comes from godot/data/pilot-narration.json (the
  chorus' text, TABOO 0.020);
* the line is spoken by the DRAFT voice (Piper, voice "irina", data of
  RHVoice under GPLv2; operator's order of 2026-10-02 «генери … с
  голосом»), written as Ogg Vorbis to the pack source
  godot/packs/closeups-ep1/closeups/<id>/voice_ru.ogg; a live recorded
  voice replaces it (Д-22, TABOO 0.019 item 5);
* a preview MP4 for the operator: the turntable frames at 8 fps, the
  voice, the line as a subtitle and the mark "черновой голос", in
  docs/audit/2026-10-02/closeup-<id>.mp4.

    python3 scripts/prerender/build_closeups.py

Constitution: ФОРМА (the thing turning in true light, and a word about
the man who looks at it) → ДЕЙСТВИЕ (render, speak, pack) → ЦЕЛЬ (the
close-up closes its scene and hands it to the next, TABOO 0.020).
"""

import json
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PILOT = ROOT / 'godot' / 'data' / 'pilot-1.json'
NARRATION = ROOT / 'godot' / 'data' / 'pilot-narration.json'
PACK = ROOT / 'godot' / 'packs' / 'closeups-ep1' / 'closeups'
FRAMES = ROOT / 'build' / 'turntable'
PREVIEW = ROOT / 'docs' / 'audit' / '2026-10-02'
PIPER = '/home/user/tts-venv/bin/piper'
TTS = Path('/tmp/claude-0/-home-user-ludus/00bfaacc-916a-5377-9b22-'
           '7beb9ad7416e/scratchpad/tts')
# One draft voice a language, each with a licence that allows a
# commercial game (lessac: research only, ryan: non-commercial —
# rejected; Д-22).
VOICES = {
    'ru': TTS / 'ru-irinia-medium.onnx',                       # GPLv2 data
    'en': TTS / 'en-us-kathleen-low' / 'en-us-kathleen-low.onnx',  # CC0
    'de': TTS / 'de-thorsten-low' / 'de-thorsten-low.onnx',    # CC0
    'fr': TTS / 'fr-siwis-medium' / 'fr-siwis-medium.onnx',    # CC-BY 4.0
    'es': TTS / 'es-carlfm-x-low' / 'es-carlfm-x-low.onnx',    # public dom.
    'it': (TTS / 'it-riccardo_fasol-x-low' /
           'it-riccardo_fasol-x-low.onnx'),                     # M-AILABS
}
VOICE = VOICES['ru']
I18N = ROOT / 'docs' / 'story' / 'chorus-ep1' / 'narration_i18n.json'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'


def speak(text, wav, lang='ru'):
    subprocess.run([PIPER, '-m', str(VOICES[lang]), '-f', str(wav)],
                   input=text.encode('utf-8'), check=True,
                   capture_output=True)
    with wave.open(str(wav)) as w:
        return w.getnframes() / w.getframerate()


def wrap(text, width=34):
    words, lines, cur = text.split(), [], ''
    for w in words:
        if len(cur) + len(w) + 1 > width:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + ' ' + w).strip()
    lines.append(cur)
    return '\n'.join(lines)


def preview(item, wav, seconds, text, out):
    sub = out.with_suffix('.txt')
    sub.write_text(wrap(text), encoding='utf-8')
    # Scaled to 720 px first, so the subtitle wraps inside the frame
    # (the first previews at 320 px ran past its edges).
    draw = ("scale=720:720,"
            "drawtext=fontfile=%s:textfile=%s:fontcolor=0xFFE0A8:"
            "fontsize=24:line_spacing=6:x=(w-text_w)/2:y=h-text_h-30:"
            "box=1:boxcolor=black@0.55:boxborderw=10,"
            "drawtext=fontfile=%s:text='черновой голос':fontcolor="
            "white@0.6:fontsize=12:x=10:y=10" % (FONT, sub, FONT))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-stream_loop',
                    '-1', '-framerate', '8', '-i',
                    str(FRAMES / item / 'f%02d.png'), '-i', str(wav),
                    '-t', '%.2f' % (seconds + 1.0), '-vf', draw,
                    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '24',
                    '-c:a', 'aac', '-b:a', '64k', str(out)], check=True)
    sub.unlink()


def line_of(narr, i18n, group, key, lang):
    if lang == 'ru':
        return narr[group][key]['line_ru']
    return i18n['narration'][group].get(key, {}).get(lang, '')


def voices_all(lang):
    """Every narrator line in one language, into the pack's
    narration/<lang>/<key>.ogg; returns (lines, seconds)."""
    narr = json.loads(NARRATION.read_text(encoding='utf-8'))
    i18n = json.loads(I18N.read_text(encoding='utf-8'))
    out = PACK.parent / 'narration' / lang
    out.mkdir(parents=True, exist_ok=True)
    tmp = ROOT / 'build' / 'voice' / lang
    tmp.mkdir(parents=True, exist_ok=True)
    n, total = 0, 0.0
    for group in ('beats', 'objects'):
        for key, x in narr[group].items():
            text = line_of(narr, i18n, group, key, lang)
            if not text or x.get('voice') is False:
                continue
            wav = tmp / ('%s.wav' % key)
            total += speak(text, wav, lang)
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i',
                            str(wav), '-c:a', 'libvorbis', '-q:a', '3',
                            str(out / ('%s.ogg' % key))], check=True)
            n += 1
    return n, total


def previews(lang):
    narr = json.loads(NARRATION.read_text(encoding='utf-8'))
    i18n = json.loads(I18N.read_text(encoding='utf-8'))
    pilot = json.loads(PILOT.read_text(encoding='utf-8'))
    for e in pilot['examine']:
        item = e['id'].lower()
        text = line_of(narr, i18n, 'objects', e['id'], lang)
        wav = ROOT / 'build' / 'voice' / lang / ('%s.wav' % e['id'])
        seconds = speak(text, wav, lang)
        out = PREVIEW / ('closeup-%s-%s.mp4' % (item, lang))
        preview(item, wav, seconds, text, out)
        print(lang, item, '%.1f s' % seconds, out.stat().st_size, 'B')


def main():
    if '--langs' in sys.argv:
        for lang in sys.argv[sys.argv.index('--langs') + 1].split(','):
            n, sec = voices_all(lang)
            print('%s: %d lines, %.1f s' % (lang, n, sec))
            previews(lang)
        return
    pilot = json.loads(PILOT.read_text(encoding='utf-8'))
    narr = json.loads(NARRATION.read_text(encoding='utf-8'))
    tmp = ROOT / 'build' / 'voice'
    tmp.mkdir(parents=True, exist_ok=True)
    for e in pilot['examine']:
        item = e['id'].lower()
        line = narr['objects'][e['id']]['line_ru']
        wav = tmp / ('%s.wav' % item)
        seconds = speak(line, wav)
        dest = PACK / item
        dest.mkdir(parents=True, exist_ok=True)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i',
                        str(wav), '-c:a', 'libvorbis', '-q:a', '3',
                        str(dest / 'voice_ru.ogg')], check=True)
        out = PREVIEW / ('closeup-%s.mp4' % item)
        preview(item, wav, seconds, line, out)
        print('%s: %.1f s voice, %d B ogg, %d B preview' % (
            item, seconds, (dest / 'voice_ru.ogg').stat().st_size,
            out.stat().st_size))


if __name__ == '__main__':
    main()
