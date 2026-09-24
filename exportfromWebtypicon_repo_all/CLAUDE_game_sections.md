# webtypicon2 CLAUDE.md — Game-Related Sections

Extracted from `/home/user/webtypicon2/CLAUDE.md` on 2026-09-24.

**Note:** These sections establish architectural standards that apply to game UI/contracts in webtypicon2 (WebXR VR mode). ludus (Roblox & Meta Quest VR) is **completely isolated** and uses its own CONSTITUTION.md for governance.

---

## Backend Invariants (apply to game data layer)

- The public API (`functions/src/api/router.ts`, mounted at `/api`) is **read-only and stateless**.
  Any new mutable surface (auth, bot, payments) goes in a **separate Cloud Function and separate
  Firestore collections**, never bolted onto the existing `api` function.
- Preserve graceful Firestore degradation: `getDb()` may return `null` and the API must still
  respond (see `functions/src/data/scraperCache.ts`).
- Idempotency is required for any new write/webhook path before it can merge.

## Reuse, don't reinvent (game auth patterns)

- Auth + role-based admin UI → follow the `feature/library-tab` pattern
  (`public/library/library.js`): lazy-loaded `firebase-*-compat` 10.12.2, `GoogleAuthProvider`,
  `signInWithPopup`, `getIdToken()` → `Authorization: Bearer`, role gate `_userRole === 'admin'`.
- Firestore access → lazy-init pattern from `scraperCache.ts`.
- Request security → reuse `functions/src/middleware/security.ts`
  (`rateLimitMiddleware`, `adminAuthMiddleware`).

## Interface Contract & Development Standard (Game UI/State)

Boundary between the compute core (Sandboxed Compute) and the reactive UI
(Firebase-emulated Renderer).

### 1. Contract-first

- Compute (backend) and UI talk **only** through strictly-typed JSON contracts. Neither side
  reaches into the other's internals.
- Compute returns a small, shaped payload — e.g. `{ entities: [...top N], metadata: { score_vector: [...] } }`
  — never raw dumps. Each entity carries **i18n keys**, not localized strings.
- The Renderer is a **dumb subscriber** to state (a state machine). It performs **no heavy
  computation** — only rendering and event dispatch.

### 2. Sandbox regulation

- Any "pick N of M by K params" selection is a **pure, deterministic function** (same input → same
  output), returning a fixed-size result (default: top 3).
- The sandbox **validates all input at the boundary** (JSON Schema / Zod) and has a
  **timeout guard**. Invalid input or timeout is an explicit, typed error — never a silent
  partial result.

### 3. Reactive Front-Stack (Firebase Emulator)

- UI is driven by a **Scene Controller** (scenario state machine). Each scene receives a
  declarative **"deacon instruction"** object that fully describes the UI state.
- **i18n** is applied live via a reactive provider subscribed to the i18n-key mapping in the data
  object — controls re-localize on locale change with no recompute.
- **Dev flow:** UI changes are tested **only** against the Firebase Emulator with **seed scripts**.
  Using live/production databases in development is forbidden.

### 4. Mandatory Structure for Architecture Answers

Every architecture/design response uses this order:
1. **CONTRACT** — the JSON exchange structure between nodes.
2. **VALIDATION** — the success criterion (what counts as an error / invalid state).
3. **BIAS** — where the bottleneck or race condition can arise.
4. **CODE** — clean, modular implementation (TypeScript preferred).

If a request violates the contract or architectural integrity, **signal the violation immediately**,
arguing from clean-code or performance principles rather than silently complying.
