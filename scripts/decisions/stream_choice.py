"""How the heavy data reaches the headset: one way from the honest pool.

Operator, 2026-10-02: «пропиши в клауд мд эти требования мы делаем
также найди решение для мета из 999 одно по 32 параметрам проекта
сделать также: Минимальная установка… Стриминг с носителя… читались
напрямую с сети»; «жесткий диск это 128 наших на шлеме».

Pandora put 20-40 MB on the hard disk (the engine, scripts, saves,
the interface) and read the video, sound and big textures from the CD.
Our hard disk is the APK under its 128 MiB budget; our CD is a pack
fetched over the network, kept beside the APK and mounted by DataPacks.

Pool (2026-10-02, not padded to 999, TABOO 0.07):
    13 ways x 5 hosts x 4 moments x 3 integrity checks = 780.

Hard rules prune first: Quest does not support it (Play Asset Delivery,
split APKs); it needs the store listing the project does not yet have
(Meta Asset Files, the store's OBB delivery: they come at release);
a paid host; no integrity check; it sends anything about the player
(TABOO 0.35 item 21); the game would not start offline.  The rest are
scored on 32 parameters, 0-3 each.

    python3 scripts/decisions/stream_choice.py           # table
    python3 scripts/decisions/stream_choice.py --check   # CI

Constitution: ФОРМА (the 128 MiB the headset installs, and the network
it may reach) → ДЕЙСТВИЕ (the APK carries the engine, the logic, the
interface and the first episode; the rest comes as packs before it is
needed) → ЦЕЛЬ (the game starts at once and works without a network;
the voices and the next episodes come when the player walks to them).
"""

import itertools
import sys

PARAMS = (
    'quest_supported', 'works_now', 'offline_first_start', 'apk_small',
    'pack_size_unbounded', 'store_compatible', 'sideload_compatible',
    'privacy_no_ids', 'no_account', 'no_cost', 'open_tools',
    'integrity', 'resumable', 'background', 'no_frame_stutter',
    'versioned', 'rollback', 'cdn_speed', 'availability', 'simplicity',
    'testable_offline', 'godot_native', 'no_new_module', 'ci_publish',
    'licence_clear', 'storage_quota', 'uninstall_clean',
    'saves_survive_update', 'web_parity', 'operator_effort',
    'low_risk', 'constitution_fit')
assert len(PARAMS) == 32

# way: (quest ok, needs store listing, attrs)
WAYS = {
    'godot-pck-http-download': (True, False, dict(
        works_now=3, offline_first_start=3, apk_small=3,
        pack_size_unbounded=3, store_compatible=2, sideload_compatible=3,
        resumable=2, background=3, no_frame_stutter=3, versioned=3,
        rollback=3, simplicity=2, testable_offline=3, godot_native=3,
        no_new_module=3, ci_publish=3, uninstall_clean=3,
        saves_survive_update=3, web_parity=2, operator_effort=3,
        low_risk=2, constitution_fit=3)),
    'obb-sideload-adb': (True, False, dict(
        works_now=3, offline_first_start=3, apk_small=3,
        pack_size_unbounded=2, store_compatible=3, sideload_compatible=2,
        background=0, versioned=2, simplicity=3, godot_native=3,
        no_new_module=3, ci_publish=2, operator_effort=1,
        constitution_fit=3)),
    'meta-store-obb': (True, True, {}),
    'meta-platform-asset-files': (True, True, {}),
    'godot-pck-http-range-stream': (True, False, dict(
        works_now=1, background=3, simplicity=0, no_frame_stutter=1,
        resumable=3, testable_offline=1, low_risk=0)),
    'http-audio-stream-direct': (True, False, dict(
        works_now=1, offline_first_start=1, no_frame_stutter=1,
        godot_native=1, simplicity=1, testable_offline=0)),
    'play-asset-delivery': (False, True, {}),
    'split-apks': (False, True, {}),
    'firebase-storage-sdk': (True, False, dict(
        works_now=1, no_account=1, no_new_module=0, godot_native=0,
        privacy_no_ids=1)),
    'webxr-streamed-build': (True, False, dict(
        works_now=3, apk_small=3, offline_first_start=0,
        no_frame_stutter=2, web_parity=3, godot_native=3)),
    'bittorrent': (True, False, dict(
        privacy_no_ids=0, no_new_module=0, simplicity=0)),
    'sidequest-bundle': (True, False, dict(
        works_now=2, background=0, store_compatible=0,
        operator_effort=1)),
    'everything-in-apk': (True, False, dict(
        apk_small=0, pack_size_unbounded=0, works_now=3,
        simplicity=3, background=0, offline_first_start=3)),
}
assert len(WAYS) == 13

