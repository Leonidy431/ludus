# STAGE 1 — High-Level Design

**Edge Services, IAM & Telegram Bot Integration**
Status: **DRAFT — awaiting architecture approval. No code is written until this HLD is approved.**
Release baseline: v1.34

---

## 0. Scope & non-goals

**In scope (STAGE 1):**
1. IAM / OAuth2.0 SSO — **Google + VK ID** — as the single entry point to the bot and admin area.
2. Admin panel UI components for managing the Telegram bot (webhooks, token rotation, rights).
3. API layer + bot service (Adapter Pattern): init / stop / command routing, kept out of the
   read-only monolith.
4. Declarative Telegram menu hierarchy as an immutable artifact (`config/tg_menu_schema.json`).
5. The **Sandbox isolation contour** that lets all of the above be built and proven without
   touching the production backend.

**Explicit non-goals (later stages):** bot command *business logic* depth, payments (STAGE 4),
ML/NLP translation (STAGE 5), UI/branding refactor (STAGE 2). Those are referenced only where they
constrain STAGE 1 interfaces.

---

## 1. Sandbox Isolation contour (PRIMARY DIRECTIVE)

The absolute priority is 100% uptime of the existing read-only liturgical API. STAGE 1 achieves
this through four independent layers of isolation.

### 1.1 Runtime isolation — a separate function
- New Cloud Function **`botApi`**, deployed independently of the production `api` function.
- The production `api` code path (`functions/src/index.ts` → `/api` router) is **not edited** in
  STAGE 1. A regression in `botApi` cannot affect `/api`.
- Bot/auth routes live under a distinct base path (`/botapi/**`) with their own Hosting rewrite.

### 1.2 Environment isolation — staging project + emulator
- **Local dev:** Firebase Emulator Suite (Auth + Functions + Firestore emulators) — already
  configured in `firebase.json` (ports 5001/5000/8080/9199).
- **Shared sandbox:** a **dedicated staging Firebase project** (`studio-…-staging`) added to
  `.firebaserc` as the `staging` alias.
- CI gate: feature branches deploy to **staging only**; `main` → prod. No feature reaches the prod
  project before an explicit, reviewed merge.

```
.firebaserc
{
  "projects": {
    "default": "studio-8655717756-3e0c1",
    "staging": "studio-8655717756-3e0c1-staging"
  }
}
```

### 1.3 Data isolation — disjoint collections
New collections only, never co-mingled with `liturgical_cache` / `calendar` / `saints`:

| Collection    | Purpose                                              |
|---------------|------------------------------------------------------|
| `users`       | SSO identities, roles/claims, linked telegram/vk ids |
| `bot_config`  | bot token ref, webhook state, menu version           |
| `bot_chats`   | Telegram chat ↔ optional user linkage, subscriptions |
| `bot_audit`   | admin actions (token rotation, webhook changes)      |

Firestore rules for these are user-scoped (`request.auth.uid == uid`) and admin-gated; the existing
public-read/deny-write rules for liturgical data are untouched.

### 1.4 Feature flag & idempotency gate
- `botApi` is simply **not deployed to prod** until sign-off (the ultimate kill switch); an env
  flag `BOT_ENABLED` additionally gates webhook processing.
- **Idempotency is a release gate**: every Telegram update is deduped on `update_id` (recorded in
  `bot_chats`/a processed-set) before any side effect, so retried webhooks are safe.

---

## 2. IAM / OAuth2.0 SSO (Google + VK ID)

### 2.1 Provider abstraction (Strategy Pattern)
A single `IdentityProvider` port so providers are pluggable and STAGE-1 risk is contained:

```
interface IdentityProvider {
  id: 'google' | 'vk';
  // returns a verified, normalized identity or throws
  authenticate(payload): Promise<{ providerUid; email?; displayName?; photoUrl? }>;
}
```

### 2.2 Google — native Firebase Auth
Reuse the proven `feature/library-tab` front-end flow:
`firebase-app-compat` + `firebase-auth-compat` 10.12.2 → `GoogleAuthProvider` →
`signInWithPopup` → `getIdToken()` → sent as `Authorization: Bearer` to `botApi`.

### 2.3 VK ID — custom-token exchange
VK is **not** a native Firebase provider, so we mint a Firebase identity ourselves:

```
Browser                         botApi (Cloud Function)              Firebase Auth / VK
  │ 1. VK ID widget → auth code        │                                   │
  │ 2. POST /botapi/auth/vk/exchange ─►│                                   │
  │        { code }                    │ 3. validate code w/ VK OAuth API ─►│ (VK)
  │                                    │◄─ 4. VK user id + profile          │
  │                                    │ 5. upsert users/{uid}              │
  │                                    │ 6. admin.auth().createCustomToken ►│ (Firebase)
  │◄── 7. { firebaseCustomToken } ─────│                                   │
  │ 8. signInWithCustomToken(token)    │                                   │
  │ 9. getIdToken() → Bearer to botApi │                                   │
```

`VK_APP_SECRET` lives in env / Secret Manager only.

### 2.4 Session, verification & RBAC
- All `botApi` protected routes use a new **`authMiddleware`** that calls
  `admin.auth().verifyIdToken()` and attaches `req.user = { uid, email, role }` — same shape and
  fail-closed posture as the existing `adminAuthMiddleware`.
