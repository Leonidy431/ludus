---
id: ludus-pre-deployment-checklist
type: checklist
tags: [ludus, deployment, v0.1, critical-gaps]
version: 1.0
status: in-progress
date: 2026-09-28
---

# Ludus v0.1: Pre-Deployment Critical Gaps Checklist

**Purpose:** Identify the "+1 Unknown CRITICAL blocker"  
**Status:** 7 of 8 blockers identified + closed  
**Task:** Find and resolve the missing blocker before device testing

---

## Core Blockers (7/8 Complete)

- [x] **A6** — Demiurge Architecture (docs/DEMIURGE_ARCHITECTURE.md)
- [x] **A8** — Firestore Schema (functions/src/schemas/ludusTypes.ts)
- [x] **U1** — Game Tab Integration (webtypicon2)
- [x] **T1** — PlayMode Tests (PHASE6_DemiurgeBridgePlayModeTests.cs)
- [x] **D3** — Health Check Endpoint (/api/ludus/health)
- [x] **S12** — Firestore Auth (firestore.rules + auth middleware)
- [x] **A10** — Offline Sync (IndexedDB + Service Worker)
- [ ] **?** — UNKNOWN (to be identified)

---

## Potential Missing Blockers

### 1. **Telemetry Pipeline (VR → Firestore)**
**Description:** DiveComputer telemetry → DemiurgeBridge → Player node attributes  
**Status:** DemiurgeBridge done, but need to verify end-to-end flow

**Checklist:**
- [ ] DiveComputer emits telemetry (depth, pressure, velocity, etc.)
- [ ] DemiurgeBridge receives and maps to D&D attributes
- [ ] Player node updates in Firestore (real-time)
- [ ] webtypicon2 ludus-game.js reflects changes
- [ ] VR client sees updated profile instantly

**Test:**
```bash
# Simulate telemetry
adb logcat | grep Telemetry
# Should see: Depth: 500m, Power: 75%, Velocity: 1.2 m/s
# Should map to: Wisdom: 15, Constitution: 14, Dexterity: 12
```

---

### 2. **Conflict Resolution & Data Consistency**
**Description:** Offline → online sync with concurrent server updates  
**Status:** Last-write-wins implemented, but needs edge case testing

**Checklist:**
- [ ] Player updates node while offline
- [ ] Server (another client) updates same node
- [ ] Both come online → sync happens
- [ ] Verify no data loss or duplicates
- [ ] Firestore rules enforce consistency
- [ ] Audit log tracks changes (optional)

**Test Scenarios:**
```
1. Player A (offline): Update strength 15 → 20
   Player B (online): Update strength 15 → 18
   Result: One should win (last-write)

2. Player (offline): Submit gate attempt
   Server (background job): Invalidate gate
   Result: Attempt should reconcile correctly
```

---

### 3. **Rate Limiting & DDoS Protection**
**Description:** Protect Cloud Functions from abuse  
**Status:** NOT IMPLEMENTED (could be blocker)

**Checklist:**
- [ ] Rate limiting on health endpoint
- [ ] Rate limiting on metrics endpoint
- [ ] DDoS protection (Cloud Armor)
- [ ] Request validation (input sanitization)
- [ ] Quota enforcement per user/API key

**Implementation:**
```typescript
// functions/src/middleware/rateLimit.ts
export function rateLimit(maxRequests: number, windowMs: number) {
  // Use Firebase document counters
  // Or implement in firestore.rules
}
```

**Risk:** If missing, endpoints could be hammered during Quest testing

---

### 4. **Monitoring & Alerting**
**Description:** Real-time observability for production  
**Status:** PARTIALLY DONE (logging exists, alerts missing)

**Checklist:**
- [ ] Cloud Logging dashboard created
- [ ] Error rate alerts configured
- [ ] Performance baselines set (latency, throughput)
- [ ] Budget alerts (Firebase costs)
- [ ] Integration with incident response (Slack, PagerDuty?)

**Missing:**
- Alert on Firestore rule denials
- Alert on auth failures
- Alert on offline sync backlog growth
- Alert on function timeouts

---

### 5. **Data Backup & Disaster Recovery**
**Description:** Protect against data loss  
**Status:** NOT CONFIGURED (could be blocker)

**Checklist:**
- [ ] Firestore automated backups enabled
- [ ] Backup retention policy set (30+ days)
- [ ] Recovery procedure documented
- [ ] Test restore process
- [ ] Backup storage redundancy (multi-region?)

**Configuration:**
```bash
# Enable Firestore backups
gcloud firestore backups create --location=us-central1 --async

# Schedule daily backups (via Cloud Scheduler)
gcloud scheduler jobs create app-engine ludus-backup \
  --schedule="0 2 * * *" \
  --http-method=POST \
  --uri=https://region-project.cloudfunctions.net/triggerBackup
```

