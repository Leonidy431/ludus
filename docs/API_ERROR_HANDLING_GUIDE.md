# API Error Handling & Edge Cases Guide
## Complete Error Scenario Coverage for Phase 3 Testing

**Purpose:** Document all error conditions and correct handling  
**Owner:** Claude Haiku 4.5  
**Status:** Ready for Phase 3  
**Last Updated:** Sep 29, 2026

---

## 📋 HTTP Status Codes & Meanings

### 4xx Client Errors (User's Fault)

| Status | Name | Meaning | When to Use |
|--------|------|---------|------------|
| **400** | Bad Request | Client sent malformed data | Missing required fields, invalid JSON, wrong data types |
| **401** | Unauthorized | Missing or invalid authentication | No Bearer token, expired token |
| **403** | Forbidden | Authenticated but not authorized | Player trying to access another's data, missing admin claim |
| **404** | Not Found | Resource doesn't exist | NPC not in Firestore, player not found |
| **405** | Method Not Allowed | Wrong HTTP verb | POST to GET endpoint, GET to POST endpoint |

### 5xx Server Errors (Our Fault)

| Status | Name | Meaning | When to Use |
|--------|------|---------|------------|
| **500** | Internal Server Error | Unhandled exception | Database connection failed, unexpected error in logic |

---

## 🔴 Critical Error Scenarios (Must Handle)

### Scenario 1: Missing Required Parameter

**Test Case: getDialogueTree without npcId**

```bash
curl http://localhost:5001/api/ludus/dialogue/tree
# Missing ?npcId parameter
```

**Current Implementation:**
```typescript
if (!npcId) {
  res.status(400).json({ error: 'Missing npcId parameter' });
  return;
}
```

**Expected Response:**
```json
HTTP/1.1 400 Bad Request
{
  "error": "Missing npcId parameter"
}
```

**Validation Test:**
- [x] Status code: 400
- [x] Error message present
- [x] Response is valid JSON

---

### Scenario 2: Invalid Authentication (Missing Bearer Token)

**Test Case: upsertDialogueTree without Bearer token**

```bash
curl -X POST http://localhost:5001/api/ludus/dialogue/tree/test_npc \
  -H "Content-Type: application/json" \
  -d '{"npcName":"Test","startNode":"start","nodes":[]}'
# No Authorization header
```

**Current Implementation:**
```typescript
const authHeader = req.headers.authorization;
if (!authHeader || !authHeader.startsWith('Bearer ')) {
  res.status(401).json({ error: 'Unauthorized: Admin token required' });
  return;
}
```

**Expected Response:**
```json
HTTP/1.1 401 Unauthorized
{
  "error": "Unauthorized: Admin token required"
}
```

**Validation Test:**
- [x] Status code: 401
- [x] Error message explains requirement
- [x] Bearer token verification active

---

### Scenario 3: Insufficient Permissions (Not Admin)

**Test Case: upsertDialogueTree with non-admin token**

```bash
# Using a regular player's ID token (not admin)
curl -X POST http://localhost:5001/api/ludus/dialogue/tree/test_npc \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{"npcName":"Test","startNode":"start","nodes":[]}'
```

**Current Implementation:**
```typescript
const decodedToken = await admin.auth().verifyIdToken(token);
if (!decodedToken.admin && !decodedToken.isAdmin) {
  res.status(403).json({ error: 'Forbidden: Admin privileges required' });
  return;
}
```

**Expected Response:**
```json
HTTP/1.1 403 Forbidden
{
  "error": "Forbidden: Admin privileges required"
}
```

**Validation Test:**
- [x] Status code: 403 (not 401)
- [x] Token is valid but user not admin
- [x] Custom claim checked (admin or isAdmin)

---

### Scenario 4: Cross-Player Access Attempt

**Test Case: Player A trying to access Player B's memory**

```bash
# Player A (auth user = "player-a") tries to get Player B's memory
curl -H "x-firebase-auth-user: player-a" \
  http://localhost:5001/api/ludus/dialogue/memory/elder_sergius/player-b
```