- Roles `viewer | editor | admin` stored as Firebase **custom claims** + mirrored in `users/{uid}`.
- Admin-only routes additionally assert `role === 'admin'` (reuse the library-tab gate idea).

---

## 3. API Layer & Bot Service (Adapter Pattern)

### 3.1 botApi surface
```
/botapi/auth/google/session     POST   establish session from Google ID token
/botapi/auth/vk/exchange        POST   VK code → Firebase custom token
/botapi/me                      GET    current user + role            [auth]
/botapi/admin/bot/webhook       PUT    set/clear Telegram webhook     [admin]
/botapi/admin/bot/token         POST   rotate bot token (ref only)    [admin]
/botapi/admin/bot/rights        PUT    grant/revoke user roles        [admin]
/botapi/telegram/webhook/:secret POST  Telegram update intake         [secret-gated]
```
Reuses `rateLimitMiddleware`. Webhook authenticated by Telegram's
`X-Telegram-Bot-Api-Secret-Token` header **and** the path secret.

### 3.2 Adapter Pattern — Telegram out of the domain
```
Telegram Update ─► TelegramAdapter ─► BotCommand (internal domain event)
                                          │
                                          ▼
                              CommandRouter → handlers
                                          │
                                          ▼
                       reuse composeService() from serviceComposer.ts
                                          │
                                          ▼
                       TelegramAdapter.render() ─► sendMessage reply
```
- `TelegramAdapter` is the only module that knows Telegram's wire format. A future Discord/VK-bot
  adapter implements the same port without touching domain handlers.
- Bot **lifecycle** (init / stop / route) lives in the bot service layer, not the monolith — the
  prompt's "do not overload the monolith" requirement.

### 3.3 Reuse of existing infrastructure
- `composeService()` (`functions/src/composer/serviceComposer.ts`) for all liturgical answers.
- `liturgical_cache` (read path) for efficiency — no new write coupling.
- Firestore lazy-init pattern from `scraperCache.ts`.

---

## 4. Declarative Telegram Menu

- Menu hierarchy authored as an **immutable JSON artifact**: `config/tg_menu_schema.json`,
  conforming to the Telegram Bot API (`BotCommand[]` + inline-keyboard layouts).
- Loaded read-only at runtime; a `syncMenu` routine (admin-triggered) pushes it to Telegram via
  `setMyCommands` / menu-button APIs. The artifact is the single source of truth; runtime never
  mutates it.
- A schema validator (shape + Telegram constraints: command length, lowercase, ≤100 commands)
  runs in CI so a malformed menu cannot ship.

```jsonc
// config/tg_menu_schema.json  (shape illustration)
{
  "version": 1,
  "commands": [
    { "command": "today",   "description": "Service for today" },
    { "command": "date",    "description": "Pick a date" },
    { "command": "lang",    "description": "Choose language" }
  ],
  "menus": {
    "root": { "rows": [["today", "date"], ["lang"]] }
  }
}
```

---

## 5. Sequence diagrams (summary)

1. **Google SSO** — §2.2 flow → `authMiddleware` verifies ID token → `users/{uid}` upsert.
2. **VK custom-token exchange** — §2.3 diagram.
3. **Telegram message** — §3.2 adapter pipeline → `composeService` → reply (idempotent on
   `update_id`).
4. **Admin token rotation** — admin (role-gated) → `bot_config` update → `bot_audit` append →
   Telegram `setWebhook` re-registration.

---

## 6. Security & data contracts

**Threats & mitigations**
- Webhook spoofing → secret path + `X-Telegram-Bot-Api-Secret-Token` verification.
- Token leakage → bot token & `VK_APP_SECRET` in Secret Manager; never in client, logs, or git.
- Replay/duplication → `update_id` idempotency gate (§1.4).
- Privilege escalation → fail-closed `authMiddleware`; admin routes assert `role === 'admin'`.
- Abuse → `rateLimitMiddleware` on `botApi`.

**Document schemas (illustrative)**
```
users/{uid}     : { email, displayName?, photoUrl?, role: 'viewer'|'editor'|'admin',
                    providers: { google?: id, vk?: id, telegram?: id }, createdAt }
bot_config/main : { tokenRef, webhookUrl, webhookSecret, menuVersion, enabled, updatedAt }
bot_chats/{id}  : { chatId, uid?, lastUpdateId, subscriptions[], createdAt }
bot_audit/{id}  : { actorUid, action, target, at }
```

---

## 7. Forward note — read-only public API (STAGE 2 hint)
The existing public read API must remain **read-only**. STAGE 1 does not add mutable routes to it;
all new mutable surfaces live in `botApi`. STAGE 2 will add an explicit "read-only" statement to the
public API docs and verify it. Captured here so the boundary is intentional, not accidental.

---

## 8. Acceptance for this HLD
Approve if: prod `api` is provably untouched (§1.1), the staging+emulator split is explicit (§1.2),
Google+VK SSO flows are fully specified (§2), the Adapter boundary keeps Telegram out of the domain
(§3.2), and the menu is an immutable validated artifact (§4). On approval, STAGE 1 implementation
begins **on the emulator/staging contour only**.
