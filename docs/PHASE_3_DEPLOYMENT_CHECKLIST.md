---
id: ludus-phase-3-deployment-checklist
type: deployment-guide
tags: [ludus, phase-3, testing, deployment, firebase, validation]
version: 1.0
status: active
date: 2026-09-29
phase: Phase 3 (Oct 1–5)
---

# Ludus Phase 3: Testing & Deployment Checklist
## Oct 1–5, 2026 | Quest 3 Launch Readiness

**Objective:** Deploy all Cloud Functions, seed dialogue data, verify APIs, integrate frontend, and achieve go/no-go status for Meta Quest 3 testing.

**Quality Gate:** All tests passing + manual verification on desktop/mobile/Quest 3 emulator.

---

## 📋 Pre-Deployment Validation (Sep 29–30)

### Code Review & Validation

- [ ] **TypeScript compilation** — No errors/warnings
  ```bash
  cd functions
  npm run build
  # Expected: ✓ Build successful, 0 errors
  ```

- [ ] **Linting** — ESLint passes all files
  ```bash
  npm run lint
  # Expected: No warnings/errors
  ```

- [ ] **Type safety** — All `any` types eliminated
  ```bash
  grep -r "any" functions/src --include="*.ts" | grep -v "admin.firestore.any"
  # Expected: Only safe patterns allowed (admin.firestore.any is acceptable)
  ```

- [ ] **Dependencies audit** — No critical vulnerabilities
  ```bash
  npm audit
  # Expected: 0 critical, 0 high vulnerabilities
  ```

### Firestore Rules Validation

- [ ] **Rules compile** — firestore.rules valid
  ```bash
  firebase deploy --only firestore:rules --dry-run
  # Expected: ✓ Dry run successful
  ```

- [ ] **Security rules** — Public read for dialogue trees, auth required for memory/state
  ```
  Rule: ludus_dialogue_trees/{npcId} — allow read by anyone
  Rule: ludus_npc_memory/{npcId}/players/{playerId} — allow read by auth users
  Rule: ludus_dialogue_states — allow read/write by auth users
  ```

### Environment Configuration

- [ ] **Firebase project configured**
  ```bash
  firebase projects:list
  # Expected: ludus-firestore in active list
  ```

- [ ] **.env.local** — Contains FIREBASE_PROJECT_ID (local development only)
  ```bash
  # functions/.env.local should exist with:
  # FIREBASE_PROJECT_ID=ludus-firestore
  # (NOT committed to git)
  ```

- [ ] **Service account** — Downloaded to ~/.firebase/ (local seed script only)
  ```bash
  ls -la ~/.firebase/ludus-firestore-service-account.json
  # Expected: file exists, readable by current user
  ```

---

## 🚀 Phase 1: Firebase Deployment (Oct 1, Morning)

### 1.1 Build & Deploy Cloud Functions

**Estimated time:** 5–10 minutes

```bash
# From /home/user/ludus/functions directory
cd /home/user/ludus/functions

# Step 1: Clean install
rm -rf node_modules package-lock.json
npm install

# Step 2: Build TypeScript
npm run build

# Expected output:
# > tsc
# ✓ Build complete

# Step 3: Deploy all functions
firebase deploy --only functions

# Expected output:
# ✓ functions[getDialogueTree] ... deployed at https://us-central1-ludus.cloudfunctions.net/getDialogueTree
# ✓ functions[getNpcMemory] ... deployed at https://us-central1-ludus.cloudfunctions.net/getNpcMemory
# ✓ functions[persistDialogueState] ... deployed at https://us-central1-ludus.cloudfunctions.net/persistDialogueState
# ✓ functions[getDialogueStats] ... deployed at https://us-central1-ludus.cloudfunctions.net/getDialogueStats
# ✓ functions[upsertDialogueTree] ... deployed at https://us-central1-ludus.cloudfunctions.net/upsertDialogueTree
```

