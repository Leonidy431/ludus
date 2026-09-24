---
id: ludus-game-tab-integration
type: architecture
tags: [ludus, ui, game-tab, webtypicon2-integration, scene-controller]
related: [[DEMIURGE_ARCHITECTURE.md], [LUDUS_PROTOCOL.md], [CONSTITUTION.md]]
version: 1.0
status: active
---

# Ludus Game Tab Integration (U1)

**Scope:** Add "Games" top-level navigation item in webtypicon2 UI that launches the Ludus player dashboard and game interface.

**Contract:** Lazy-loaded Game Tab → Scene Controller state machine → Firebase real-time updates via i18n-reactive provider.

---

## 1. Architecture Overview

```
webtypicon2/public/index.html
├── Navigation Bar
│   ├── [Library]
│   ├── [Liturgy]
│   ├── [Corpus]
│   ├── [Games] ← NEW
│   │   └── On click: launch Scene Controller with scene="ludus-dashboard"
│   └── [Settings]
│
└── Scene Router
    ├── If scene === "ludus-dashboard"
    │   └── Load <LudusGameTab /> (lazy)
    │       ├── Player Profile Card
    │       ├── Quest Tracker
    │       ├── Knowledge Gates Panel
    │       ├── Marketplace Browse
    │       └── Faction Status
    │
    ├── If scene === "ludus-gate-challenge"
    │   └── <KnowledgeGateChallenge /> (scene params: gateId)
    │
    └── If scene === "ludus-quest-detail"
        └── <QuestDetailModal /> (scene params: taskId)
```

---

## 2. Components

### 2.1 Navigation Bar Update

**File:** `public/components/NavBar.tsx` (or `.js`)

```typescript
interface NavItem {
  id: string;
  labelKey: string;        // i18n key, e.g., "nav.games"
  icon?: string;           // Emoji or icon URL
  onClick: () => void;
  badge?: number;          // e.g., unread quest count
}

const NAV_ITEMS: NavItem[] = [
  { id: "library", labelKey: "nav.library", icon: "📚", onClick: () => scene("library") },
  { id: "liturgy", labelKey: "nav.liturgy", icon: "✝️", onClick: () => scene("liturgy") },
  { id: "corpus", labelKey: "nav.corpus", icon: "📖", onClick: () => scene("corpus") },
  // NEW:
  {
    id: "games",
    labelKey: "nav.games",
    icon: "🎮",
    onClick: () => scene("ludus-dashboard"),
    badge: playerUncompletedQuestCount, // Derived from Firestore
  },
  { id: "settings", labelKey: "nav.settings", icon: "⚙️", onClick: () => scene("settings") },
];
```

**Styling:** Obsidian design (strict, high-contrast).
- Active tab: gold underline (Obsidian theme).
- Icon + label centered.
- Responsive: hide label on mobile, show icon + badge only.

### 2.2 Ludus Dashboard Scene

**File:** `public/scenes/ludus-dashboard.tsx`

```typescript
interface LudusDashboardProps {
  userId: string;
  onNavigate: (scene: string, params?: Record<string, unknown>) => void;
}

export const LudusDashboard: React.FC<LudusDashboardProps> = ({ userId, onNavigate }) => {
  const { profile } = usePlayerProfile(userId);
  const { quests } = usePlayerQuests(userId);
  const { resources } = usePlayerResources(userId);
  const { gates } = usePlayerGates(userId);

  if (!profile) {
    return <LoadingSpinner />;
  }

  return (
    <div className="ludus-dashboard">
      <header>
        <h1>{profile.displayName}'s {{t "ludus.dashboard"}}</h1>
        <div className="player-stats">
          <Stat label={{t "stat.level"}} value={profile.stats.level} />
          <Stat label={{t "stat.experience"}} value={profile.stats.experience} />
          <Stat label={{t "resource.gold"}} value={resources.gold} icon="💰" />
          <Stat label={{t "resource.faith"}} value={resources.faith} icon="✨" />
        </div>
      </header>

      <section className="quests-tracker">
        <h2>{{t "ludus.active-quests"}}</h2>
        <QuestList
          quests={quests.filter((q) => q.status === "ACTIVE")}
          onQuestClick={(taskId) => onNavigate("ludus-quest-detail", { taskId })}
        />
      </section>

      <section className="knowledge-gates">
        <h2>{{t "ludus.knowledge-gates"}}</h2>
        <GatePanel
          gates={gates}
          onGateClick={(gateId) => onNavigate("ludus-gate-challenge", { gateId })}
        />
      </section>

      <section className="marketplace">
        <h2>{{t "ludus.marketplace"}}</h2>
        <MarketplaceBrowser userId={userId} />
      </section>

      <aside className="faction-status">
        <h3>{{t "ludus.faction"}}</h3>
        <FactionCard userId={userId} />
      </aside>
    </div>
  );
};
```

### 2.3 Knowledge Gate Challenge Scene

**File:** `public/scenes/ludus-gate-challenge.tsx`