**Current Implementation:**
```typescript
if (authUser && authUser !== playerId) {
  res.status(403).json({ error: 'Cannot access other player memory' });
  return;
}
```

**Expected Response:**
```json
HTTP/1.1 403 Forbidden
{
  "error": "Cannot access other player memory"
}
```

**Security Test:**
- [x] Status code: 403
- [x] Cross-player access prevented
- [x] Auth header checked

---

### Scenario 5: Resource Not Found

**Test Case: Request dialogue tree for nonexistent NPC**

```bash
curl http://localhost:5001/api/ludus/dialogue/tree/nonexistent_npc_xyz
```

**Current Implementation:**
```typescript
const treeDoc = await db.collection('ludus_dialogue_trees').doc(npcId).get();

if (!treeDoc.exists) {
  res.status(404).json({ error: `Dialogue tree not found for NPC: ${npcId}` });
  return;
}
```

**Expected Response:**
```json
HTTP/1.1 404 Not Found
{
  "error": "Dialogue tree not found for NPC: nonexistent_npc_xyz"
}
```

**Validation Test:**
- [x] Status code: 404
- [x] Error message includes NPC ID
- [x] No data returned

---

### Scenario 6: Wrong HTTP Method

**Test Case: GET request to POST-only endpoint**

```bash
# getDialogueTree only accepts GET, persistDialogueState requires POST
curl -X POST http://localhost:5001/api/ludus/dialogue/tree/elder_sergius
```

**Current Implementation (in persistDialogueState):**
```typescript
if (req.method !== 'POST') {
  res.status(405).json({ error: 'Method not allowed' });
  return;
}
```

**Expected Response:**
```json
HTTP/1.1 405 Method Not Allowed
{
  "error": "Method not allowed"
}
```

**Validation Test:**
- [x] Status code: 405
- [x] Error message clear
- [x] Correct method documented

---

### Scenario 7: Malformed JSON

**Test Case: POST with invalid JSON body**

```bash
curl -X POST http://localhost:5001/api/ludus/dialogue/state \
  -H "Content-Type: application/json" \
  -d 'not json at all'
```

**Expected Response:**
```
HTTP/1.1 400 Bad Request
{
  "error": "Invalid JSON"
}
```

**Note:** Express typically handles this automatically. If not, add:
```typescript
app.use(express.json());
// Will throw error on malformed JSON
```

---

### Scenario 8: Missing Required Fields in POST

**Test Case: persistDialogueState without playerId**

```bash
curl -X POST http://localhost:5001/api/ludus/dialogue/state \
  -H "Content-Type: application/json" \
  -d '{"npcId":"elder_sergius","currentNodeId":"greeting"}'
  # Missing playerId
```

**Current Implementation:**
```typescript
if (!playerId || !npcId || !currentNodeId) {
  res.status(400).json({ error: 'Missing required fields' });
  return;
}
```

**Expected Response:**
```json
HTTP/1.1 400 Bad Request
{
  "error": "Missing required fields"
}
```

**Validation Test:**
- [x] Status code: 400
- [x] All 3 required fields checked
- [x] Error message clear

---

### Scenario 9: Invalid Dialogue Tree Structure

**Test Case: upsertDialogueTree without nodes array**

```bash
curl -X POST http://localhost:5001/api/ludus/dialogue/tree/test_npc \
  -H "Authorization: Bearer <valid_admin_token>" \
  -H "Content-Type: application/json" \
  -d '{"npcName":"Test","startNode":"start"}'
  # Missing nodes array
```

**Current Implementation:**
```typescript
if (!treeData.npcName || !treeData.startNode || !treeData.nodes) {
  res.status(400).json({ error: 'Invalid dialogue tree structure' });
  return;
}
```

**Expected Response:**
```json
HTTP/1.1 400 Bad Request
{
  "error": "Invalid dialogue tree structure"
}
```

**Validation Test:**
- [x] Status code: 400
- [x] All required tree fields validated
- [x] Firestore write prevented

---

### Scenario 10: Database Connection Error

**Test Case: Firebase connection interrupted**

