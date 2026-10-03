#!/usr/bin/env python3
"""Build the draft voice of Claud, the ROV operator's AI companion.

CLAUDE.md TABOO 0.026 and docs/HLD_COMPANION_CLAUD_2026-10-03.md: the
companion speaks in a warm female mezzo with crisp, quick diction and a
calm irony, and a light digital sheen (a short chorus, glassy early
reflections, a little high-shelf air).  The voice is close to the
manner of a famous game AI by timbre, but it is never a copy or a clone
of any real actress: this script starts from an open text-to-speech
voice and shapes it with a fixed chain of filters, nothing more.

Every file it writes is a DRAFT VOICE ("черновой голос", TABOO 0.019
item 5): the tag sits in the OGG comment, in the file name of the
manifest and in the manifest itself.  The clean voice is a live actress
under contract and with consent.

The tracks go to a pack beside the APK (TABOO 0.018), never into
godot/: the output directory defaults to build/voice/claud/, which git
ignores.  The manifest lists bytes and SHA-256 of every file, as
godot/data/packs.json will need once CI builds the pack.

Engine: Piper (piper-tts on PyPI, https://github.com/OHF-Voice/piper1-gpl,
GPL-3.0-or-later; run as a separate program, the audio it makes is not
covered by its licence).  Russian voice: ru_RU-irina-medium from
rhasspy/piper-voices; its model card gives the dataset (RHVoice) licence
as "Unknown", and every Piper medium voice is fine-tuned from the
"lessac" voice, whose Blizzard 2013 data have their own terms.  So the
draft is for listening inside the team only; nothing it makes ships to
a store until a lawyer has read these terms or a live voice replaces
it.  The manifest records all of this.

Usage (piper installed into any Python, for example a venv):

    pip install piper-tts
    python3 scripts/voice/build_claud_voice.py --python venv/bin/python
    python3 scripts/voice/build_claud_voice.py --only claud_ascent_enter \\
        --samples /tmp/samples

The model (about 63 MB) is downloaded once into --model-dir; pass
--drop-model to delete it after the run when the disk is small.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "godot", "data", "companion-claud.json")
OUT = os.path.join(ROOT, "build", "voice", "claud")
MODELS = os.path.join(ROOT, "build", "voice", "models")
FFMPEG = shutil.which("ffmpeg") or "/usr/bin/ffmpeg"
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main/"

# One open voice per language.  Only Russian is wired now: Piper has a
# single Russian female voice, and the English draft waits for a voice
# whose terms the chorus accepts (see the HLD, phase C3).
VOICES = {
    "ru": {
        "name": "ru_RU-irina-medium",
        "path": "ru/ru_RU/irina/medium/",
        "license": "dataset RHVoice, model card: License: Unknown; "
                   "fine-tuned from en_US lessac (Blizzard 2013 terms)",
    },
}
ENGINE = {
    "name": "piper-tts",
    "url": "https://github.com/OHF-Voice/piper1-gpl",
    "license": "GPL-3.0-or-later (the program; its audio output is not "
               "covered)",
}

# Quick and collected: a little shorter phonemes than the voice's own,
# a steady generator.  Piper samples noise inside the model, so the same
# text may differ by a few samples between runs; the manifest pins the
# hash of what was actually built.
SYNTH = {"length_scale": 0.9, "noise_scale": 0.45, "noise_w": 0.6,
         "sentence_silence": 0.12}

# The shaping chain, in the order a studio would patch it:
# - rubberband lowers the pitch by about 1.5 semitones and keeps the
#   formants, so the voice moves towards a mezzo without a "slowed tape"
#   colour;
# - two peaking bands give warmth (220 Hz) and diction (3 kHz);
# - a light two-voice chorus and three short early reflections
#   (9-26 ms) give the glassy digital sheen of a voice in a helmet;
# - a high shelf adds air above 9 kHz;
# - loudness lands at -16 LUFS, peak at -1.5 dBTP (TABOO 0.4 item 13).
CHAIN = ",".join([
    "rubberband=pitch=0.917:formant=preserved",
    "equalizer=f=220:t=o:w=1.2:g=2",
    "equalizer=f=3000:t=o:w=1.0:g=1.5",
    "chorus=0.8:0.85:18|26:0.22|0.16:0.35|0.28:1.4|1.9",
    "aecho=0.9:0.7:9|17|26:0.16|0.1|0.06",
    "highshelf=f=9000:g=3",
    "loudnorm=I=-16:TP=-1.5:LRA=7",
    "aresample=48000",
])
DRAFT_TAG = "DRAFT VOICE / черновой голос - open TTS, not a live actress"


def sha256(path):
    """Return the SHA-256 of a file, read in blocks to stay small."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 16), b""):
            h.update(block)
    return h.hexdigest()


