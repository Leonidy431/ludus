# Frontend-Backend Integration Testing Guide
## Phase 3 & Beyond — Verifying Web/Quest 3 App ↔ Cloud Functions

**Purpose:** Document integration testing between ludus-game.js frontend and Cloud Functions backend  
**Scope:** Browser (Chrome/Firefox), Quest 3 web app, Desktop PWA  
**Status:** Planning guide for Phase 3+ testing

---

## 📋 INTEGRATION TEST MATRIX

| Test ID | Component | Scenario | Prerequisites | Pass Criteria |
|---------|-----------|----------|---|---|
| **INT-001** | Dialogue Loading | Frontend loads dialogue tree from API | Emulator running, NPC seeded | 200 OK, tree data received <300ms |
| **INT-002** | Player Memory | Frontend fetches NPC memory, displays "first meeting" state | Player + NPC record in Firestore | Memory data matches stored record |
| **INT-003** | Choice Persistence | Frontend sends player choice to backend, verifies update | Firestore write completes | Attributes incremented in player doc |
| **INT-004** | Stats Display | Frontend shows aggregated stats after multiple NPCs | 4+ dialogue interactions | Stats endpoint returns correct totals |
| **INT-005** | Error Recovery | Frontend handles 404 gracefully | Nonexistent NPC requested | Error message shown, game continues |
| **INT-006** | CORS Preflight | Browser sends OPTIONS request, receives CORS headers | Chrome DevTools Network tab | Access-Control-Allow-Origin present |
| **INT-007** | Offline Sync | Frontend works offline, syncs when reconnected | WiFi toggled off/on | Queued requests sent after reconnect |
| **INT-008** | Mobile Responsiveness | Dialog UI works on Quest 3 (1832×1920 resolution) | Quest 3 device or emulator | Text readable, choices selectable at any size |

---

## 🧪 TEST SCENARIOS WITH CODE EXAMPLES

### INT-001: Dialogue Loading Flow

**Frontend Code (ludus-game.js):**
```javascript
async function loadDialogueForNpc(npcId) {
  try {
    console.log(`[LUDUS] Loading dialogue tree for NPC: ${npcId}`);
    
    const response = await fetch(`/api/ludus/dialogue/tree/${npcId}`);
    
    if (!response.ok) {
      throw new Error(`Failed to load dialogue (${response.status})`);
    }
    
    const dialogueTree = await response.json();
    
    // Verify structure
    if (!dialogueTree.npcId || !dialogueTree.nodes) {
      throw new Error('Invalid dialogue tree structure');
    }
    
    // Render dialogue UI
    renderDialogueUI(dialogueTree);
    return dialogueTree;
    
  } catch (err) {
    console.error('[LUDUS] Dialogue loading failed:', err);
    showErrorMessage(`Failed to load ${npcId}'s dialogue. Please try again.`);
  }
}
```

**Backend API Response (ludus-dialogue.ts):**
```typescript
{
  "npcId": "elder_sergius",
  "npcName": "Elder Sergius",
  "theology": "Hesychasm (Contemplative Prayer)",
  "startNode": "greeting",
  "nodes": [
    {
      "id": "greeting",
      "text": "Peace be with you, seeker of silence.",
      "branches": [
        {
          "text": "I seek understanding through contemplation",
          "nextNodeId": "contemplation_path",
          "attributeBonuses": { "wisdom": 2, "faith": 1 }
        }
      ]
    }
  ]
}
```

**Test Verification:**
```bash
# 1. Check response is valid JSON
curl -s http://localhost:5001/api/ludus/dialogue/tree/elder_sergius | jq .

# 2. Verify structure with grep
curl -s http://localhost:5001/api/ludus/dialogue/tree/elder_sergius \
  | jq '.nodes[0] | has("id", "text", "branches")'

