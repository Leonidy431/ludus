---
id: ludus-phase2-critical-blockers
type: implementation-guide
tags: [ludus, deployment, rate-limiting, monitoring, backup, critical-blockers]
version: 1.0
status: implementation-ready
date: 2026-09-28
---

# Phase 2 Critical Blockers — Implementation Plan

**Purpose:** Implement the "+1 unknown CRITICAL blocker" identified in PRE_DEPLOYMENT_CHECKLIST.md  
**Status:** 3 blockers identified; implementation ready  
**Timeline:** Sep 28 (today) — must complete before device testing (Oct 1)

---

## Overview: The "+1 Unknown Blocker" = 3 Interconnected Systems

Analysis of PRE_DEPLOYMENT_CHECKLIST.md items #3, #4, #5 reveals these are **interdependent**:

| System | Severity | Implement | Time |
|--------|----------|-----------|------|
| **Rate Limiting** | HIGH | Firestore rules + middleware | 30 min |
| **Monitoring & Alerts** | HIGH | Cloud Logging dashboard + alert policies | 45 min |
| **Backup & DR** | HIGH | Firestore automatic backups + restore test | 20 min |

Without these, device testing will likely fail when:
- Multiple clients hammer health/metrics endpoints → quota exceeded or cascading failures
- Backend errors occur silently → no observability for debugging
- Seed data is lost → impossible to recover state

---

## 1. Rate Limiting (Firestore Rules + Middleware)

### 1.1 Firestore-Level Rate Limit (Defense in Depth)

Add to `firestore.rules` to prevent collection abuse:

```javascript
// At the top of firestore.rules, add rate-limit helpers:

function isRateLimited(collection, uid) {
  // Check if user exceeded write quota in last minute
  let userCounter = get(/databases/$(database)/documents/ludus_rate_limits/$(uid));
  let now = request.time.toMillis();
  
  // Reset counter if older than 60 seconds
  if (userCounter == null || (now - userCounter.data.lastWrite) > 60000) {
    return false;  // Allow write
  }
  
  // Check if count exceeds limit (e.g., 30 writes/min for players, 100 for admins)
  let limit = isAdmin() ? 100 : 30;
  return userCounter.data.count >= limit;
}

// Example: Gate attempts limited to 1 per 5 seconds per player
match /ludus_gate_attempts/{attemptId} {
  allow create: if isAuthenticated() && 
                   !isRateLimited('ludus_gate_attempts', request.auth.uid) &&
                   request.resource.data.playerNodeId == getUserPlayerNodeId();
  
  // Auto-update rate limit counter after write
  // (Note: this requires a Cloud Function trigger; see 1.2)
}
```

**Simpler alternative** (for Phase 2): Use middleware-only rate limiting.

### 1.2 Middleware Rate Limiting (`functions/src/middleware/rateLimit.ts`)

Create new middleware file:

```typescript
// functions/src/middleware/rateLimit.ts

import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';

interface RateLimitConfig {
  windowMs: number;        // 60000 = 1 minute
  maxRequests: number;     // requests per window
  keyGenerator?: (req: functions.https.Request) => string;
}

/**
 * Middleware: Rate limiting via Firestore document counters.
 * Allows N requests per window per key (default: uid).
 */
export function rateLimit(config: RateLimitConfig) {
  return async (req: functions.https.Request, res: functions.Response, next: () => void) => {
    const key = config.keyGenerator?.(req) || req.user?.uid || req.ip;
    if (!key) {
      return res.status(400).json({ error: 'Could not determine rate limit key' });
    }

    const db = getFirestore();
    const counterRef = db.collection('ludus_rate_limits').doc(key);
    const now = Date.now();

    try {
      const result = await db.runTransaction(async (tx) => {
        const snap = await tx.get(counterRef);
        const data = snap.data();

        // Reset if window expired
        if (!data || (now - data.lastUpdate) > config.windowMs) {
          tx.set(counterRef, { count: 1, lastUpdate: now }, { merge: true });
          return true;  // Allow
        }

        // Check limit
        if (data.count >= config.maxRequests) {
          return false;  // Deny
        }

        // Increment counter
        tx.update(counterRef, { count: data.count + 1, lastUpdate: now });
        return true;  // Allow
      });

      if (!result) {
        return res.status(429).json({
          error: 'Rate limit exceeded',
          retryAfter: config.windowMs / 1000
        });
      }

      next();
    } catch (error) {
      console.error('[RateLimit] Error:', error);
      // Fail open on error (allow request)
      next();
    }
  };
}

// Presets for common scenarios
export const rateLimitPresets = {
  // Prevent endpoint hammering (health/metrics)
  healthEndpoint: {
    windowMs: 60000,   // 1 minute
    maxRequests: 30    // 30 requests per minute per user/IP
  },
  
  // Prevent brute-force on game actions
  gameAction: {
    windowMs: 60000,
    maxRequests: 10    // 10 actions per minute per player
  },
  
  // Admin operations (more lenient)
  admin: {
    windowMs: 60000,
    maxRequests: 100   // 100 ops per minute per admin
  }
};
```