**Checklist:**
- [ ] Build exits with code 0 (success)
- [ ] All 5 functions deployed successfully
- [ ] No timeout errors (cold start is expected on first call)
- [ ] Function logs appear in Cloud Console (https://console.cloud.google.com/functions)

### 1.2 Verify Deployment

```bash
# Check Cloud Console
open "https://console.cloud.google.com/functions?project=ludus-firestore"

# Expected: All 5 functions listed
# - getDialogueTree
# - getNpcMemory
# - persistDialogueState
# - getDialogueStats
# - upsertDialogueTree
```

**Checklist:**
- [ ] All functions appear in Cloud Console
- [ ] Status shows "OK" (green checkmark)
- [ ] Last deployed time is current (within last 5 minutes)

---

## 🌱 Phase 2: Data Seeding (Oct 1, Morning)

### 2.1 Seed Dialogue Data

**Estimated time:** 2–3 minutes

```bash
# From /home/user/ludus directory
export FIREBASE_PROJECT_ID=ludus-firestore
npx ts-node functions/src/scripts/seedDialogueData.ts

# Expected output:
# [Seed] Starting dialogue tree population...
# [Seed] ✅ Elder Sergius dialogue tree created
# [Seed] ✅ Theodora dialogue tree created
# [Seed] ✅ NPC memory document created for elder_sergius
# [Seed] ✅ NPC memory document created for theodora
# [Seed] ✅ NPC memory document created for isaias
# [Seed] ✅ NPC memory document created for abbot_moses
# [Seed] ✅ NPC memory document created for sister_catherine
# [Seed] ✅ All dialogue trees seeded successfully!
# [Seed] Total: 2 dialogue trees, 5 NPC memory documents
# [Seed] Seed complete. Exiting...
```

**Checklist:**
- [ ] Script exits with code 0
- [ ] All NPC memory documents created (5 total)
- [ ] Both dialogue trees seeded (Elder Sergius, Theodora)
- [ ] No Firebase connection errors

### 2.2 Verify Firestore Data

```bash
# Open Firestore Console
open "https://console.cloud.google.com/firestore/databases/collections?project=ludus-firestore"

# Verify collections exist:
# ✓ ludus_dialogue_trees
#   - Document: elder_sergius
#   - Document: theodora
# ✓ ludus_npc_memory
#   - Document: elder_sergius → Collection: players
#   - Document: theodora → Collection: players
#   - Document: isaias
#   - Document: abbot_moses
#   - Document: sister_catherine
```

**Checklist:**
- [ ] ludus_dialogue_trees collection exists
- [ ] At least 2 documents (elder_sergius, theodora)
- [ ] ludus_npc_memory collection exists
- [ ] At least 5 NPC memory documents
- [ ] Can expand documents to view fields

---

## 🧪 Phase 3: API Verification (Oct 1, Afternoon)

### 3.1 Test Dialogue Tree Endpoint

**Test 1: Get Elder Sergius Dialogue Tree**

```bash
curl -s "https://us-central1-ludus.cloudfunctions.net/getDialogueTree?npcId=elder_sergius" \
  | jq '.'

# Expected output (sample):
# {
#   "npcId": "elder_sergius",
#   "npcName": "Elder Sergius",
#   "theology": "Apophatic Prayer & Hesychasm",
#   "startNode": "sergius_001",
#   "nodes": [
#     {
#       "id": "sergius_001",
#       "text": "Welcome, seeker. The desert has long taught...",
#       "branches": [...]
#     },
#     ...
#   ]
# }

# Expected status: 200 OK
# Expected latency: 50–100ms (warm instance), 2–3s (cold start)
```

**Checklist:**
- [ ] Status code: 200
- [ ] Response contains npcId, npcName, theology, startNode, nodes
- [ ] startNode matches first node in nodes array
- [ ] All nodes have id, text, branches array

**Test 2: Get Theodora Dialogue Tree**

```bash
curl -s "https://us-central1-ludus.cloudfunctions.net/getDialogueTree?npcId=theodora" \
  | jq '.npcName'

# Expected output: "Theodora"
```

**Checklist:**
- [ ] Status code: 200
- [ ] npcName is "Theodora"

**Test 3: 404 Error Handling**

```bash
curl -s "https://us-central1-ludus.cloudfunctions.net/getDialogueTree?npcId=nonexistent" \
  | jq '.'

# Expected output:
# {"error": "Dialogue tree not found for NPC: nonexistent"}

# Expected status: 404
```

**Checklist:**
- [ ] Status code: 404
- [ ] Error message is descriptive

### 3.2 Test NPC Memory Endpoint

**Test 1: First Meeting (No Prior Memory)**

```bash
curl -s "https://us-central1-ludus.cloudfunctions.net/getNpcMemory?npcId=elder_sergius&playerId=player_test_001" \
  -H "x-firebase-auth-user: player_test_001" \
  | jq '.'

# Expected output:
# {
#   "firstMeeting": true,
#   "lastInteraction": null,
#   "totalInteractions": 0,
#   "choiceHistory": []
# }

# Expected status: 200
```

**Checklist:**
- [ ] Status code: 200
- [ ] firstMeeting: true
- [ ] totalInteractions: 0
- [ ] choiceHistory: empty array

**Test 2: 403 Cross-Player Access Prevention**

```bash
curl -s "https://us-central1-ludus.cloudfunctions.net/getNpcMemory?npcId=elder_sergius&playerId=player_test_001" \
  -H "x-firebase-auth-user: different_player" \
  | jq '.'

# Expected output:
# {"error": "Cannot access other player memory"}

# Expected status: 403
```

**Checklist:**
- [ ] Status code: 403 (when auth user differs from playerId)
- [ ] Error message is clear

### 3.3 Test Persist Dialogue State Endpoint

**Test 1: Save Player Choice**

```bash
curl -s -X POST "https://us-central1-ludus.cloudfunctions.net/persistDialogueState" \
  -H "Content-Type: application/json" \
  -d '{
    "playerId": "player_test_001",
    "npcId": "elder_sergius",
    "currentNodeId": "sergius_002",
    "dialogueHistory": [
      {
        "nodeId": "sergius_001",
        "choiceIndex": 0,
        "choiceText": "Teach me the desert'"'"'s secrets",
        "attributeBonuses": {"wisdom": 2},
        "timestamp": 1696010400000
      }
    ],
    "attributeBonuses": {"wisdom": 2}
  }' \
  | jq '.'

# Expected output:
# {
#   "success": true,
#   "timestamp": <unix_timestamp>,
#   "bonusesApplied": ["wisdom"]
# }

# Expected status: 200
```

**Checklist:**
- [ ] Status code: 200
- [ ] success: true
- [ ] timestamp is valid (current unix time)
- [ ] bonusesApplied contains applied attributes

**Test 2: Verify Firestore Writes**

After running Test 1, check Firestore:

```bash
# Verify dialogue state saved
# Navigate to: ludus_dialogue_states → player_test_001_elder_sergius

# Expected fields:
# - playerId: "player_test_001"
# - npcId: "elder_sergius"
# - currentNodeId: "sergius_002"
# - dialogueHistory: array with 1 entry
# - attributeBonusesThisSession: {wisdom: 2}
# - timestamp: current time
```

**Checklist:**
- [ ] Document created in ludus_dialogue_states
- [ ] All fields present and correct
- [ ] dialogueHistory has entry for sergius_001

### 3.4 Test Dialogue Stats Endpoint

**Test 1: Get Player Stats**

```bash
curl -s "https://us-central1-ludus.cloudfunctions.net/getDialogueStats?playerId=player_test_001" \
  | jq '.'

# Expected output (if player exists in ludus_players):
# {
#   "playerId": "player_test_001",
#   "npcInteractions": 1,
#   "currentAttributes": {...},
#   "totalBonusesEarned": {"wisdom": 2},
#   "dialogueEngagementLevel": "beginner"
# }

# Expected status: 200
```

**Checklist:**
- [ ] Status code: 200 (or 404 if player not in ludus_players)
- [ ] Fields: playerId, npcInteractions, currentAttributes, totalBonusesEarned, dialogueEngagementLevel

**Test 2: 404 Error for Non-Existent Player**

```bash
curl -s "https://us-central1-ludus.cloudfunctions.net/getDialogueStats?playerId=nonexistent_player" \
  | jq '.error'

# Expected output:
# "Player not found"

# Expected status: 404
```

**Checklist:**
- [ ] Status code: 404
- [ ] Error message: "Player not found"

### 3.5 Performance Baselines

**Record response times for baseline comparison:**

| Endpoint | Cold Start | Warm | Target | Status |
|----------|-----------|------|--------|--------|
| getDialogueTree | 2–3s | 50–100ms | < 500ms | ✓ |
| getNpcMemory | 2–3s | 20–50ms | < 500ms | ✓ |
| persistDialogueState | 2–3s | 100–200ms | < 500ms | ✓ |
| getDialogueStats | 2–3s | 50–150ms | < 500ms | ✓ |

**Checklist:**
- [ ] Record warm response times in table above
- [ ] All warm responses under 500ms
- [ ] Cold start delays documented (expected 2–3s)

---

## 🔗 Phase 4: Frontend Integration (Oct 2–3)

### 4.1 Integrate ludus-game.js with APIs

**File:** `webtypicon2/public/ludus/ludus-game.js`

```javascript
// In game initialization
async function initLudusGame() {
  // 1. Initialize dialogue manager
  LudusDialogueManager.init(playerId);
  
  // 2. Initialize audio manager
  LudusAudioManager.init();
  
  // 3. Add NPC click handler
  document.addEventListener('npc-click', async (event) => {
    const npcId = event.detail.npcId;
    await startDialogueWithNpc(npcId);
  });
}

// NPC interaction handler
async function startDialogueWithNpc(npcId) {
  try {
    // Load dialogue tree from API
    const response = await fetch(
      `https://us-central1-ludus.cloudfunctions.net/getDialogueTree?npcId=${npcId}`
    );
    
    if (!response.ok) {
      throw new Error(`Failed to load dialogue: ${response.status}`);
    }
    
    const dialogueTree = await response.json();
    
    // Initialize UI
    LudusDialogueUI.init(npcId, dialogueTree, playerAttributes, async (result) => {
      if (result.attributeBonuses) {
        // Persist to Firebase
        await persistChoice(npcId, result);
        updatePlayerUI(result.attributeBonuses);
      }
    });
    
    LudusDialogueUI.mount('ludus-dialogue-container');
  } catch (err) {
    console.error('Dialogue error:', err);
  }
}