# host: (paid, sends ids, cdn speed, availability, licence clear)
HOSTS = {
    'github-releases': (False, False, 2, 3, 3),
    'github-pages': (False, False, 2, 3, 3),
    'firebase-hosting': (False, False, 3, 3, 3),
    'cloudflare-r2': (True, False, 3, 3, 3),
    'own-server': (True, False, 1, 1, 3),
}
MOMENTS = {'at-install': 1, 'first-launch-blocking': 0,
           'background-before-need': 3, 'on-demand-at-door': 1}
CHECKS = {'none': 0, 'sha256-manifest': 3, 'signed-manifest': 3}


def pruned(w, h, m, c):
    quest, store, _ = WAYS[w]
    paid, ids, _, _, _ = HOSTS[h]
    if not quest:
        return 'Quest does not support it'
    if store:
        return 'needs the store listing (comes at release)'
    if paid:
        return 'paid host'
    if ids:
        return 'sends data about the player'
    if c == 'none':
        return 'no integrity check'
    if m == 'first-launch-blocking':
        return 'the game would not start at once'
    if w == 'everything-in-apk' and h != 'github-releases':
        return 'no host needed: one row is enough'
    return ''


def score(w, h, m, c):
    a = WAYS[w][2]
    s = {p: a.get(p, 1) for p in PARAMS}
    _, _, cdn, avail, lic = HOSTS[h]
    s['quest_supported'] = 3
    s['privacy_no_ids'] = min(a.get('privacy_no_ids', 3), 3)
    s['no_account'] = a.get('no_account', 3)
    s['no_cost'] = 3
    s['open_tools'] = a.get('open_tools', 3)
    s['integrity'] = CHECKS[c]
    s['background'] = min(s['background'], MOMENTS[m])
    s['cdn_speed'] = cdn
    s['availability'] = avail
    s['licence_clear'] = lic
    if h == 'firebase-hosting':
        # A new deploy target to keep, and a quota to watch.
        s['operator_effort'] = max(0, s['operator_effort'] - 2)
        s['storage_quota'] = 1
    if h == 'github-pages':
        # Pages serves files up to 100 MB and sites up to 1 GB; a voice
        # pack of an episode may pass both.  Releases take 2 GB a file.
        s['storage_quota'] = 1
        s['pack_size_unbounded'] = min(s['pack_size_unbounded'], 1)
    if c == 'signed-manifest':
        # A key to keep and rotate: a secret for the operator.
        s['operator_effort'] = max(0, s['operator_effort'] - 1)
        s['simplicity'] = max(0, s['simplicity'] - 1)
    return s


def ranked():
    alive, dead = [], {}
    for c in itertools.product(WAYS, HOSTS, MOMENTS, CHECKS):
        why = pruned(*c)
        if why:
            dead[why] = dead.get(why, 0) + 1
            continue
        s = score(*c)
        alive.append((sum(s.values()), c))
    alive.sort(key=lambda x: (-x[0], x[1]))
    return alive, dead


CHOSEN = ('godot-pck-http-download', 'github-releases',
          'background-before-need', 'sha256-manifest')


def main(argv):
    alive, dead = ranked()
    total = len(WAYS) * len(HOSTS) * len(MOMENTS) * len(CHECKS)
    if '--check' in argv:
        print('stream: %d in pool, %d pruned, %d scored; chosen %s' % (
            total, sum(dead.values()), len(alive),
            ' x '.join(alive[0][1])))
        if alive[0][1] != CHOSEN:
            print('FAIL: the choice changed; update the HLD')
            return 1
        return 0
    print('pool %d, pruned %d %s, scored %d' % (
        total, sum(dead.values()), dead, len(alive)))
    print('| # | way | host | moment | check | score of 96 |')
    print('|---|---|---|---|---|---|')
    for i, (tot, c) in enumerate(alive[:8], 1):
        print('| %d | %s | %s | %s | %s | %d |' % ((i,) + c + (tot,)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
