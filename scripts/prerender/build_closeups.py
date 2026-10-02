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
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PILOT = ROOT / 'godot' / 'data' / 'pilot-1.json'
NARRATION = ROOT / 'godot' / 'data' / 'pilot-narration.json'
PACK = ROOT / 'godot' / 'packs' / 'closeups-ep1' / 'closeups'
FRAMES = ROOT / 'build' / 'turntable'
PREVIEW = ROOT / 'docs' / 'audit' / '2026-10-02'
PIPER = '/home/user/tts-venv/bin/piper'
VOICE = Path('/tmp/claude-0/-home-user-ludus/00bfaacc-916a-5377-9b22-'
             '7beb9ad7416e/scratchpad/tts/ru-irinia-medium.onnx')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'


def speak(text, wav):
    subprocess.run([PIPER, '-m', str(VOICE), '-f', str(wav)],
                   input=text.encode('utf-8'), check=True,
                   capture_output=True)
    with wave.open(str(wav)) as w:
        return w.getnframes() / w.getframerate()


def wrap(text, width=46):
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
    draw = ("drawtext=fontfile=%s:textfile=%s:fontcolor=0xFFE0A8:"
            "fontsize=18:line_spacing=4:x=(w-text_w)/2:y=h-text_h-24:"
            "box=1:boxcolor=black@0.45:boxborderw=8,"
            "drawtext=fontfile=%s:text='черновой голос':fontcolor="
            "white@0.6:fontsize=12:x=10:y=10" % (FONT, sub, FONT))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-stream_loop',
                    '-1', '-framerate', '8', '-i',
                    str(FRAMES / item / 'f%02d.png'), '-i', str(wav),
                    '-t', '%.2f' % (seconds + 1.0), '-vf', draw,
                    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '24',
                    '-c:a', 'aac', '-b:a', '64k', str(out)], check=True)
    sub.unlink()


def main():
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
