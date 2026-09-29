# VR scene migration: webtypicon2 `public/game/vr*` → ludus `public/vr/`

Date: 2026-09-29. Branch: `claude/gracious-clarke-36w4kh`.

## Why

The owner approved moving the Meta-only WebXR scene («Двор Герата»,
Quest 3) into the Meta repo (ludus). webtypicon2 is left untouched here;
a separate PR there will remove the old copy.

Source commit (last commit touching `public/game` in webtypicon2):
`c72d62342305ded38b9bf57cf69c90c28a3eb886`
(`git -C /home/user/webtypicon2 log -1 --format=%H -- public/game`).

## What was copied

| ludus path | from webtypicon2 `public/game/` |
|---|---|
| `public/vr/vr.html`, `vr.js`, `vr-og.png` | same names |
| `public/vr/vendor/needle/*` (11 `.min.js` + `LICENSE.md`) | `vendor/needle/*` (all files) |
| `public/vr/vr-assets/gerat.glb`, `props/character-items-01.glb` | `vr-assets/**` |
| `public/vr/art/` 14 SVGs | `art/`: every file vr.html/vr.js reference |

The SVGs are `obj-shlem-quest`, `obj-zvezda-puti`, `obj-tamga-khana`,
`obj-svitok-yazykov`, `obj-rog-glashataya`, `loc-gerat`, `loc-nebo-stepi`,
`npc-khan` and the six `npc-<id>` portraits built dynamically from
`VR_NPC_STATIC` (sargis, vardan, melik, tabib, strazhnik, anahit).

## Changes made after copying

- `/game/art/`, `/game/vendor/needle/` and `/game/vr.js` became `/vr/...`.
- The «back to text game» links `href="/game/"` point to `/` (the ludus
  home). `?from=<tab>` now rewrites them to `/?tab=<tab>`.
- `og:image` points to `/vr/vr-og.png` instead of `typikon.site`.
- New `<meta name="ludus-vr-backend" content="off">` in `vr.html`.
  `healthGatedAuthLoad()` in `vr.js` reads it. With "off" it skips
  `GET /api/game/health` and goes straight to the offline story mode
  (cached mission and static NPC row), which the page already had. The
  gameApi backend (`/api/game/*`, `/auth.js`) lives in webtypicon2, so
  without this gate every load produced a 404. Set it to "on" only where
  those routes are really served.

## Verification (Playwright, headless Chromium, SwiftShader WebGL)

`http://localhost:8080/vr/vr.html` made 25 same-origin requests. All
returned 200, and none returned 4xx. Both GLBs returned 200:
`/vr/vr-assets/gerat.glb` and `/vr/vr-assets/props/character-items-01.glb`.
After «Войти во двор» a 1280×720 canvas renders the court: walls, trees
and an altar block (604 distinct colours in the screenshot). WebXR itself
cannot start headless and was not tested. A real Quest 3 is still needed.

The run also logged problems that the move did not cause. The original
page at webtypicon2 `/game/vr.html` shows the same three page errors,
plus a 404 on `/api/game/health`:

- The Needle runtime tries to reach outside hosts: `needle.tools/api/v1/rum/t`
  and `/ping` (telemetry), `cdn.needle.tools/.../basis_transcoder.*` (KTX2),
  `www.gstatic.com/draco/...` (Draco) and `fonts.googleapis.com`. The
  sandbox proxy blocked all of them. As a result, `TypeError: Failed to
  fetch` appears twice and `Cannot read properties of undefined (reading
  'includes')` appears in `needle-engine.bundle`. The scene still renders.
- To run without these hosts (as a Quest store build must), self-host the
  Draco and Basis decoders and turn off Needle telemetry. That is follow-up
  work.

## Licences found

- `vendor/needle/LICENSE.md` (only licence file present): "Copyright ©
  Needle Tools GmbH, 2021–2022. All Rights Reserved. Needle Engine … is
  not open source." Free use is allowed only for non-commercial,
  non-NFT and evaluation projects. Commercial use requires eligibility
  under the EULA (https://needle.tools/eula) or a written grant.
  **Shipping to the Meta Quest store (Feb 2027) is gated on a Needle
  licence decision.**
- Engine version: the string `"5.1.12"` appears in
  `needle-engine.bundle-BmdWLmLa.min.js`, which matches the
  `@needle-tools/engine@5.1.12` noted in `vr.js`.
- three.js: `three-core.min.js` declares `REVISION "169.19"` (Needle's
  three.js fork). None of the 11 `.min.js` files has an `@license`
  header or a `/*!` banner (`grep -c` gives 0 for each).
- The folder ships no licence text for the bundled third-party code
  (three.js, rapier, three-mesh-ui, postprocessing, MaterialX). Upstream,
  these projects publish permissive licences (MIT, Apache-2.0, Zlib), but
  this was **not verified from the vendored files**. Before release, add
  the upstream LICENSE texts from the exact package versions.
- GLBs: `asset.generator` reads "webtypikon2 vr-v1 (self-authored, CC0)"
  and "webtypikon2 vr-props-v1 (self-authored, CC0, primitive geometry)".

## Repo-root junk files (from a mis-pasted heredoc)

A broken heredoc in commits `c5177b2`, `ea81806`, `b0fac6b` and `9572bd1`
(2026-09-23) created these files. Their names are lines from the
file-tree drawings in the HLDs. Before deciding, each file was printed and
checked against every tracked text file, line by line:

| file | lines found elsewhere | content |
|---|---|---|
| `(IVehicleCommandSource)                    (Phase 2)` | 0/90 | HLD_VR §5.2–5.9 cockpit layering/events |
| `(thermocline)    (Archimedes) … (allocation)` | 2/54 | HLD_VR §4.1–4.7 water column, buoyancy |
| `Phase 5 (Instruments) ─┘` | 7/99 | HLD_VR §6.x dive computer, alarms |
| `└── CockpitCommandSource.cs …` | 0/14 | HLD_VR §5.10 scene setup checklist |
| `└── InputCommandAdapter.cs …` | 0/7 | HLD_VR §5 / 5.1 heading |
| `}` | 9/87 | HLD_Roblox §4–5 ProfileStore, session lock |
| `└── UI.luau …` | 1/6 | HLD_Roblox dependency rule, §4 heading |
| `└─► releaseAsync …` | 1/6 | HLD_Roblox economy note, §3 heading |
| `InputProvider.cs` | 0/11 | HLD_VR §5–6 (markdown, **not** C#) |

**Decision: nothing was deleted.** The files do come from a broken
heredoc, but their text is the only copy of large parts of
`UnityVR/HLD_VR.md` (165 lines now) and `HLD_Roblox.md` in the working
tree. The rule for this cleanup was to delete only fragments that are
not unique source. Root `InputProvider.cs` is not identical to
`UnityVR/Assets/Scripts/Input/InputProvider.cs` and is not a fragment of
it: it is markdown HLD text, and the real file is C# code (per `diff`).
So it stays, as the rule requires.

Recommended follow-up (owner of the HLD docs): merge each fragment into
`UnityVR/HLD_VR.md` / `HLD_Roblox.md` in section order, then
`git rm` the nine root files in the same commit.