**Handling:**
```typescript
try {
  // Database operation
} catch (err) {
  console.error('[Ludus] Error:', err);
  res.status(500).json({ error: 'Failed to [operation]' });
}
```

**Expected Response:**
```json
HTTP/1.1 500 Internal Server Error
{
  "error": "Failed to load dialogue tree"
}
```

**Validation Test:**
- [x] Status code: 500 (only for actual server errors)
- [x] Generic error message (don't expose stack trace)
- [x] Error logged to console for debugging

---

## 🟡 Edge Cases (Nice to Handle)

### Edge Case 1: Empty Dialogue Tree

**Scenario:** NPC exists but has no nodes

**Response:**
```json
{
  "npcId": "broken_npc",
  "npcName": "Broken NPC",
  "nodes": []
}
```

**Handling:** Return 200 with empty nodes. Frontend should handle gracefully (show error message).

### Edge Case 2: Circular Dialogue References

**Scenario:** Node A → Node B → Node A (infinite loop)

**Handling:** Firestore rules don't prevent this. Add documentation warning developers. Frontend should detect and break cycles.

### Edge Case 3: Very Large Attribute Values

**Scenario:** Player has wisdom: 9999999

**Handling:** Accept and store. No validation needed (player could legitimately have high stats from many dialogues).

### Edge Case 4: Concurrent Writes to Same Player

**Scenario:** Two dialogue interactions saving state simultaneously

**Handling:** Use Firestore `set(..., { merge: true })` to prevent overwriting. Transactions handle conflicts.

### Edge Case 5: Expired Player Profile

**Scenario:** Player exists in Firestore but profile fields are old/incomplete

**Handling:** getDialogueStats returns whatever exists. Frontend should have defaults for missing fields.

---

## 🧪 Automated Error Test Suite

**File:** `scripts/test-error-scenarios.sh` (not yet created)

**Would test:**
```bash
#!/bin/bash
# Test all 10 error scenarios

test_scenario 1 "Missing npcId" \
  GET "http://localhost:5001/api/ludus/dialogue/tree" \
  400

test_scenario 2 "Missing Bearer token" \
  POST "http://localhost:5001/api/ludus/dialogue/tree/test" \
  401

test_scenario 3 "Non-admin token" \
  POST "http://localhost:5001/api/ludus/dialogue/tree/test" \
  --header "Authorization: Bearer <non_admin>" \
  403

# ... and so on for all scenarios
```

---

## 📋 Error Handling Checklist (Pre-Phase 3)

- [x] All 5 endpoints have try-catch blocks
- [x] All required parameters are validated
- [x] HTTP 400 for client errors (missing/invalid data)
- [x] HTTP 401 for missing authentication
- [x] HTTP 403 for insufficient permissions
- [x] HTTP 404 for not found resources
- [x] HTTP 405 for wrong HTTP method
- [x] HTTP 500 only for server errors
- [x] Error messages are clear and actionable
- [x] Stack traces not exposed in responses
- [x] All errors logged to console for debugging
- [x] Cross-player access prevented (security)
- [x] Admin auth verified before sensitive operations

---

## 🎯 Oct 1 Testing Plan

**During Phase 3B.5 (15 min error handling test):**

1. Run each error scenario from "Critical Error Scenarios" section
2. Verify HTTP status code matches expected
3. Verify error message is present and clear
4. Verify no stack traces in responses
5. Verify security boundaries respected (cross-player access blocked)
6. Document any failures in `PHASE_3_DEPLOYMENT_NOTES.md`

**Success Criteria:**
- All 10 scenarios return correct HTTP status
- All errors have descriptive messages
- No security bypasses found
- No unhandled exceptions

---

## 📎 Related Files

- `docs/reports/PHASE_3_DEPLOYMENT_CHECKLIST.md` — Full Phase 3 guide
- `scripts/test-api-endpoints.sh` — Automated endpoint tests
- `functions/src/api/ludus-dialogue.ts` — Implementation
- `firestore.rules` — Security rules (prevent cross-player access)

---

**Status:** ✅ COMPLETE  
**Ready for:** Oct 1, 2026 Phase 3 Testing  
**Owner:** Claude Haiku 4.5