async function persistChoice(npcId, result) {
  await fetch(
    'https://us-central1-ludus.cloudfunctions.net/persistDialogueState',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        playerId: getCurrentPlayerId(),
        npcId,
        currentNodeId: result.nextNodeId,
        dialogueHistory: result.dialogueHistory,
        attributeBonuses: result.attributeBonuses,
      }),
    }
  );
}
```

**Checklist:**
- [ ] ludus-game.js loads Cloud Functions endpoints
- [ ] NPC click handler triggers dialogue load
- [ ] Choice persistence implemented
- [ ] Attribute updates reflected in UI
- [ ] Error handling for network failures
- [ ] Retry logic for transient errors

### 4.2 HTML Setup

**Verify HTML contains:**

```html
<!-- Container for dialogue modal -->
<div id="ludus-dialogue-container"></div>

<!-- Script loading order -->
<script src="/ludus/ludus-npc-dialogue-manager.js"></script>
<script src="/ludus/ludus-audio-manager.js"></script>
<script src="/ludus/ludus-npc-dialogue-ui.js"></script>
<script src="/ludus/ludus-game.js"></script>

<!-- Stylesheet -->
<link rel="stylesheet" href="/ludus/ludus-dialogue.css">
```

**Checklist:**
- [ ] Dialogue container exists in DOM
- [ ] Scripts loaded in correct order
- [ ] Stylesheet linked

---

## 💻 Phase 5: Desktop Testing (Oct 2, Afternoon)

### 5.1 Browser Testing Setup

**Browser:** Chrome/Brave (with DevTools)  
**Network:** Throttle to "Slow 3G" to simulate mobile conditions

### 5.2 Test Flow: Load Dialogue Tree

**Scenario:** Click on Elder Sergius NPC in scene

```
Expected Sequence:
1. Click NPC in scene
2. Dialogue modal appears within 500ms
3. NPC name: "Elder Sergius"
4. Greeting text displays: "Welcome, seeker..."
5. 3 choice buttons appear (unlocked)
6. Audio theme plays (desert-bell-theme)
```

**Checklist:**
- [ ] Modal appears without layout shift
- [ ] NPC name and description display
- [ ] All 3 initial branches visible
- [ ] No locked choices (first meeting)
- [ ] Audio plays successfully (use DevTools Audio tab)
- [ ] No console errors (F12 → Console)

### 5.3 Test Flow: Make a Choice

**Scenario:** Click choice "Teach me the desert's secrets" (Wisdom ≥ 8)

```
Expected Sequence:
1. Button click registered
2. Loading indicator appears (optional)
3. New dialogue appears: "Good. You carry the mark..."
4. Attribute bonus displays: "+2 Wisdom"
5. UI updates show new attributes
6. Audio transitions (fade current music, play SFX)
7. 2 new choices appear
8. No console errors
```

**Checklist:**
- [ ] Choice click is responsive (< 200ms)
- [ ] Dialogue advances to sergius_002
- [ ] Attribute bonus shown (+2 Wisdom)
- [ ] Player attributes updated in UI
- [ ] Audio smooth transition (no gaps)
- [ ] New branches display correctly
- [ ] No network errors in Network tab

### 5.4 Test Flow: Multi-Branch Path

**Scenario:** Continue dialogue to completion

```
Expected Sequence:
1. Player chooses "How do I embrace this unknowing?" from sergius_002
2. Dialogue advances to sergius_005
3. Bonus: "+3 Wisdom, +2 Faith"
4. Only 1 choice available: "I will practice this daily"
5. Click final choice
6. Dialogue ends (no more branches)
7. Modal close button appears
8. Dialogue state persisted to Firestore
```

**Checklist:**
- [ ] Dialogue progresses through nodes without errors
- [ ] Bonuses accumulate correctly (+3W, +2F)
- [ ] Locked choices work (attribute requirements)
- [ ] Dialogue ends gracefully when nextNodeId is null
- [ ] Firestore write confirmed (check Network tab: POST to persistDialogueState)
- [ ] No memory leaks (DevTools Memory tab shows stable heap)

### 5.5 Performance Profiling (Desktop)

**Tools:** Chrome DevTools (Performance tab)

```bash
# Record 30-second performance trace:
1. Open DevTools → Performance tab
2. Click record (⚫)
3. Interact: Click NPC → Make 3 choices → Close dialogue
4. Stop recording (⏹)
5. Analyze flame chart