```typescript
interface GateChallengeProps {
  gateId: string;
  userId: string;
  onComplete: (passed: boolean) => void;
}

export const KnowledgeGateChallenge: React.FC<GateChallengeProps> = ({
  gateId,
  userId,
  onComplete,
}) => {
  const { gate } = useGate(gateId);
  const [answer, setAnswer] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);
  const [feedback, setFeedback] = React.useState("");

  if (!gate) return <LoadingSpinner />;

  const handleSubmit = async () => {
    setSubmitting(true);
    try {
      const result = await submitGateAnswer(gateId, userId, answer);
      setFeedback(result.feedback || "");
      onComplete(result.passed);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="gate-challenge">
      <header>
        <h1>{gate.title}</h1>
        <p className="difficulty">{{t "difficulty"}} {gate.tier}/3</p>
      </header>

      <section className="question">
        <p>{gate.question}</p>
      </section>

      <textarea
        value={answer}
        onChange={(e) => setAnswer(e.target.value)}
        placeholder={{t "ludus.gate.answer-placeholder"}}
        disabled={submitting}
      />

      {feedback && <div className="feedback">{feedback}</div>}

      <button onClick={handleSubmit} disabled={submitting || !answer.trim()}>
        {{t "ludus.gate.submit"}}
      </button>
    </div>
  );
};
```

---

## 3. Firestore Queries & Real-Time Subscriptions

### 3.1 Player Profile Subscription

```typescript
function usePlayerProfile(userId: string) {
  const [profile, setProfile] = React.useState<PlayerProfile | null>(null);

  React.useEffect(() => {
    const docRef = db.collection("ludus_players").doc(userId);
    const unsubscribe = docRef.onSnapshot((snap) => {
      if (snap.exists) {
        setProfile(snap.data() as PlayerProfile);
      }
    });

    return unsubscribe;
  }, [userId]);

  return { profile };
}
```

### 3.2 Quests Query with Status Filter

```typescript
function usePlayerQuests(userId: string) {
  const [quests, setQuests] = React.useState<KairoticTask[]>([]);

  React.useEffect(() => {
    const q = query(
      collection(db, "ludus_tasks"),
      where("assignedPlayerId", "==", userId),
      orderBy("deadline", "asc") // Upcoming deadlines first
    );

    const unsubscribe = onSnapshot(q, (snap) => {
      setQuests(snap.docs.map((doc) => doc.data() as KairoticTask));
    });

    return unsubscribe;
  }, [userId]);

  return { quests };
}
```

---

## 4. i18n Integration

All UI strings use i18n keys (not hardcoded translations).

**File:** `public/i18n/ludus.json`

```json
{
  "nav.games": "Games",
  "ludus.dashboard": "Dashboard",
  "ludus.active-quests": "Active Quests",
  "ludus.knowledge-gates": "Knowledge Gates",
  "ludus.marketplace": "Marketplace",
  "ludus.faction": "Faction Status",
  "ludus.gate.answer-placeholder": "Type your answer here...",
  "ludus.gate.submit": "Submit Answer",
  "stat.level": "Level",
  "stat.experience": "Experience",
  "resource.gold": "Gold",
  "resource.faith": "Faith",
  "difficulty": "Difficulty"
}
```

**Reactive Locale Switching:**
```typescript
const { t, locale } = useTranslation();

React.useEffect(() => {
  // When user changes locale in settings, all rendered strings update instantly
  // (provided by i18n provider subscription)
}, [locale]);
```

---

## 5. Scene Controller Integration

The Ludus Game Tab is driven by Scene Controller state machine (per webtypicon2 CLAUDE.md).

```typescript
interface LudusScene {
  scene:
    | "ludus-dashboard"
    | "ludus-gate-challenge"
    | "ludus-quest-detail"
    | "ludus-marketplace";
  params?: {
    gateId?: string;
    taskId?: string;
    listingId?: string;
  };
  metadata?: {
    timestamp: number;
    userId: string;
  };
}

// Deacon instruction object (from Scene Controller to renderer):
interface DemonInstruction {
  scene: LudusScene;
  instructions: {
    layout: "full-width" | "sidebar" | "modal";
    showHeader: boolean;
    showNavBar: boolean;
    ariaLabel: string;
  };
}
```

---

## 6. Lazy Loading & Code Splitting

```typescript
// public/scenes/index.tsx
const LudusDashboard = React.lazy(() =>
  import("./ludus-dashboard").then((m) => ({ default: m.LudusDashboard }))
);

const KnowledgeGateChallenge = React.lazy(() =>
  import("./ludus-gate-challenge").then((m) => ({ default: m.KnowledgeGateChallenge }))
);

export const sceneMap: Record<string, React.ComponentType<any>> = {
  "ludus-dashboard": LudusDashboard,
  "ludus-gate-challenge": KnowledgeGateChallenge,
  // ... other scenes
};
```

---

## 7. Security & Access Control

### 7.1 Authentication Gate