### 1.3 Apply Rate Limiting to Endpoints

Update `functions/src/api/ludus-health.ts`:

```typescript
import { rateLimit, rateLimitPresets } from '../middleware/rateLimit';

export const ludusHealth = functions.https.onRequest(async (req, res) => {
  // Rate limit before auth check
  const limiter = rateLimit(rateLimitPresets.healthEndpoint);
  
  return new Promise((resolve) => {
    limiter(req, res, async () => {
      const authContext = await verifyIdToken(req.headers.authorization);
      
      // ... rest of handler
      res.json({ status: 'ok', /* ... */ });
      resolve(undefined);
    });
  });
});

export const ludusMetrics = functions.https.onRequest(async (req, res) => {
  const limiter = rateLimit(rateLimitPresets.admin);
  
  return new Promise((resolve) => {
    limiter(req, res, async () => {
      // ... auth + metrics logic
      resolve(undefined);
    });
  });
});
```

### 1.4 Testing Rate Limiting

```bash
# Test rate limit enforcement (should get 429 after N requests)
for i in {1..35}; do
  curl -s -w "\nStatus: %{http_code}\n" https://YOUR_PROJECT.cloudfunctions.net/ludusHealth
  sleep 0.1
done

# After 30 requests in 60 seconds, should see 429 Too Many Requests
```

---

## 2. Monitoring & Alerting

### 2.1 Enable Cloud Logging

```bash
# Verify Cloud Logging is enabled (it is by default)
gcloud projects describe ludus-dev --format="value(loggingConfig)"

# List existing logs
gcloud logging read "resource.type=cloud_function" --limit 10 --format=json
```

### 2.2 Create Cloud Logging Dashboard

Create `monitoring/logging-dashboard.yaml`:

```yaml
displayName: "Ludus v0.1 — Cloud Logging Dashboard"
mosaicLayout:
  columns: 12
  tiles:
    - width: 6
      height: 4
      widget:
        title: "Cloud Functions — Error Rate (last 24h)"
        xyChart:
          dataSets:
            - timeSeriesQuery:
                timeSeriesFilter:
                  filter: |
                    resource.type="cloud_function"
                    resource.labels.function_name=("ludusHealth" OR "ludusMetrics")
                    severity="ERROR"
                  aggregation:
                    alignmentPeriod: "60s"
                    perSeriesAligner: "ALIGN_RATE"
                  
    - width: 6
      height: 4
      widget:
        title: "Firestore — Rule Denials (last 24h)"
        xyChart:
          dataSets:
            - timeSeriesQuery:
                timeSeriesFilter:
                  filter: |
                    resource.type="cloud_firestore_database"
                    protoPayload.status.code=7
                  aggregation:
                    alignmentPeriod: "60s"
                    perSeriesAligner: "ALIGN_RATE"

    - width: 6
      height: 4
      widget:
        title: "Auth Failures (last 24h)"
        xyChart:
          dataSets:
            - timeSeriesQuery:
                timeSeriesFilter:
                  filter: |
                    resource.type="cloud_function"
                    jsonPayload.message=~"Auth.*failed"
                  aggregation:
                    alignmentPeriod: "60s"
                    perSeriesAligner: "ALIGN_COUNT"

    - width: 6
      height: 4
      widget:
        title: "Health Endpoint Latency (p99)"
        xyChart:
          dataSets:
            - timeSeriesQuery:
                timeSeriesFilter:
                  filter: |
                    resource.type="cloud_function"
                    resource.labels.function_name="ludusHealth"
                    metric.type="cloudfunctions.googleapis.com/execution_times"
                  aggregation:
                    alignmentPeriod: "60s"
                    perSeriesAligner: "ALIGN_PERCENTILE_99"

    - width: 12
      height: 4
      widget:
        title: "Recent Error Logs (Last 10)"
        logsPanel:
          filter: |
            resource.type="cloud_function"
            severity >= ERROR
          resourceNames:
            - projects/ludus-dev
```

Deploy dashboard:

```bash
# Create the dashboard
gcloud monitoring dashboards create --config-from-file=monitoring/logging-dashboard.yaml

# Verify creation
gcloud monitoring dashboards list
```

### 2.3 Create Alert Policies

Create alert for error rate spike:

```bash
# Create alert policy for high error rate
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Ludus: High Function Error Rate" \
  --condition-display-name="Error rate > 1% for 5 min" \
  --condition-threshold-value=0.01 \
  --condition-threshold-duration=300s
```

Manual setup via Console (easier for first deployment):
1. Cloud Console → Monitoring → Alerting → Create Policy
2. Condition:
   - Metric: `cloud_function/execution_times`
   - Filter: `function_name="ludusHealth" OR "ludusMetrics"`
   - Condition: Error rate (%) > 1% for 5 minutes
3. Notification: Create channel → Slack / PagerDuty / Email

---

## 3. Firestore Backups & Disaster Recovery

### 3.1 Enable Automated Backups