Expected metrics:
- First Contentful Paint (FCP): < 1s
- Largest Contentful Paint (LCP): < 2s
- Cumulative Layout Shift (CLS): < 0.1
- Frame rate: 60 FPS (no dropped frames)
```

**Checklist:**
- [ ] FCP < 1s
- [ ] LCP < 2s
- [ ] CLS < 0.1
- [ ] Frame rate stays at 60 FPS
- [ ] No long tasks (> 50ms)
- [ ] Memory usage stable (no rapid growth)

---

## 📱 Phase 6: Mobile Testing (Oct 3, Morning)

### 6.1 Devices to Test

| Device | OS | Screen | Test Lead |
|--------|----|----|-----------|
| iPhone SE (2020) | iOS 17 | 4.7" | Leonidy431 |
| Samsung Galaxy A13 | Android 12 | 6.5" | Leonidy431 |

### 6.2 Test Setup

**Steps:**
1. Open webtypicon2 on mobile device (via same WiFi)
2. Navigate to ludus game tab
3. Open DevTools remotely (Chrome: chrome://inspect)
4. Enable network throttling: "Slow 4G"

### 6.3 Test Flow: Basic Interaction

**Scenario:** Same as desktop, but on mobile

```
Expected Sequence (Mobile):
1. NPC appears in scene (touch-friendly size)
2. Tap NPC → Modal appears (full-screen on phone)
3. Text readable (min 16px font)
4. Buttons large enough to tap (min 44x44px)
5. No horizontal scroll
6. Touch interactions responsive (< 200ms)
7. Audio plays from device speaker
```

**Checklist:**
- [ ] Modal adapts to mobile viewport (< 480px)
- [ ] Font sizes readable (no pinch-zoom needed)
- [ ] Buttons meet accessibility size (44x44px)
- [ ] No horizontal scroll
- [ ] Touch latency < 200ms
- [ ] Audio plays (check speaker/headphones)
- [ ] No console errors

### 6.4 Performance Profiling (Mobile)

**Tools:** Chrome DevTools Remote Debugging

```bash
# Android (Chrome):
adb reverse tcp:9222 tcp:9222
chrome://inspect

