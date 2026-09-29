---
id: ludus-cloud-functions-dialogue-api
type: backend-api
tags: [ludus, cloud-functions, firebase, dialogue, api, endpoints]
version: 1.0
status: ready-for-deployment
date: 2026-09-29
---

# Ludus Cloud Functions Dialogue API

**Purpose:** Backend endpoints for NPC dialogue system  
**Status:** Ready for deployment to Firebase  
**Coverage:** 5 core endpoints + admin seeding  
**Firestore Collections:** `ludus_dialogue_trees`, `ludus_npc_memory`, `ludus_dialogue_states`, `ludus_players`

---

## Overview

The Dialogue API provides backend services for:
1. Loading dialogue trees from Firestore
2. Managing NPC memory (player interaction history)
3. Persisting dialogue state (choices, attribute bonuses)
4. Tracking player dialogue engagement
5. Admin seeding of dialogue data

---

## API Endpoints

### 1. GET /api/ludus/dialogue/tree/{npcId}

**Purpose:** Load complete dialogue tree for an NPC

**Request:**
```bash
curl -X GET "https://us-central1-ludus.cloudfunctions.net/getDialogueTree?npcId=elder_sergius"
```

**URL Parameters:**
- `npcId` (required): NPC identifier (e.g., `elder_sergius`, `theodora`)

**Response:**
```json
{
  "npcId": "elder_sergius",
  "npcName": "Elder Sergius",
  "theology": "Apophatic Prayer & Hesychasm",
  "startNode": "sergius_001",
  "nodes": [
    {
      "id": "sergius_001",
      "text": "Welcome, seeker...",
      "branches": [
        {
          "text": "Teach me the desert's secrets",
          "condition": { "wisdom": 8 },
          "nextNodeId": "sergius_002",
          "attributeBonuses": { "wisdom": 2 },
          "narrativeEffect": "Sergius nods, recognizing your readiness."
        }
      ]
    }
  ]
}
```

**Status Codes:**
- `200`: Dialogue tree loaded successfully
- `404`: NPC dialogue tree not found
- `500`: Server error

**Client Usage (webtypicon2):**
```javascript
const tree = await LudusDialogueManager.loadDialogueTree('elder_sergius');
// Returns: DialogueTree object
```

---

### 2. GET /api/ludus/dialogue/memory/{npcId}/{playerId}

**Purpose:** Load NPC's memory of player interactions

**Request:**
```bash
curl -X GET "https://us-central1-ludus.cloudfunctions.net/getNpcMemory?npcId=elder_sergius&playerId=player123"
  -H "x-firebase-auth-user: player123"
```

**URL Parameters:**
- `npcId` (required): NPC identifier
- `playerId` (required): Player identifier

**Headers:**
- `x-firebase-auth-user` (optional): Player ID for auth check (prevents cross-player access)

**Response (First Meeting):**
```json
{
  "firstMeeting": true,
  "lastInteraction": null,
  "totalInteractions": 0,
  "choiceHistory": []
}
```

**Response (Returning Player):**
```json
{
  "firstMeeting": false,
  "lastInteraction": 1696010400000,
  "totalInteractions": 3,
  "choiceHistory": [
    {
      "nodeId": "sergius_001",
      "choice": "Teach me the desert's secrets",
      "timestamp": 1696010400000
    }
  ],
  "attributeBonusesEarned": {
    "wisdom": 5,
    "faith": 2
  }
}
```

**Status Codes:**
- `200`: Memory loaded (first meeting returns empty)
- `403`: Unauthorized (wrong player)
- `500`: Server error

**Client Usage:**
```javascript
const memory = await LudusDialogueManager.loadNpcMemory('elder_sergius');
// Returns: NpcMemory object
```

---

### 3. POST /api/ludus/dialogue/state

**Purpose:** Persist dialogue state after player makes a choice

**Request:**
```bash
curl -X POST "https://us-central1-ludus.cloudfunctions.net/persistDialogueState" \
  -H "Content-Type: application/json" \
  -d '{
    "playerId": "player123",
    "npcId": "elder_sergius",
    "currentNodeId": "sergius_002",
    "dialogueHistory": [
      {
        "nodeId": "sergius_001",
        "choiceIndex": 0,
        "choiceText": "Teach me the desert'\''s secrets",
        "attributeBonuses": { "wisdom": 2 },
        "timestamp": 1696010400000
      }
    ],
    "attributeBonuses": { "wisdom": 2 }
  }'
```

**Request Body:**
```typescript
{
  playerId: string;          // Player ID
  npcId: string;             // NPC ID
  currentNodeId: string;     // Current dialogue node
  dialogueHistory: Array<{   // All choices made in this session
    nodeId: string;
    choiceIndex: number;
    choiceText: string;
    attributeBonuses: Record<string, number>;
    timestamp: number;
  }>;
  attributeBonuses: Record<string, number>;  // Bonuses to apply
}
```