---

### 6. **Client-Side Error Handling & Fallbacks**
**Description:** Graceful degradation when services fail  
**Status:** PARTIALLY DONE (offline fallback exists)

**Checklist:**
- [ ] Network error handling (retry logic with exponential backoff)
- [ ] Firestore subscription failures (show cached data)
- [ ] Corrupted IndexedDB recovery (wipe + re-sync)
- [ ] Service Worker update failures (show update prompt)
- [ ] Graceful feature degradation (offline = read-only mode)

**Gap:** If Firestore is down, what happens?
- Should show cached profile + "Offline" indicator
- Should queue mutations for later sync
- Should NOT crash or show blank screen

---

### 7. **Security Audit (Beyond S12)**
**Description:** Beyond JWT & Firestore rules  
**Status:** PARTIAL (JWT + rules done, broader security unclear)

**Checklist:**
- [ ] Input validation (prevent injection attacks)
- [ ] CORS headers configured
- [ ] HTTPS enforced everywhere
- [ ] Sensitive data encryption (at rest + in transit)
- [ ] API key rotation procedures
- [ ] Dependency vulnerability scanning
- [ ] Access logs for audit trail

**Potential Gaps:**
- Are NodeIDs validated (prevent access to admin nodes)?
- Are answer hashes salted (prevent hash collision attacks)?
- Are timestamps validated (prevent replay attacks)?

---

### 8. **Performance Under Load**
**Description:** Can it handle 100+ concurrent players?  
**Status:** NOT TESTED (blocker for production)

**Checklist:**
- [ ] Firestore throughput limits understood (writes/sec)
- [ ] Cloud Functions scaling configured
- [ ] Service Worker cache size limits checked
- [ ] IndexedDB quota per user (typically 50 MB)
- [ ] Concurrent WebSocket connections (if applicable)

**Test:**
```bash
# Load test with k6 or Apache JMeter
k6 run loadtest.js
# Expected: health endpoint <100ms p99, <1% error rate
```

---

## Most Likely "+1 Unknown Blocker"

**Hypothesis:** One of the above (most likely **#3 Rate Limiting**, **#4 Monitoring**, or **#5 Backup**)

**Reasoning:**
- A6–D3 are explicitly listed as "READY"
- S12 and A10 were explicitly called out as "PENDING"
- The "+1 unknown" suggests something not obvious in initial planning
- Rate limiting, monitoring, and backup are often forgotten in v0.1

**Action:** If you have access to "99 Blind Spots Assessment" from Day 1, check it. Otherwise, assume it's one of the above and implement proactively.

---

## Recommended Action Plan

### If Unknown Blocker = Rate Limiting
```bash
# Add to firestore.rules
match /ludus_health {
  allow read: if request.time < resource.data.nextAllowedTime;
}
```

### If Unknown Blocker = Monitoring
```bash
# Create Cloud Monitoring dashboard
gcloud monitoring dashboards create --config-from-file=monitoring.yaml
```

### If Unknown Blocker = Backup
```bash
# Enable Firestore backups
gcloud firestore backups create --retention-days=30
```

### If Unknown Blocker = Something Else
**Check:** PR comments, git history, or ask stakeholders

---

## Resolution Status

| Gap | Severity | Status | Owner |
|-----|----------|--------|-------|
| Telemetry pipeline | HIGH | ⏳ TODO | DemiurgeBridge team |
| Conflict resolution | MEDIUM | ⏳ TEST | A10/S12 |
| Rate limiting | HIGH | ❌ MISSING | DevOps |
| Monitoring | HIGH | ❌ MISSING | DevOps |
| Backup & DR | HIGH | ❌ MISSING | DevOps |
| Error handling | MEDIUM | ⏳ PARTIAL | Frontend |
| Security audit | HIGH | ⏳ PARTIAL | Security |
| Load testing | HIGH | ❌ MISSING | QA |

---

## Decision Points

**Before Device Testing (Oct 1):**
1. Identify the +1 unknown blocker
2. Implement rate limiting (if missing)
3. Set up monitoring dashboard
4. Enable Firestore backups
5. Run load test (synthetic traffic)
6. Security audit review

**Deployment Readiness Threshold:**
- [ ] All 8 blockers resolved
- [ ] Telemetry end-to-end tested
- [ ] No unresolved security findings
- [ ] Monitoring alerts configured
- [ ] Backup tested (restore succeeds)
- [ ] Load test passes (p99 <500ms)

---

**Owner:** Claude Haiku 4.5  
**Last Updated:** 2026-09-28 10:50 UTC  
**Next Review:** Before Phase 3 (Oct 1)