# iOS (Safari):
Settings → Safari → Advanced → Web Inspector
connect Mac and open DevTools
```

**Expected metrics:**
- Load time: < 3s (on Slow 4G)
- Interaction to Paint (INP): < 100ms
- Memory: < 100MB
- Battery drain: acceptable (no runaway loops)

**Checklist:**
- [ ] Load time < 3s (4G throttle)
- [ ] INP < 100ms
- [ ] Memory < 100MB
- [ ] Battery drain < 1% per 5 minutes gameplay
- [ ] No thermal throttling

---

## 🥽 Phase 7: Meta Quest 3 Testing (Oct 4–5)

### 7.1 Quest 3 Setup

**Prerequisites:**
- Meta Quest 3 headset (paired with dev machine)
- Chromium browser on Quest (or Meta Horizon app)
- ADB installed on dev machine
- Proxy settings configured for HTTPS

### 7.2 Emulator Pre-Test (Oct 4, Morning)

**Setup Quest Emulator:**

```bash
# Start Android emulator
emulator -avd quest3_emulator -writable-system

# Allow remote debugging
adb devices

# Load ludus game in emulator browser
adb shell am start -a android.intent.action.VIEW \
  -d "https://webtypicon2.app/ludus-game"
```

**Test in Emulator:**
- [ ] Page loads without errors
- [ ] NPC dialogue appears
- [ ] Audio plays (via emulator audio)
- [ ] Choices work
- [ ] Firestore persistence works
- [ ] No Quest 3-specific errors

### 7.3 Real Device Testing (Oct 4–5, Afternoon)

**Preparation:**
1. Connect Meta Quest 3 via USB-C
2. Enable Developer Mode on Quest
3. Enable ADB access: Settings → Developer → ADB Debugging
4. Verify connection: `adb devices`

**Test Scenario 1: Scene Navigation**

```
Expected Sequence:
1. Game loads on Quest 3
2. Scene renders at 72 FPS (Quest baseline)
3. NPCs visible in 3D space
4. Head tracking works (look around NPC)
5. Controller input responsive (grab/point)
```

**Checklist:**
- [ ] Renders at 72+ FPS
- [ ] No black screen / blank render
- [ ] Scene load time < 2s
- [ ] Head tracking smooth
- [ ] Controller input recognized
- [ ] No Motion Sickness (check user report)

**Test Scenario 2: Dialogue in VR**

```
Expected Sequence:
1. Point at NPC with controller laser
2. Tap trigger to interact
3. Dialogue modal appears in VR (world-locked)
4. Text readable from 1m distance
5. Voice audio plays from NPC position (spatial audio)
6. Tap button to choose
7. Feedback audio plays (SFX)
8. Dialogue progresses smoothly
```

**Checklist:**
- [ ] Modal appears in VR space (not flat 2D overlay)
- [ ] Text at ~40px size (readable at 1m)
- [ ] Spatial audio: voice comes from NPC position (left/right/distance)
- [ ] SFX plays in correct layer (reduced when dialogue playing)
- [ ] No audio sync issues (lips/mouth lag)
- [ ] Choice buttons hit-testable via controller ray
- [ ] No jitter/judder during dialogue

**Test Scenario 3: Performance on Quest 3**

```bash
# Use Oculus Metrics Tool
adb shell am start -n com.oculus.metrics/com.oculus.metrics.MainActivity