**Response:**
```json
{
  "success": true,
  "timestamp": 1696010400000,
  "bonusesApplied": ["wisdom", "faith"]
}
```

**Side Effects:**
1. **Updates Firestore:**
   - `ludus_dialogue_states/{playerId}_{npcId}` — dialogue history
   - `ludus_players/{playerId}/form` — player attributes (transactional)
   - `ludus_npc_memory/{npcId}/players/{playerId}` — NPC memory

2. **Player Attributes Update:**
   - Atomic transaction ensures consistency
   - Bonuses applied: `current_attribute + bonus_value`
   - Example: `wisdom: 10` + `+2 wisdom` → `wisdom: 12`

3. **NPC Memory Update:**
   - `totalInteractions++`
   - `lastInteraction` timestamp
   - `choiceHistory` appended
   - `attributeBonusesEarned` summed

**Status Codes:**
- `200`: State persisted successfully
- `400`: Invalid request body
- `405`: Method not allowed
- `500`: Server error

**Client Usage:**
```javascript
const result = await LudusDialogueManager.processChoice(branchIndex, playerAttributes);
// Internally calls persistDialogueState
```

---

### 4. GET /api/ludus/dialogue/stats/{playerId}

**Purpose:** Get player's dialogue engagement statistics

**Request:**
```bash
curl -X GET "https://us-central1-ludus.cloudfunctions.net/getDialogueStats?playerId=player123"
```

**URL Parameters:**
- `playerId` (required): Player identifier

**Response:**
```json
{
  "playerId": "player123",
  "npcInteractions": 3,
  "currentAttributes": {
    "wisdom": 12,
    "faith": 10,
    "dexterity": 8,
    "constitution": 9,
    "charisma": 7,
    "cunning": 5,
    "erudition": 11
  },
  "totalBonusesEarned": {
    "wisdom": 5,
    "faith": 3,
    "erudition": 2
  },
  "dialogueEngagementLevel": "intermediate"
}
```

**Engagement Levels:**
- `beginner`: 0–2 NPCs
- `intermediate`: 3–5 NPCs
- `advanced`: 6+ NPCs

**Status Codes:**
- `200`: Stats retrieved
- `404`: Player not found
- `500`: Server error

**Client Usage (Dashboard):**
```javascript
const stats = await fetch(`/api/ludus/dialogue/stats/${playerId}`).then(r => r.json());
// Display: "You've interacted with 3 NPCs, earning +5 Wisdom overall"
```

---

### 5. POST /api/ludus/dialogue/tree/{npcId} (ADMIN)

**Purpose:** Create or update dialogue tree (for seeding/admin)

**Request:**
```bash
curl -X POST "https://us-central1-ludus.cloudfunctions.net/upsertDialogueTree" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -d '{
    "npcId": "isaias",
    "npcName": "Isaias",
    "theology": "Cataphatic Teaching",
    "startNode": "isaias_001",
    "nodes": [...]
  }'
```

**Request Body:**
```typescript
{
  npcId: string;             // NPC ID (from URL)
  npcName: string;           // Display name
  theology: string;          // Theological focus
  startNode: string;         // First node ID
  nodes: DialogueNode[];     // All dialogue nodes
}
```

**Response:**
```json
{
  "success": true,
  "npcId": "isaias"
}
```

**Status Codes:**
- `200`: Tree created/updated
- `400`: Invalid structure
- `401`: Unauthorized
- `405`: Method not allowed
- `500`: Server error

**Admin Usage (Node.js):**
```bash
# Run seed script locally
npx ts-node functions/src/scripts/seedDialogueData.ts

# Or call cloud function with admin token
firebase functions:shell
> getDialogueTree('elder_sergius')
```

---

## Firestore Collections Schema

### `ludus_dialogue_trees/{npcId}`

```typescript
{
  npcId: string;
  npcName: string;
  theology: string;
  startNode: string;
  nodes: DialogueNode[];
}
```

**Example:** `/ludus_dialogue_trees/elder_sergius`

### `ludus_npc_memory/{npcId}/players/{playerId}`

```typescript
{
  firstMeeting: boolean;
  lastInteraction?: number;  // timestamp
  totalInteractions: number;
  choiceHistory: Array<{
    nodeId: string;
    choice: string;
    timestamp?: number;
  }>;
  attributeBonusesEarned?: Record<string, number>;
}
```

**Example:** `/ludus_npc_memory/elder_sergius/players/player123`

### `ludus_dialogue_states/{playerId}_{npcId}`

```typescript
{
  playerId: string;
  npcId: string;
  currentNodeId: string;
  dialogueHistory: Array<{
    nodeId: string;
    choiceIndex: number;
    choiceText: string;
    attributeBonuses: Record<string, number>;
    timestamp: number;
  }>;
  attributeBonusesThisSession: Record<string, number>;
  timestamp: number;
}
```

**Example:** `/ludus_dialogue_states/player123_elder_sergius`

---

## Deployment Instructions

### 1. Deploy to Firebase

