# Third-party raw material register

| Object | Source | Commit | Path | Licence | Colour | Shape |
|---|---|---|---|---|---|---|
| ant_anger_8c10c90816 | anger | 12/12 | https://github.com/Card-Forge/forge | 647b5eac95 | forge-gui/res/adventure/common/sprites/enemy/beast/insect/smallworm.png #0 | GPL | 48.1% |
| ant_gluttony_3b98248226 | gluttony | 12/12 | https://github.com/Card-Forge/forge | 647b5eac95 | forge-gui/res/adventure/common/sprites/enemy/ooze/giant_slime.png #0 | GPL | 37.2% |
| ant_anger_3c331cda72 | anger | 12/12 | https://github.com/Card-Forge/forge | 647b5eac95 | forge-gui/res/adventure/common/sprites/enemy/plant/mushroom_monster.png #0 | GPL | 46.0% |
| ant_anger_78b752dfa6 | anger | 12/12 | https://github.com/Card-Forge/forge | 647b5eac95 | forge-gui/res/adventure/common/sprites/enemy/plant/slimefoot.png #0 | GPL | 49.4% |
| ant_anger_c3857f31c5 | anger | 12/12 | https://github.com/Card-Forge/forge | 647b5eac95 | forge-gui/res/adventure/common/sprites/enemy/undead/ghost.png #0 | GPL | 50.4% |
| ant_acedia_7503efbff8 | acedia | 12/12 | https://github.com/Card-Forge/forge | 647b5eac95 | forge-gui/res/adventure/common/sprites/enemy/undead/ghost.png #1 | GPL | 69.4% |
| ant_sadness_3f22d4e3ed | sadness | 12/12 | https://github.com/Card-Forge/forge | 647b5eac95 | forge-gui/res/adventure/common/sprites/enemy/undead/ghost_2.png #0 | GPL | 39.1% |
| ant_pride_4a93e8590a | pride | 12/12 | https://github.com/Card-Forge/forge | 647b5eac95 | forge-gui/res/adventure/common/sprites/enemy/aberration/beholder.png #1 | GPL | 35.1% |
| ant_avarice_f14d9c7468 | avarice | 12/12 | https://github.com/crawl/crawl | 7c31f6e797 | crawl-ref/source/rltiles/UNUSED/monsters/ravenous_mimic.png #0 | GPL | 40.2% |
| ant_vainglory_12f32bbb0f | vainglory | 12/12 | https://github.com/crawl/crawl | 7c31f6e797 | crawl-ref/source/rltiles/item/misc/misc_phantom_mirror.png #0 | GPL | 56.6% |

## Engine and libraries of the headset build (used unchanged, not raw material)

These are dependencies under their own licences, not material reworked
by the runner, so the 35 % rule does not apply to them. They are listed
here so the lawyer sees every third-party component (TABOO 0.1).

| Component | Licence | Commit or version | Where |
|---|---|---|---|
| Godot Engine | MIT | 4.7.1-stable | downloaded in CI (scripts/godot/ci_setup.sh) |
| godot_openxr_vendors (Meta loader) | MIT | 5.1.0-stable | downloaded in CI for the APK |
| godot-xr-tools | MIT | 2d8db860d1 | godot/addons/godot-xr-tools, vendor/godot |
| beehave | MIT | fe589153fa | godot/addons/beehave, vendor/godot |
| dialogic | MIT | 701b67bbe6 | godot/addons/dialogic, vendor/godot |
| godot4-oceanfft | MIT | 01f32d7151 | godot/addons/tessarakkt.oceanfft, vendor/godot |
| godot-jolt | MIT | 7f22589470 | vendor/godot (reference; Jolt is built into Godot) |
| godot_voxel | MIT | fa52579ec9 | vendor/godot (reference, not built yet) |
| godot-4-hitbox-hurtbox | MIT code, CC-BY-NC-SA art | 2238883d86 | vendor/godot (reference only; art never used) |

## Mangustik drawings and panel looks (operator's own repos, 2026-09-30)