def fetch_model(lang, model_dir):
    """Download the voice and its card once; return the .onnx path."""
    v = VOICES[lang]
    os.makedirs(model_dir, exist_ok=True)
    onnx = os.path.join(model_dir, v["name"] + ".onnx")
    for name in (v["name"] + ".onnx", v["name"] + ".onnx.json",
                 "MODEL_CARD"):
        dest = os.path.join(model_dir, name)
        if name == "MODEL_CARD":
            dest = os.path.join(model_dir, v["name"] + ".MODEL_CARD")
        if os.path.exists(dest):
            continue
        print("fetch", HF + v["path"] + name)
        urllib.request.urlretrieve(HF + v["path"] + name, dest)
    return onnx


def lines_to_build(data, lang, only):
    """Every non-empty line of `lang`, never one at a holy beat."""
    holy = set(data.get("holy_beats", []))
    out = []
    for x in data["lines"]:
        if x["beat"] in holy or not x.get(lang):
            continue
        if only and x["voice_file"] not in only:
            continue
        out.append((x["voice_file"], x.get("say_" + lang, x[lang])))
    return out


def synth(python, onnx, text, wav):
    """Speak `text` into `wav` with Piper as a separate process."""
    cmd = [python, "-m", "piper", "-m", onnx, "-f", wav,
           "--length-scale", str(SYNTH["length_scale"]),
           "--noise-scale", str(SYNTH["noise_scale"]),
           "--noise-w-scale", str(SYNTH["noise_w"]),
           "--sentence-silence", str(SYNTH["sentence_silence"])]
    subprocess.run(cmd, input=text.encode("utf-8"), check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def shape(wav, ogg, text):
    """Run the shaping chain and write a mono Vorbis tagged as draft."""
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
           "-i", wav, "-af", CHAIN, "-ac", "1", "-c:a", "libvorbis",
           "-q:a", "4", "-map_metadata", "-1",
           "-metadata", "title=Claud: " + text[:60],
           "-metadata", "comment=" + DRAFT_TAG,
           "-metadata", "artist=draft voice (open TTS)", ogg]
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--data", default=DATA)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--model-dir", default=MODELS)
    ap.add_argument("--lang", default="ru", choices=sorted(VOICES))
    ap.add_argument("--python", default=sys.executable,
                    help="a Python with piper-tts installed")
    ap.add_argument("--only", nargs="*", default=[],
                    help="voice_file ids to build (default: all)")
    ap.add_argument("--samples", default="",
                    help="also copy the built files here")
    ap.add_argument("--drop-model", action="store_true",
                    help="delete the downloaded model after the run")
    a = ap.parse_args()

    out = os.path.abspath(a.out)
    if os.path.commonpath([out, os.path.join(ROOT, "godot")]) \
            == os.path.join(ROOT, "godot"):
        sys.exit("the voice goes to a pack, not into godot/ (TABOO 0.018)")
    with open(a.data, encoding="utf-8") as f:
        data = json.load(f)
    if data.get("draft_voice") is not True:
        sys.exit("companion-claud.json is not marked draft_voice")
    probe = subprocess.run([a.python, "-c", "import piper"],
                           capture_output=True)
    if probe.returncode != 0:
        sys.exit("piper-tts is not installed for %s: pip install "
                 "piper-tts (network needed once)" % a.python)

    onnx = fetch_model(a.lang, a.model_dir)
    lang_dir = os.path.join(out, a.lang)
    os.makedirs(lang_dir, exist_ok=True)
    files = []
    with tempfile.TemporaryDirectory() as tmp:
        for vf, text in lines_to_build(data, a.lang, set(a.only)):
            wav = os.path.join(tmp, vf + ".wav")
            ogg = os.path.join(lang_dir, vf + ".ogg")
            synth(a.python, onnx, text, wav)
            shape(wav, ogg, text)
            files.append({
                "voice_file": vf, "lang": a.lang,
                "path": "companion/%s/%s.ogg" % (a.lang, vf),
                "bytes": os.path.getsize(ogg), "sha256": sha256(ogg),
                "text": text, "draft_voice": True,
            })
            print("built", ogg, files[-1]["bytes"], "bytes")
            if a.samples:
                os.makedirs(a.samples, exist_ok=True)
                shutil.copy(ogg, a.samples)

    manifest = {
        "pack": data.get("pack", "voice-claud-ep1"),
        "draft_voice": True,
        "label_ru": data.get("draft_label_ru", "черновой голос"),
        "label_en": data.get("draft_label_en", "draft voice"),
        "mount": "res://companion/{lang}/{voice_file}.ogg",
        "engine": ENGINE,
        "voice": {"lang": a.lang, "model": VOICES[a.lang]["name"],
                  "source": HF + VOICES[a.lang]["path"],
                  "license": VOICES[a.lang]["license"]},
        "not_a_copy": "No recording, voice, sound or name of Halo or "
                      "of its actress is used; the timbre comes from an "
                      "open TTS voice and the fixed chain below.",
        "synth": SYNTH, "chain": CHAIN,
        "release": "team listening only until a lawyer clears the "
                   "voice terms or a live actress records the lines",
        "files": files,
        "total_bytes": sum(f["bytes"] for f in files),
    }
    path = os.path.join(out, "manifest-%s.draft.json" % a.lang)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("manifest", path, len(files), "files",
          manifest["total_bytes"], "bytes")
    if a.drop_model:
        shutil.rmtree(a.model_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
