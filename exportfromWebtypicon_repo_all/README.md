# Export from webtypicon2 Repository — Game-Related Materials

**Generated:** 2026-09-24  
**Source:** `/home/user/webtypicon2`  
**Purpose:** Archive of all game design, architecture, and implementation documents from webtypicon2 that inform ludus development.

---

## ⚠️ Isolation Note

**ludus is completely isolated from webtypicon2.** This export is for reference only. ludus (Roblox & Meta Quest VR) operates under its own CONSTITUTION.md and has NO shared code or liturgical content with webtypicon2 (the WebXR/Orthodox education game).

See: `/home/user/ludus/CONSTITUTION.md` § "МЕГА ТАБУ №1: АБСОЛЮТНАЯ ИЗОЛЯЦИЯ"

---

## Contents

### `/docs/`

- **LUDUS_PROTOCOL.md** — Protocol specification for ludus game state exchange (webtypicon2's WebXR mode)
- **STAGE1_HLD.md** — High-Level Design for Stage 1 game implementation

### `/root_files/`

- **TZ.md** — Technical Specification (Техническое Задание) — comprehensive game requirements

### `/game_orden_files/`

Collection of game design documents in Spanish/pseudo-Latin notation:

- **game_Orden** — Master game design specification (★★★ — largest file, core design)
- **Game_orden_2** — Secondary design addendum
- **game_orden_3 through game_orden_7** — Modular design sections covering specific game systems

**Note:** The "orden" suffix denotes structured design phases per the original project's freeorion-inspired architecture review (see ludus `reference_repo/`).

### `/CLAUDE_game_sections.md`

Extracted game-relevant sections from webtypicon2's CLAUDE.md:
- Backend invariants (API, Firestore patterns)
- UI contract standards (Scene Controller, deacon instruction pattern)
- Firebase Emulator dev flow

---

## How to Use This Export

1. **For ludus Roblox track:** Reference `/docs/LUDUS_PROTOCOL.md` for async PvP state contracts; see `game_Orden` for Daily Ludus core loop inspiration.
2. **For ludus VR track (Meta Quest):** Use STAGE1_HLD.md + TZ.md as reference architecture; apply contract-first patterns from `CLAUDE_game_sections.md`.
3. **For cross-repo questions:** Check `game_orden_*` files for detailed system design rationale.

---

## File Sizes

| File | Size | Purpose |
|------|------|---------|
| game_Orden | 3.3 MB | Master design spec |
| TZ.md | 59 KB | Technical requirements |
| Game_orden_2 | 117 KB | Secondary spec |
| game_orden_3..7 | 50–75 KB each | Modular systems |
| LUDUS_PROTOCOL.md | 5.7 KB | State exchange protocol |
| STAGE1_HLD.md | 10.6 KB | Stage 1 HLD |
| CLAUDE_game_sections.md | 3 KB | Architecture rules |

---

## Linked References

- ludus CONSTITUTION.md (isolation + taboo rules)
- ludus/Roblox/src/ (active Luau implementation)
- ludus/UnityVR/Assets/Scripts/ (active VR C# implementation)
- ludus/reference_repo/ (99 open-source game repos for design patterns)

---

**Do not merge any code from this export into ludus `main` or any ludus feature branch.** This folder is read-only reference. ludus develops independently under its own git history and deployment rules.