| Source | Revision | Path | Licence | Use |
|---|---|---|---|---|
| Leonidy431/Mangustik | e0dc577 | rov-platform/cad, drawings, electronics svg; dive-buddy chassis; welder-module pipe_parts_d110; diveguard frontend | none recorded; operator's own work (first-party) | ROV model `godot/models/rov/mangustik.glb`, cockpit look |
| Leonidy431/Mangustik-BlueOs-Yacht-UAV | 48443c9 | project (19).zip: globals.css, tailwind.config.ts, vessel-dashboard, compass | none recorded; operator's own work (first-party) | cockpit look (colours, card layout, thresholds) |

Details: `third_party/mangustik/SOURCES.md`. No colour/shape delta is
claimed: these are not raw material through the runner.

## Posoh hydrophone "model 1" (operator's own repo, 2026-09-30)

| Source | Revision | Path | Licence | Use |
|---|---|---|---|---|
| Leonidy431/posoh | 55f44d0 | hardware/HYDROPHONE_V1.md; hardware/cad/*.scad and renders/*.png; hardware/firmware/hydrophone_v1/hydrophone_v1.ino; hardware/thermal/THERMAL_BUDGET.md; BOM_SENSORS.md; HARDWARE_INTEGRATION.md; OPENSCAD_DFM_PROTOCOL.md; docs/HARDWARE_BOM.md | none recorded; operator's own work (first-party) | hydrophone model `godot/models/posoh/hydrophone.glb` (rendered by OpenSCAD from hydrophone_v1.scad), `godot/scripts/posoh_core.gd` (sample rate and preamp values) |

Details: `third_party/posoh/SOURCES.md`. No colour/shape delta is
claimed: these are not raw material through the runner.
| ant_sadness_b6a55c4b0e | sadness | 12/12 | https://github.com/wesnoth/wesnoth | 7747be0ff7 | data/core/images/units/monsters/deep-tentacle-melee-defend-1.png #0 | GPL | 52.1% |
| ant_sadness_5272495b7e | sadness | 12/12 | https://github.com/wesnoth/wesnoth | 7747be0ff7 | data/core/images/units/monsters/deep-tentacle-melee-defend-2.png #0 | GPL | 51.7% |
| ant_avarice_055bf3b162 | avarice | 12/12 | https://github.com/wesnoth/wesnoth | 7747be0ff7 | data/internal/Rogue_Mage/images/units/rogue-mage/shadow-lord+female-defend1.png #0 | GPL | 35.1% |
| ant_avarice_c12399d853 | avarice | 12/12 | https://github.com/wesnoth/wesnoth | 7747be0ff7 | data/internal/Rogue_Mage/images/units/rogue-mage/shadow-lord+female-defend2.png #0 | GPL | 35.1% |
| ant_sadness_f52ff4a292 | sadness | 12/12 | https://github.com/wesnoth/wesnoth | 7747be0ff7 | data/internal/Rogue_Mage/images/units/rogue-mage/shadow-lord+female-sword2.png #0 | GPL | 44.3% |
| ant_avarice_e795010b0e | avarice | 12/12 | https://github.com/wesnoth/wesnoth | 7747be0ff7 | data/internal/Rogue_Mage/images/units/rogue-mage/shadow-lord+female-sword3.png #0 | GPL | 45.4% |

Withdrawn 2026-09-30 (row kept, the register only grows): `ant_avarice_c12399d853` was not shipped. It is a duplicate animation frame of `ant_avarice_055bf3b162` (aligned silhouette IoU 0.922). See docs/RAW_OSINT_CURSOR.json, pass 2026-09-30T16:51, field `reverted`.


## Spectral references of the audio pass audio-299-2026-09-30

Measured profiles only (envelope, T60, spectral centroid, decay), CLAUDE.md
TABOO 0.35 rule 8: no sound from these repositories is shipped or
sampled. Per-file licences and paths: docs/RAW_AUDIO_REFERENCES.json.

| Repository | Commit | Licences of the used files | Files | Share-alike |
|---|---|---|---|---|
| https://github.com/00-Evan/shattered-pixel-dungeon | 2bb34a4e91 | GPL | 12 | 12 |
| https://github.com/Anuken/Mindustry | f3bfa418a5 | GPL | 25 | 25 |
| https://github.com/FyroxEngine/Fyrox | c4ead6b99c | MIT | 1 | 0 |
| https://github.com/OpenDungeons/OpenDungeons | a9efe49a6f | CC-BY-SA, GPL | 5 | 5 |
| https://github.com/defold/defold | cbca1e163f | Custom | 2 | 0 |
| https://github.com/drwhut/tabletop-club | a4fb379b0f | MIT | 6 | 0 |
| https://github.com/endless-sky/endless-sky | 748d56c3c7 | PD | 6 | 0 |
| https://github.com/lincity-ng/lincity-ng | 69bff77dad | GPL | 5 | 5 |
| https://github.com/magefree/mage | 3d3f4320ed | MIT | 3 | 0 |
| https://github.com/panda3d/panda3d | ec9ea0a93a | BSD | 1 | 0 |
| https://github.com/raysan5/raylib | 6ecf21f700 | PD | 1 | 0 |
| https://github.com/space-wizards/space-station-14 | d4d4696248 | CC-BY, CC-BY-SA, MIT, PD | 173 | 24 |
| https://github.com/wesnoth/wesnoth | 7747be0ff7 | CC-BY-SA, GPL | 7 | 7 |
| https://github.com/widelands/widelands | 6c21c892e8 | GPL | 45 | 45 |
| https://github.com/yairm210/Unciv | eba5356202 | MPL | 7 | 7 |

## Spectral references of the audio pass audio-299-2026-09-30-r2

Supersedes the section "Spectral references of the audio pass audio-299-2026-09-30"
above. That section recorded 86 space-station-14 files without per-file
metadata as MIT (the code licence; the README makes assets CC-BY-SA 3.0
by default and warns that some are non-commercial) and the Unciv files as
MPL (their credits page names CC0 and CC BY 4.0). Files that fall back on
a README default in a repository that declares non-commercial assets are
now held out for the lawyer.

Measured profiles only (envelope, T60, spectral centroid, decay), CLAUDE.md
TABOO 0.35 rule 8: no sound from these repositories is shipped or
sampled. Per-file licences, authors and paths: docs/RAW_AUDIO_REFERENCES.json.

| Repository | Commit | Licences of the used files | Licence sources | Files | Share-alike | .noai |
|---|---|---|---|---|---|---|
| https://github.com/00-Evan/shattered-pixel-dungeon | 2bb34a4e91 | GPL | repository 6 | 6 | 6 |  |
| https://github.com/Anuken/Mindustry | f3bfa418a5 | GPL | repository 17 | 17 | 17 |  |
| https://github.com/FyroxEngine/Fyrox | c4ead6b99c | MIT | repository 2 | 2 | 0 |  |
| https://github.com/OpenDungeons/OpenDungeons | a9efe49a6f | CC-BY-SA, GPL | credits-table 5 | 5 | 5 |  |
| https://github.com/defold/defold | cbca1e163f | Custom | repository 2 | 2 | 0 |  |
| https://github.com/drwhut/tabletop-club | a4fb379b0f | MIT | repository 6 | 6 | 0 |  |
| https://github.com/endless-sky/endless-sky | 748d56c3c7 | PD | debian-copyright 1 | 1 | 0 |  |
| https://github.com/lincity-ng/lincity-ng | 69bff77dad | GPL | repository 4 | 4 | 4 |  |
| https://github.com/panda3d/panda3d | ec9ea0a93a | BSD | repository 1 | 1 | 0 |  |
| https://github.com/space-wizards/space-station-14 | d4d4696248 | CC-BY, CC-BY-SA, PD | per-file 55 | 55 | 18 | yes |
| https://github.com/wesnoth/wesnoth | 7747be0ff7 | CC-BY-SA, GPL | per-file 7 | 7 | 7 |  |
| https://github.com/widelands/widelands | 6c21c892e8 | GPL, PD | repository 26, sound-register 5 | 31 | 26 |  |
| https://github.com/yairm210/Unciv | eba5356202 | MPL, PD | credits-page 2, repository 1 | 3 | 1 |  |

Held out for the lawyer (not used, not fetched): space-wizards/space-station-14 licence-nc-unknown 82; space-wizards/space-station-14 licence-unknown 4; widelands/widelands licence-ambiguous 12; widelands/widelands licence-unknown 9.

A root `.noai` marker (an opt-out signal against AI use) is present in: https://github.com/space-wizards/space-station-14. It is recorded for the lawyer and the operator; the pass has not decided whether it binds.


## Things of the 99 locations (raw material, TABOO 0.013 p. 3)

Neutral things from the props store of the 99 repos
(`docs/RAW_LOCATION_PROPS.json`), each reshaped into twelve variants by
`scripts/raw_assets/location_items.py` and `location_kit.py` and passed
by eye (`docs/audit/2026-09-30/location-items/`). The licence is that of
the file itself where the file names one (space-station-14 `.rsi/
meta.json`, the SVG's `<metadata>`), else the repository's. Shape is
|A xor B| / |A or B| of the alpha masks against the source; every
variant is also 35 % or more from each of its siblings.

| Object | Serves | Variants | Source | Commit | Path | Licence | Min shape | Min colour |
|---|---|---|---|---|---|---|---|---|
| obj_bench_41042cf8fd | bench | 12/12 | https://github.com/space-wizards/space-station-14 | d4d4696248 | Resources/Textures/Structures/Furniture/chairs.rsi/wooden-bench.png #0 | CC-BY-SA-3.0 | 35.2% | 60.8% |
| obj_bridge_log_40b14237a3 | bridge-log, spruce-log | 12/12 | https://github.com/widelands/widelands | 6c21c892e8 | data/tribes/wares/log/idle_4.png #0 | GPL-2.0-or-later | 37.1% | 36.2% |
| obj_hourglass_e49ab22431 | hourglass | 12/12 | https://github.com/Azgaar/Fantasy-Map-Generator | 77192941fd | public/charges/hourglass.svg #0 | CC-BY-SA-3.0 | 35.2% | 95.3% |
| obj_tools_9b09b1f302 | tools | 12/12 | https://github.com/widelands/widelands | 6c21c892e8 | data/tribes/wares/hammer/menu.png #0 | GPL-2.0-or-later | 40.4% | 37.6% |

### Authors of the things of the 99 locations (attribution, appended 2026-09-30)

The rows above name the licence but not the author, which CC BY-SA and
the GPL ask for. From each file's own licence record (the kit meta's
`licence_facts`, which quotes the source):

| Object | Author and attribution | Licence | From |
|---|---|---|---|
| obj_bench_41042cf8fd | "wooden bench by Ko4erga (discord)", Space Station 14 contributors (space-wizards/space-station-14, `chairs.rsi/meta.json` "copyright") | CC-BY-SA-3.0 | `Resources/Textures/Structures/Furniture/chairs.rsi/wooden-bench.png` |
| obj_hourglass_e49ab22431 | Syryatsu, "Meuble sablier s'écoulant", https://commons.wikimedia.org/wiki/File:Meuble_sablier_s%27%C3%A9coulant.svg (via Azgaar/Fantasy-Map-Generator) | CC-BY-SA-3.0 | `public/charges/hourglass.svg` |
| obj_bridge_log_40b14237a3 | The Widelands Development Team (widelands/widelands, COPYING; authors listed in `data/txts/AUTHORS.lua`) | GPL-2.0-or-later | `data/tribes/wares/log/idle_4.png` |
| obj_tools_9b09b1f302 | The Widelands Development Team (widelands/widelands, COPYING; authors listed in `data/txts/AUTHORS.lua`) | GPL-2.0-or-later | `data/tribes/wares/hammer/menu.png` |

The derived variants carry the same licence (share-alike); the claim of
35 % change is the project's own rule, not a legal test (TABOO 0.1).
| ant_avarice_eb6a1405af | avarice | 12/12 | https://github.com/crawl/crawl | 7c31f6e797 | crawl-ref/source/rltiles/UNUSED/monsters/deep_dwarf_death_knight.png #0 | GPL | 35.6% |
| ant_anger_7b0ce4d8c3 | anger | 12/12 | https://github.com/wesnoth/wesnoth | 7747be0ff7 | data/core/images/units/monsters/deep-tentacle-ranged-defend.png #0 | GPL | 38.8% |
| ant_anger_fb79893509 | anger | 12/12 | https://github.com/crawl/crawl | 7c31f6e797 | crawl-ref/source/rltiles/gui/spells/monster/summon_sin_beast.png #0 | GPL | 50.7% |
