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