# 3. Measure latency
time curl -s http://localhost:5001/api/ludus/dialogue/tree/elder_sergius > /dev/null
```

---

### INT-003: Choice Persistence Flow

**Frontend Sequence:**
```javascript
async function submitDialogueChoice(npcId, nodeId, choiceIndex, choiceText, bonuses) {
  try {
    // 1. Get current player
    const playerId = await getCurrentPlayerId();
    
    // 2. Prepare state update
    const dialogueState = {
      playerId,
      npcId,
      currentNodeId: nodeId,
      dialogueHistory: [
        {
          nodeId,
          choiceIndex,
          choiceText,
          attributeBonuses: bonuses,
          timestamp: Date.now()
        }
      ],
      attributeBonuses: bonuses
    };
    
    // 3. Send to backend
    const response = await fetch('/api/ludus/dialogue/state', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(dialogueState)
    });
    
    if (!response.ok) throw new Error(`Backend error: ${response.status}`);
    
    // 4. Update local UI state
    const result = await response.json();
    updatePlayerAttributesDisplay(result.currentAttributes);
    
    // 5. Show feedback
    showBonusAnimation(bonuses);
    
  } catch (err) {
    console.error('[LUDUS] Failed to persist choice:', err);
    showErrorMessage('Failed to save your choice. Please try again.');
  }
}
```

**Backend Persistence:**
```typescript
// 1. Validate input
if (!playerId || !npcId || !currentNodeId) {
  res.status(400).json({ error: 'Missing required fields' });
  return;
}

// 2. Update dialogue state collection
await db.collection('ludus_dialogue_states')
  .doc(`${playerId}_${npcId}`)
  .set(dialogueState, { merge: true });

// 3. Update NPC memory
await db.collection('ludus_npc_memory')
  .doc(npcId)
  .collection('players')
  .doc(playerId)
  .update({
    lastInteraction: Date.now(),
    totalInteractions: firebase.firestore.FieldValue.increment(1),
    'choiceHistory': firebase.firestore.FieldValue.arrayUnion({...choice})
  });

// 4. Update player attributes
await db.collection('ludus_players')
  .doc(playerId)
  .update({
    'form.wisdom': firebase.firestore.FieldValue.increment(bonuses.wisdom || 0),
    'form.faith': firebase.firestore.FieldValue.increment(bonuses.faith || 0),
    // ... other attributes
  });
```

**Test Verification:**
```bash
# 1. Send choice via API
curl -X POST http://localhost:5001/api/ludus/dialogue/state \
  -H "Content-Type: application/json" \
  -d '{
    "playerId": "test-player-001",
    "npcId": "elder_sergius",
    "currentNodeId": "greeting",
    "dialogueHistory": [{...}],
    "attributeBonuses": {"wisdom": 2}
  }'

# 2. Verify Firestore write (from emulator UI at localhost:4000)
# Collection: ludus_dialogue_states
# Document: test-player-001_elder_sergius
# Field: currentNodeId should equal "greeting"

# 3. Verify player attributes updated
# Collection: ludus_players
# Document: test-player-001
# Field: form.wisdom should be incremented
```

---

### INT-005: Error Handling & Recovery

**Scenario: NPC Not Found**

**Frontend:**
```javascript
async function handleMissingNpc(npcId) {
  try {
    const response = await fetch(`/api/ludus/dialogue/tree/${npcId}`);
    
    if (response.status === 404) {
      const error = await response.json();
      
      // Show user-friendly error with recovery options
      showErrorDialog({
        title: 'NPC Not Found',
        message: error.error,
        hint: error.recovery[0],
        actions: [
          { label: 'Try Again', onClick: () => loadDialogueForNpc(npcId) },
          { label: 'Go Back', onClick: () => navigateToNpcList() }
        ]
      });
    }
  } catch (err) {
    // Network error (not 404)
    showErrorDialog({
      title: 'Connection Error',
      message: 'Unable to reach the server',
      actions: [
        { label: 'Retry', onClick: () => location.reload() }
      ]
    });
  }
}
```

**Backend Response:**
```json
{
  "error": "Dialogue tree not found for NPC: nonexistent_npc",
  "context": {
    "npcId": "nonexistent_npc",
    "timestamp": "2026-10-01T09:15:30.123Z"
  },
  "recovery": [
    "Verify the NPC ID is spelled correctly",
    "Check if this NPC is available in your game version",
    "Try loading a different NPC"
  ]
}
```

**Test Verification:**
```bash
# 1. Request nonexistent NPC
curl http://localhost:5001/api/ludus/dialogue/tree/fake_npc