# Monitor:
# - Frame rate: maintain 72 FPS
# - Memory: < 2GB active
# - Thermal: < 50°C (check headset temp)
# - GPU load: < 80%
```

**Checklist:**
- [ ] Frame rate stable at 72 FPS (no drops below 60)
- [ ] Memory < 2GB
- [ ] Temperature < 50°C
- [ ] GPU utilization < 80%
- [ ] Play session 10 min without crashes
- [ ] Thermal throttling does not occur

**Test Scenario 4: Audio Spatial Positioning**

```
Expected Test:
1. NPC positioned at 2m distance, 45° to the right
2. Voice audio should sound like it's coming from that position
3. Turn head 90° left — voice should now come from right side
4. Move closer to NPC — voice volume increases
5. Move behind NPC — audio pans to back (binaural HRTF)
```

**Checklist:**
- [ ] Audio panning matches NPC position
- [ ] Audio distance cues work (closer = louder)
- [ ] Head turn changes audio panning in real-time
- [ ] No audio lag (< 50ms latency)
- [ ] Binaural processing creates immersion (not dry/stereo)

### 7.4 Handoff to Wwise (Oct 5)

**Pre-Wwise Checklist:**
- [ ] All dialogue trees working in VR
- [ ] Audio mixing functional (4-layer system)
- [ ] Spatial audio basic implementation working
- [ ] No critical bugs blocking audio production
- [ ] Ready to hand off to Wwise team for professional integration

---

## 🎯 Go/No-Go Decision Criteria

### GO to Phase 4 (Voice Recording) if:

✅ **All of the following:**
- All 5 Cloud Functions deployed and responding
- Firestore data seeded successfully
- API tests (3.1–3.4) pass 100%
- Desktop tests (5.2–5.5) pass 100%
- Mobile tests (6.2–6.4) pass 100%
- Quest 3 emulator tests (7.2) pass 100%
- Quest 3 real device tests (7.3–7.4) pass 100%
- No critical bugs (P0) blocking production
- Performance targets met (< 500ms API, 72 FPS VR)
- Firestore free tier under 50% quota usage

### NO-GO to Phase 4 if:

❌ **Any of the following:**
- Functions fail to deploy or have runtime errors
- Firestore quota exceeded
- API tests fail (status codes, response format)
- Desktop tests fail on Chrome
- Mobile rendering issues (text unreadable, buttons unreachable)
- Quest 3 FPS drops below 60
- Audio spatial positioning not working
- Player attributes not persisting correctly
- Security/auth issues (cross-player access, leaks)
- Memory leaks or crashes on 10+ minute play sessions

**Decision Maker:** Leonidy431  
**Decision Date:** Oct 5, 5:00 PM UTC

---

## 📊 Test Results Summary Template

```markdown
# Phase 3 Test Results — Oct 1–5, 2026