```bash
# From ludus directory
cd functions
npm install
npm run build
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:getDialogueTree
```

**Expected Output:**
```
✓ functions[getDialogueTree] ... deployed at https://us-central1-ludus.cloudfunctions.net/getDialogueTree
✓ functions[getNpcMemory] ... deployed at https://us-central1-ludus.cloudfunctions.net/getNpcMemory
✓ functions[persistDialogueState] ... deployed at https://us-central1-ludus.cloudfunctions.net/persistDialogueState
✓ functions[getDialogueStats] ... deployed at https://us-central1-ludus.cloudfunctions.net/getDialogueStats
✓ functions[upsertDialogueTree] ... deployed at https://us-central1-ludus.cloudfunctions.net/upsertDialogueTree
```

### 2. Seed Dialogue Data

```bash
# Run locally with service account
export FIREBASE_PROJECT_ID=ludus-firestore
npx ts-node functions/src/scripts/seedDialogueData.ts

# Output:
# [Seed] Starting dialogue tree population...
# [Seed] ✅ Elder Sergius dialogue tree created
# [Seed] ✅ Theodora dialogue tree created
# [Seed] ✅ NPC memory documents created
# [Seed] ✅ All dialogue trees seeded successfully!
```

### 3. Verify Deployment

```bash
# Test getDialogueTree
curl "https://us-central1-ludus.cloudfunctions.net/getDialogueTree?npcId=elder_sergius"

# Should return 200 with dialogue tree JSON
```

---

## Frontend Integration (webtypicon2)

### In ludus-game.js:

```javascript
// Initialize dialogue manager
LudusDialogueManager.init(playerId);

// Load dialogue tree when NPC is clicked
async function onNpcClick(npcId) {
  try {
    const tree = await LudusDialogueManager.loadDialogueTree(npcId);
    const memory = await LudusDialogueManager.loadNpcMemory(npcId);
    
    // Show greeting based on memory
    if (memory.firstMeeting) {
      console.log('First meeting with this NPC');
    } else {
      console.log(`You've met this NPC ${memory.totalInteractions} times`);
    }
    
    // Initialize UI
    LudusDialogueUI.init(npcId, tree, playerAttributes, async (result) => {
      // Player made a choice
      if (result.attributeBonuses) {
        // Update player UI
        updatePlayerAttributes(result.attributeBonuses);
      }
    });
    
    // Render dialogue modal
    LudusDialogueUI.mount('ludus-dialogue-container');
    
  } catch (err) {
    console.error('Failed to load dialogue:', err);
  }
}
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| 404: Dialogue tree not found | NPC not seeded | Run seedDialogueData.ts |
| 403: Cannot access other player | Auth header mismatch | Remove x-firebase-auth-user or use correct playerId |
| 500: Failed to persist | Database error | Check Firestore rules and quotas |
| Network timeout | Cold start | Retry after 5 seconds (Cloud Functions warm-up) |

### Retry Strategy

```javascript
async function apiCallWithRetry(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i === maxRetries - 1) throw err;
      await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, i)));
    }
  }
}

// Usage
const tree = await apiCallWithRetry(() => 
  LudusDialogueManager.loadDialogueTree('elder_sergius')
);
```

---

## Performance & Limits

### Response Times

| Endpoint | Typical Response | Cold Start |
|----------|------------------|-----------|
| getDialogueTree | 50–100ms | 2–3s |
| getNpcMemory | 20–50ms | 2–3s |
| persistDialogueState | 100–200ms | 2–3s |
| getDialogueStats | 50–150ms | 2–3s |

### Firestore Limits (Free Tier)

- **Reads:** 50K/day
- **Writes:** 20K/day
- **Deletes:** 20K/day

**Estimated Monthly Usage (100 players):**
- Load dialogue tree: 3,000 reads/month
- Load NPC memory: 3,000 reads/month
- Persist state: 2,000 writes/month
- Get stats: 500 reads/month
- **Total:** ~5,500 reads, 2,000 writes (well under free tier)

---

## Testing Checklist

- [ ] Deploy all 5 endpoints to Firebase
- [ ] Run seedDialogueData.ts to populate trees
- [ ] Test getDialogueTree with curl
- [ ] Test getNpcMemory (first meeting)
- [ ] Test persistDialogueState (attribute updates)
- [ ] Verify NPC memory persists across sessions
- [ ] Test getDialogueStats
- [ ] Frontend integration test (webtypicon2)
- [ ] Error handling (404, 500)
- [ ] Performance test (load 1000 concurrent dialogues)

---

## Next Steps

1. **Oct 1:** Deploy to Firebase
2. **Oct 1:** Run seed script
3. **Oct 1–5:** Frontend integration & testing
4. **Oct 2–15:** Voice recording integration
5. **Nov 1–15:** Audio mixing with Wwise

---

**Owner:** Claude Haiku 4.5  
**Date:** 2026-09-29  
**Status:** Ready for deployment