# Expected: 404 with error context
# 2. Verify error has recovery hints
# 3. Verify game doesn't crash (logs error gracefully)
```

---

### INT-006: CORS Preflight Testing

**Browser Network Tab Shows:**
```
OPTIONS /api/ludus/dialogue/tree/elder_sergius
→ 204 No Content
← Headers:
  Access-Control-Allow-Origin: *
  Access-Control-Allow-Methods: GET,POST,OPTIONS
  Access-Control-Allow-Headers: Content-Type,Authorization
```

**Test in Browser Console:**
```javascript
// Test CORS from different domain
fetch('http://localhost:5001/api/ludus/dialogue/tree/elder_sergius', {
  method: 'GET',
  headers: { 'Content-Type': 'application/json' }
})
.then(r => r.json())
.then(data => console.log('✓ CORS works:', data))
.catch(err => console.error('✗ CORS failed:', err.message));
```

**Expected:** Should work (no CORS error in console)

---

### INT-007: Offline Sync Testing

**Frontend Offline Queue:**
```javascript
class OfflineDialogueQueue {
  private queue: DialogueRequest[] = [];
  private isOnline: boolean = navigator.onLine;
  
  constructor() {
    window.addEventListener('online', () => this.syncQueue());
    window.addEventListener('offline', () => { this.isOnline = false; });
  }
  
  async sendDialogueChoice(choice: DialogueChoice) {
    if (this.isOnline) {
      // Send immediately
      return this.postToBackend(choice);
    } else {
      // Queue for sync
      this.queue.push({ choice, timestamp: Date.now() });
      console.log(`[LUDUS] Choice queued (offline). Queue size: ${this.queue.length}`);
    }
  }
  
  private async syncQueue() {
    this.isOnline = true;
    console.log(`[LUDUS] Syncing ${this.queue.length} queued requests...`);
    
    for (const request of this.queue) {
      try {
        await this.postToBackend(request.choice);
        this.queue.shift(); // Remove after success
      } catch (err) {
        console.error('[LUDUS] Sync failed, will retry:', err);
        break; // Stop on first failure
      }
    }
    
    console.log(`[LUDUS] Sync complete. ${this.queue.length} remaining.`);
  }
}
```

**Test Steps:**
1. Open game, load dialogue
2. Toggle WiFi off (turn off device WiFi)
3. Submit a choice → should show "offline" indicator
4. Toggle WiFi back on → should see "syncing..." + success
5. Verify choice persisted in Firestore

---

## 📊 INTEGRATION TEST CHECKLIST (Phase 3)

**Before Oct 1 09:00 UTC (Quest 3 Real Device):**
- [ ] CORS headers verified (INT-006)
- [ ] Error messages include recovery hints (INT-005)
- [ ] Offline queue logic implemented (INT-007)
- [ ] Dialog UI responsive at Quest 3 resolution (INT-008)

**During Oct 1 PM Testing:**
- [ ] INT-001: Load dialogue tree (60 sec)
- [ ] INT-002: Fetch NPC memory (30 sec)
- [ ] INT-003: Send choice + verify persistence (2 min)
- [ ] INT-004: Check stats aggregation (1 min)
- [ ] INT-005: Trigger errors, verify recovery (2 min)
- [ ] INT-006: Verify CORS in browser DevTools (1 min)
- [ ] INT-007: Test offline (2 min: go offline, act, come online)
- [ ] INT-008: Check responsiveness on Quest 3 screen (1 min)

**Total Time:** ~10 minutes integration testing

---

## 🔗 RELATED DOCUMENTS

- `docs/reports/PHASE_3_MASTER_CHECKLIST.md` — Overall readiness
- `INTEGRATION_TEST_SCENARIOS.md` — API-level test scenarios
- `API_ERROR_HANDLING_GUIDE.md` — Error handling reference
- `PERFORMANCE_PROFILING_BASELINE.md` — Performance targets
- `docs/reports/PHASE_3_QUEST3_TESTING_CHECKLIST.md` — Quest 3 specific tests

---

**Status:** 🟡 PLANNING (Implementation starts Phase 3)  
**Owner:** Claude Haiku 4.5  
**Target:** Phase 3 Oct 1-5, 2026