## Pre-Deployment Validation
- [ ] TypeScript build: PASS / FAIL
- [ ] Linting: PASS / FAIL
- [ ] Firestore rules: PASS / FAIL

## Phase 1: Firebase Deployment
- [ ] Functions deployed: 5/5
- [ ] Cloud Console verification: PASS / FAIL
- [ ] Function logs accessible: YES / NO

## Phase 2: Data Seeding
- [ ] Seed script runtime: __ seconds
- [ ] Dialogue trees created: 2/2
- [ ] NPC memory documents: 5/5
- [ ] Firestore data verified: PASS / FAIL

## Phase 3: API Verification
- [ ] getDialogueTree: PASS / FAIL (latency: __ms)
- [ ] getNpcMemory: PASS / FAIL (latency: __ms)
- [ ] persistDialogueState: PASS / FAIL (latency: __ms)
- [ ] getDialogueStats: PASS / FAIL (latency: __ms)
- [ ] Error handling (404, 403): PASS / FAIL

## Phase 4: Frontend Integration
- [ ] ludus-game.js integration: PASS / FAIL
- [ ] HTML setup complete: YES / NO
- [ ] No console errors: YES / NO

## Phase 5: Desktop Testing (Chrome)
- [ ] Load dialogue tree: PASS / FAIL
- [ ] Make choice: PASS / FAIL
- [ ] Multi-branch path: PASS / FAIL
- [ ] Firestore persistence: PASS / FAIL
- [ ] Performance (FCP/LCP/CLS): PASS / FAIL

