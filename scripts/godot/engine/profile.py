"""The headset engine's build profile: what is cut, and proof it is unused.

docs/decisions/ENGINE_BUILD_2026-10-02.md chose a custom Godot 4.7.1
template: optimize=size, thin LTO, a class profile from the project,
the full text server, unused modules off.  This module holds that
choice as data and checks it against the game:

* ludus.gdbuild (next to this file) is the SCons build profile:
  disabled build options and disabled classes;
* MODULES_OFF are the engine modules left out, each with the words
  that would show the game uses it;
* check() scans everything the headset build exports (godot/ without
  tests/ and the excluded addons) and fails when a word of anything cut
  appears there, so a new mechanic that needs a cut part turns CI red
  instead of failing in the headset.

    python3 scripts/godot/engine/profile.py --check
    python3 scripts/godot/engine/profile.py --scons android template_debug

Constitution: ФОРМА (the engine as the game uses it) → ДЕЙСТВИЕ (cut
only what the game never calls, and prove it on every push) → ЦЕЛЬ
(room for the teaching's voices in a lighter APK).
"""

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROFILE = HERE / 'ludus.gdbuild'
GODOT = ROOT / 'godot'

# What the headset build does not export (godot/export_presets.cfg
# exclude_filter), so words there do not count.
NOT_EXPORTED = ('tests/', 'addons/dialogic/', 'addons/beehave/',
                'addons/tessarakkt.oceanfft/', 'addons/godot-xr-tools/',
                '.godot/')
SCANNED = ('.gd', '.tscn', '.tres', '.godot', '.cfg', '.import')

# Each module left out, with the words that would mean the game uses it.
MODULES_OFF = {
    'camera': r'CameraServer|CameraFeed|CameraTexture',
    'csg': r'\bCSG',
    'enet': r'ENet',
    'fbx': r'FBXDocument|\.fbx\b',
    'gridmap': r'GridMap|MeshLibrary',
    'interactive_music': r'AudioStreamInteractive|AudioStreamPlaylist'
                         r'|AudioStreamSynchronized',
    'jsonrpc': r'JSONRPC',
    'mobile_vr': r'MobileVR',
    'mp3': r'AudioStreamMP3|\.mp3\b',
    'multiplayer': r'Multiplayer|\brpc\(|@rpc',
    'navigation_2d': r'Navigation',
    'navigation_3d': r'Navigation',
    'noise': r'FastNoiseLite|NoiseTexture',
    'theora': r'VideoStreamTheora|\.ogv\b',
    'upnp': r'UPNP',
    'webrtc': r'WebRTC',
    'websocket': r'WebSocket',
    # webxr is not listed: it builds only for the web platform, and the
    # Web export keeps the stock template.
    'godot_physics_2d': r'Body2D|Area2D|CollisionShape2D|RayCast2D',
    'godot_physics_3d': r'Body3D|Area3D|CollisionShape3D|RayCast3D',
    'jolt_physics': r'Body3D|Area3D|CollisionShape3D|RayCast3D'
                    r'|direct_space_state|PhysicsServer3D',
}

# The words behind each disabled build option.
OPTIONS_OFF = {
    'disable_navigation_2d': r'Navigation\w*2D|NavigationServer2D',
    'disable_navigation_3d': r'Navigation\w*3D|NavigationServer3D',
    'disable_physics_2d': r'Body2D|Area2D|CollisionShape2D|RayCast2D'
                          r'|PhysicsServer2D|ShapeCast2D|Joint2D',
    'disable_physics_3d': r'Body3D|Area3D|CollisionShape3D|RayCast3D'
                          r'|PhysicsServer3D|ShapeCast3D|Joint3D'
                          r'|direct_space_state|SoftBody3D',
}

# The decision's build flags (optimize=size, thin LTO; LTO thin needs
# clang, which the Android NDK and use_llvm give).
FLAGS = ['optimize=size', 'lto=thin', 'production=yes',
         'debug_symbols=no']


def load_profile():
    return json.loads(PROFILE.read_text(encoding='utf-8'))


def exported_files():
    for p in sorted(GODOT.rglob('*')):
        rel = p.relative_to(GODOT).as_posix()
        if not p.is_file() or rel.startswith(NOT_EXPORTED):
            continue
        if p.suffix in SCANNED or p.name == 'project.godot':
            yield rel, p


def strip_comments(rel, text):
    """GDScript comments may name a cut part ("Noise" in a citation);
    only code counts."""
    if not rel.endswith('.gd'):
        return text
    return '\n'.join(re.sub(r'#.*$', '', line)
                     for line in text.splitlines())


def check():
    """Every cut thing with the files that still use it."""
    prof = load_profile()
    words = {}
    for opt in prof.get('disabled_build_options', {}):
        words['option ' + opt] = OPTIONS_OFF[opt]
    for cls in prof.get('disabled_classes', []):
        words['class ' + cls] = r'\b%s\b' % re.escape(cls)
    for mod, w in MODULES_OFF.items():
        words['module ' + mod] = w
    hits = {k: [] for k in words}
    for rel, p in exported_files():
        try:
            text = strip_comments(rel, p.read_text(encoding='utf-8'))
        except UnicodeDecodeError:
            continue
        for k, w in words.items():
            if re.search(w, text):
                hits[k].append(rel)
    return {k: v for k, v in hits.items() if v}, len(words)


def scons_args(platform, target):
    """The SCons command line of the chosen build."""
    args = ['platform=' + platform, 'target=' + target,
            'build_profile=' + str(PROFILE)] + FLAGS
    if platform == 'android':
        args.append('arch=arm64')
    else:
        args.append('use_llvm=yes')
        args.append('linker=lld')
    args += ['module_%s_enabled=no' % m for m in sorted(MODULES_OFF)]
    return args


def main(argv):
    if argv[:1] == ['--scons']:
        print(' '.join(scons_args(argv[1], argv[2])))
        return 0
    used, total = check()
    if used:
        for k, files in sorted(used.items()):
            print('USED although cut: %s in %s' % (k, ', '.join(files[:5])))
        return 1
    print('engine profile: %d cut parts, none used by the exported game'
          % total)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