```typescript
// All ludus routes require Firebase auth
const ludusRoutes = [
  "ludus-dashboard",
  "ludus-gate-challenge",
  "ludus-quest-detail",
  "ludus-marketplace",
];

function checkAuth(userId: string, scene: string): boolean {
  if (!ludusRoutes.includes(scene)) return true; // Non-ludus scenes unrestricted
  
  // Ludus scenes require:
  // 1. Valid Firebase UID
  // 2. Player profile exists in ludus_players
  // 3. No account restrictions (e.g., banned)
  
  return isAuthenticated && hasPlayerProfile(userId);
}
```

### 7.2 Rate Limiting (Client + Server)

- Client: max 1 quest submission / 2 seconds
- Server: Cloud Function middleware (see `functions/src/middleware/security.ts`)

---

## 8. Styling & Theme

**File:** `public/styles/ludus-theme.css`

```css
:root {
  --ludus-primary: #FFD700;      /* Gold */
  --ludus-secondary: #00FFFF;    /* Cyan */
  --ludus-bg-dark: #0a0a0a;      /* Near-black */
  --ludus-text: #e0e0e0;         /* Light gray */
  --ludus-accent-good: #00ff00;  /* Green (success) */
  --ludus-accent-bad: #ff4444;   /* Red (failure) */
}

.ludus-dashboard {
  display: grid;
  grid-template-columns: 1fr 300px;
  gap: 2rem;
  padding: 2rem;
  background: var(--ludus-bg-dark);
  color: var(--ludus-text);
  font-family: "Courier New", monospace; /* Obsidian aesthetic */
}

.ludus-dashboard header {
  grid-column: 1 / -1;
  border-bottom: 2px solid var(--ludus-primary);
  padding-bottom: 1rem;
}

.ludus-dashboard h1 {
  color: var(--ludus-primary);
  font-size: 2rem;
  text-transform: uppercase;
  letter-spacing: 2px;
}
```

---

## 9. Success Criteria (Phase 6-6d)

- [ ] NavBar includes "Games" tab with icon & badge.
- [ ] Clicking "Games" navigates to ludus-dashboard scene.
- [ ] Player Profile card displays (level, experience, resources).
- [ ] Quest Tracker shows active quests, sorted by deadline.
- [ ] Knowledge Gates panel lists locked/unlocked gates by tier.
- [ ] Marketplace browse functional (list items, filter by price/type).
- [ ] Faction status displays (name, members, player role).
- [ ] All text uses i18n keys; locale switching works.
- [ ] Lazy loading: game bundle loads only when tab clicked.
- [ ] Firebase Emulator smoke test passes (no auth errors).
- [ ] Mobile responsive: NavBar collapses to icon-only on phones.
- [ ] Zero regressions on existing webtypicon2 features.

---

## 10. Implementation Timeline

**Sprint Week 1 (7 days):**
- Day 1–2: NavBar update + Scene Controller integration.
- Day 3–4: Ludus Dashboard component + real-time profile subscription.
- Day 5: Knowledge Gates panel + gate-challenge scene.
- Day 6: Marketplace browser component.
- Day 7: Styling, i18n, Firebase Emulator test.

**Blocking Dependencies:**
- A8 (Firestore schema) must be finalized → schema validation (ludusTypes.ts) available.
- Demiurge simulation loop running → ludus_nodes, ludus_tasks queryable.

---

## 11. Files to Create/Modify

```
public/
├── components/
│   ├── NavBar.tsx (UPDATE: add Games tab)
│   ├── ludus/
│   │   ├── PlayerProfileCard.tsx (NEW)
│   │   ├── QuestList.tsx (NEW)
│   │   ├── GatePanel.tsx (NEW)
│   │   ├── MarketplaceBrowser.tsx (NEW)
│   │   └── FactionCard.tsx (NEW)
│
├── scenes/
│   ├── ludus-dashboard.tsx (NEW)
│   ├── ludus-gate-challenge.tsx (NEW)
│   ├── ludus-quest-detail.tsx (NEW)
│   └── ludus-marketplace.tsx (NEW)
│
├── i18n/
│   ├── ludus.json (NEW)
│   └── ludus.es.json (NEW, Spanish)
│
├── styles/
│   └── ludus-theme.css (NEW)
│
└── hooks/
    ├── usePlayerProfile.ts (NEW)
    ├── usePlayerQuests.ts (NEW)
    ├── usePlayerResources.ts (NEW)
    ├── useGate.ts (NEW)
    └── useMarketplace.ts (NEW)

functions/src/
├── schemas/
│   └── ludusTypes.ts (NEW)
└── api/
    └── ludus/ (NEW subdirectory)
        ├── routes.ts (NEW: /api/ludus/* endpoints)
        ├── gates.ts (NEW: gate submission handler)
        └── quests.ts (NEW: quest state updates)
```

---

**Next Action:** Once A6, A8, U1 specs complete, implement Phase 6-6d (estimated 5–7 days).