## Phase 6: Mobile Testing
- [ ] iPhone SE load: PASS / FAIL (time: __s)
- [ ] iPhone SE dialogue: PASS / FAIL
- [ ] Galaxy A13 load: PASS / FAIL (time: __s)
- [ ] Galaxy A13 dialogue: PASS / FAIL
- [ ] Mobile performance: PASS / FAIL

## Phase 7: Meta Quest 3 Testing
- [ ] Emulator load: PASS / FAIL
- [ ] Emulator dialogue: PASS / FAIL
- [ ] Quest 3 real device load: PASS / FAIL (FPS: __/72)
- [ ] Quest 3 dialogue in VR: PASS / FAIL
- [ ] Spatial audio positioning: PASS / FAIL
- [ ] 10-min play session stable: YES / NO
- [ ] Temperature < 50°C: YES / NO

## Critical Issues Found
1. [Issue #1]: [Description] — RESOLVED / BLOCKED
2. [Issue #2]: [Description] — RESOLVED / BLOCKED
3. ...

## Overall Decision
**GO to Phase 4 (Voice Recording)** / **NO-GO, retry Oct __**

**Signed by:** Leonidy431  
**Date:** Oct __, 2026  
**Time:** __ UTC
```

---

## 📝 Deployment Runbook (Oct 1–5)

### Mon Oct 1
- **09:00** — Pre-deployment validation (1–2 hours)
- **11:00** — Firebase deployment (10 min)
- **11:15** — Data seeding (3 min)
- **11:30** — API verification (1–2 hours)
- **14:00** — Desktop testing begins (Chrome)

### Tue Oct 2
- **09:00** — Desktop testing continues (performance profiling)
- **14:00** — Mobile testing setup (iPhone/Galaxy)
- **16:00** — Mobile test execution

### Wed Oct 3
- **09:00** — Mobile testing completion (performance analysis)
- **14:00** — Quest 3 emulator testing
- **18:00** — Real Quest 3 device testing prep

### Thu Oct 4
- **09:00** — Quest 3 emulator testing execution
- **14:00** — Real Quest 3 device testing (afternoon/evening)

### Fri Oct 5
- **09:00** — Quest 3 testing continuation (edge cases, stress)
- **14:00** — Results compilation
- **17:00** — Go/No-Go decision meeting
- **18:00** — Handoff to Phase 4 or retry planning

---

## 🔒 Security Checklist

- [ ] Cloud Functions have no hardcoded secrets
- [ ] Firestore rules enforce user authentication where needed
- [ ] API endpoints validate input (no SQL injection, XSS)
- [ ] Sensitive data (API keys, service accounts) stored in Secret Manager
- [ ] HTTPS enforced on all Cloud Functions
- [ ] CORS headers configured correctly (allow webtypicon2 origin only)
- [ ] User can only access their own dialogue state/memory
- [ ] Admin functions protected (upsertDialogueTree requires auth)

---

## ✅ Final Sign-Off

**Checklist Summary:**

| Category | Items | Passing | Status |
|----------|-------|---------|--------|
| Pre-Deployment | 4 | _/4 | ⏳ |
| Firebase Deploy | 2 | _/2 | ⏳ |
| Data Seeding | 2 | _/2 | ⏳ |
| API Verification | 5 | _/5 | ⏳ |
| Frontend Integration | 3 | _/3 | ⏳ |
| Desktop Testing | 5 | _/5 | ⏳ |
| Mobile Testing | 4 | _/4 | ⏳ |
| Quest 3 Testing | 8 | _/8 | ⏳ |
| Security | 8 | _/8 | ⏳ |
| **TOTAL** | **41** | **_/41** | **⏳** |

**Phase 3 Status:** 🟡 READY FOR DEPLOYMENT  
**Target Completion:** Oct 5, 2026 (5:00 PM UTC)  
**Next Phase:** Phase 4 — Voice Recording (Oct 2–Nov 15)

---

**Owner:** Claude Haiku 4.5  
**Date Created:** 2026-09-29  
**Last Updated:** 2026-09-29  
**Status:** Active — Ready for Execution