```bash
# Enable automated backups (Firestore on-demand)
gcloud firestore backups create \
  --location=us-central1 \
  --async

# Set up scheduled backups (daily at 2 AM UTC)
gcloud scheduler jobs create app-engine ludus-backup-daily \
  --schedule="0 2 * * *" \
  --http-method=POST \
  --uri="https://region-project.cloudfunctions.net/triggerBackup" \
  --oidc-service-account-email=YOUR_SERVICE_ACCOUNT@ludus-dev.iam.gserviceaccount.com
```

### 3.2 Create Backup Trigger Function

Create `functions/src/scheduled/backupTrigger.ts`:

```typescript
import * as functions from 'firebase-functions';
import { firestore } from 'firebase-admin';

/**
 * Scheduled Cloud Function to trigger daily Firestore backup.
 * Runs at 2 AM UTC via Cloud Scheduler.
 */
export const triggerBackup = functions.https.onRequest(async (req, res) => {
  try {
    const client = new firestore.v1.FirestoreAdminClient();
    
    const projectId = process.env.GCP_PROJECT;
    const databaseName = client.databasePath(projectId, '(default)');
    
    const timestamp = new Date().toISOString().split('T')[0];
    const backupId = `ludus-backup-${timestamp}`;
    
    const operation = await client.createBackup({
      parent: client.backupPath(projectId, 'us-central1'),
      backupId,
      backup: {
        database: databaseName,
      },
    });

    console.log(`[Backup] Started: ${backupId}`);
    res.json({
      status: 'backup_started',
      backupId,
      estimatedTime: '5-10 minutes'
    });
  } catch (error) {
    console.error('[Backup] Error:', error);
    res.status(500).json({ error: error.message });
  }
});
```

### 3.3 Test Restore Procedure

```bash
# List recent backups
gcloud firestore backups list

# Restore from backup (DESTRUCTIVE — test only)
gcloud firestore databases restore BACKUP_ID
# Confirm on prompt
```

Document in `docs/DISASTER_RECOVERY.md`:

```markdown
# Disaster Recovery Procedure

## Restore from Backup

1. List available backups:
   \`\`\`bash
   gcloud firestore backups list
   \`\`\`

2. Verify backup timestamp and size

3. **PRODUCTION WARNING:** Restore is destructive — it will replace all data.
   ```bash
   gcloud firestore databases restore BACKUP_ID
   ```

4. Verify data integrity:
   ```bash
   firebase firestore:inspect ludus_nodes | head -10
   ```

## Data Retention

- Backups retained for 90 days (default)
- Daily backups at 2 AM UTC
- Last 30 days always available
```

---

## 4. Implementation Checklist

### Immediate (Today — Sep 28)

- [ ] Create `functions/src/middleware/rateLimit.ts` (30 min)
- [ ] Update `ludusHealth` and `ludusMetrics` to use rate limiting (15 min)
- [ ] Build and test: `npm run build` (10 min)
- [ ] Create monitoring/logging-dashboard.yaml (20 min)

### Before Phase 2 Deployment

- [ ] Have Firebase Console open for backup enablement
- [ ] Deploy functions with rate limiting included
- [ ] Deploy Cloud Logging dashboard
- [ ] Verify alert policies are configured

### After Phase 2 Seed Data

- [ ] Test health endpoint with rate limiting
- [ ] Confirm logs appear in Cloud Logging dashboard
- [ ] Trigger manual backup and verify in console
- [ ] Document restore procedure for team

---

## 5. Integration with Phase 2 Deployment

The `phase2-deploy.sh` script should be updated to include rate limiting:

```bash
# In scripts/phase2-deploy.sh, add after Step 1:

echo "🔐 Step 1.5: Building with Rate Limiting..."
cd functions && npm run build && cd ..
if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi

echo "✅ Rate limiting middleware compiled"
```

---

## 6. Verification After Deployment

```bash
# 1. Verify rate limiting is active
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://YOUR_PROJECT.cloudfunctions.net/ludusHealth

# Repeat 31 times → should see 429 on 31st request

# 2. Check Cloud Logging dashboard
gcloud monitoring dashboards list --filter="displayName:Ludus"

# 3. Verify backups are scheduled
gcloud scheduler jobs list | grep ludus-backup

# 4. Confirm alert policies exist
gcloud alpha monitoring policies list --filter="displayName:Ludus"
```

---

## 7. Timeline Impact

| Task | Time | Cumulative |
|------|------|------------|
| Implement rate limiting | 30 min | 30 min |
| Set up monitoring dashboard | 45 min | 75 min |
| Configure backups | 20 min | 95 min |
| **Total for Phase 2A (Blocker)** | **95 min** | — |
| Phase 2 Firestore init (30 min) | 30 min | 125 min |
| Phase 2 Health check (10 min) | 10 min | 135 min |
| **TOTAL PHASE 2** | **135 min** (2.25 hrs) | — |

**Fits within Sep 28 timeline** ✅

---

**Status:** Ready for implementation  
**Owner:** Claude Haiku 4.5  
**Next Step:** Implement rate limiting middleware (§1.2)

