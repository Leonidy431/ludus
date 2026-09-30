---
id: ludus-rov-lake-frontend
type: feature-specification
tags: [ludus, frontend, ROV, lake, webtypicon2-backend, vm8, integration]
version: 1.0
status: design-ready
date: 2026-09-28
---

# ROV Lake Tab — Ludus Frontend Integration

**Purpose:** Integrate webtypicon2 VM8 backend (panopticon-mirror-vm) as ROV Lake data source for ludus web frontend  
**Backend:** webtypicon2 panopticon-mirror-vm (port 8090, internal VPC)  
**Frontend:** ludus webtypicon2 tab or new standalone tab  
**Access:** IAP tunnel to VM8 (secure, no public endpoint)

---

## 1. VM8 Backend Infrastructure

### 1.1 Panopticon Mirror VM (VM8)

| Property | Value |
|----------|-------|
| **Hostname** | panopticon-mirror-vm |
| **Project** | studio-8655717756-3e0c1 |
| **Zone** | us-central1-a |
| **External IP** | 34.122.125.182 (static) |
| **Internal VPC IP** | 10.20.0.2 |
| **Type** | e2-small (2 vCPU, 2 GB RAM) |
| **OS** | Debian 12 |
| **Frontend Port** | 8090 (Translation Viewer / ROV Lake) |
| **Access Method** | IAP tunnel (secure, Google auth) |

### 1.2 VM8 Frontend Service

**Container:** Translation Viewer (Node/Express)  
**Location:** `webtypicon2/functions/viewer-server.js`  
**Purpose:** Serve web UI + API endpoints from local VM storage (no Firestore dependency)

**Deployed API Endpoints:**
```
GET  /health                  → 200 OK
GET  /api/service             → Liturgical service data (date, language params)
GET  /api/calendar            → Calendar/saint data for month
GET  /api/batch-status        → Translation batch job status
GET  /app.js                  → Frontend React/Vue app code
```

### 1.3 Data Model (VM8 Serves)

Data originates from webtypicon2's **liturgical corpus** (saints, services, calendar):
- Orthodox Liturgical texts (ENG, RU, and 30+ languages)
- Saint biographies + feast dates
- Troparia, kontakia, canons
- Translation status (% complete per language/book)

---

## 2. Ludus Frontend Integration Plan

### 2.1 Where to Add ROV Lake Tab

**Option A: Extend webtypicon2 ludus tab** (fastest)
- File: `webtypicon2/public/ludus-game.js`
- Add panel/tab for "ROV Lake" data viewer
- Reuse existing auth + UI framework

**Option B: New standalone ludus tab** (more isolation)
- File: `webtypicon2/public/ludus-rov-lake.html` (new)
- Separate JavaScript + CSS
- Call VM8 API endpoints directly
- Coordinate with ludus game state

**Recommendation:** Option A (extend ludus-game.js) — faster integration, less duplication

### 2.2 Frontend Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Ludus Web Browser                           │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  webtypicon2/ludus-game.js                                │ │
│  │  ├─ Game state (DemiurgeBridge)                           │ │
│  │  ├─ Player profile (Firestore)                            │ │
│  │  └─ NEW: ROV Lake data (VM8 backend)                      │ │
│  └───────────────────────────────────────────────────────────┘ │
│           │                                 │                   │
│           ▼                                 ▼                   │
│  [Firestore]                        [IAP Tunnel to VM8]        │
│  ludus_nodes,                       panopticon-mirror-vm:8090  │
│  ludus_edges                        /api/service, /api/calendar│
└─────────────────────────────────────────────────────────────────┘
            │                                 │
            ▼                                 ▼
    ┌──────────────────┐        ┌──────────────────────────┐
    │  Firebase/Ludus  │        │  webtypicon2 Corpus      │
    │  Game State      │        │  (Liturgy, Saints, etc)  │
    └──────────────────┘        └──────────────────────────┘
```

### 2.3 Integration Architecture

```typescript
// webtypicon2/public/ludus-game.js (extend)

class RovLakeManager {
  constructor(vm8Url: string) {
    this.vm8Url = vm8Url;  // https://localhost:8090 (via IAP tunnel)
    this.cache = new Map();  // Client-side caching
  }

  async getServiceData(date: string, lang: string) {
    // GET /api/service?date=2026-09-28&lang=en
    const key = `service:${date}:${lang}`;
    if (this.cache.has(key)) return this.cache.get(key);
    
    const response = await fetch(
      `${this.vm8Url}/api/service?date=${date}&lang=${lang}`
    );
    const data = await response.json();
    this.cache.set(key, data, 3600000);  // Cache 1 hour
    return data;
  }

  async getCalendarData(month: string) {
    // GET /api/calendar?month=2026-09
    const response = await fetch(
      `${this.vm8Url}/api/calendar?month=${month}`
    );
    return await response.json();
  }

  async getBatchStatus() {
    // GET /api/batch-status
    const response = await fetch(`${this.vm8Url}/api/batch-status`);
    return await response.json();
  }

  render() {
    // Populate UI with ROV Lake data
    // Tab shows: Batch progress, service for today, calendar, translations
  }
}

// In ludus game scene
const rovLake = new RovLakeManager('https://localhost:8090');
await rovLake.render();
```

---

## 3. Access Setup (For Development/Testing)

### 3.1 Prerequisites

**Local Machine:**
```bash
# Install Google Cloud SDK
# Linux/macOS: https://cloud.google.com/sdk/docs/install
# Windows: Download GoogleCloudSDKInstaller.exe

# Authorize with your Google account
gcloud auth login

# Set GCP project
gcloud config set project studio-8655717756-3e0c1
```

**User Permissions:**
- Must have `roles/iap.tunnelResourceAccessor` on project (one-time setup)
  ```bash
  gcloud projects add-iam-policy-binding studio-8655717756-3e0c1 \
    --member="user:lab767@gmail.com" \
    --role="roles/iap.tunnelResourceAccessor"
  ```

### 3.2 Create IAP Tunnel to VM8 (Development)

**Terminal 1 — Open persistent tunnel:**
```bash
gcloud compute start-iap-tunnel panopticon-mirror-vm 8090 \
  --local-host-port=localhost:8090 \
  --zone us-central1-a
```

**Terminal 2 — Use in browser/code:**
```
http://localhost:8090
```

### 3.3 Browser Access While Testing

In `ludus-game.js` (dev/test environment):
```typescript
const VM8_URL = process.env.NODE_ENV === 'development'
  ? 'http://localhost:8090'  // Via IAP tunnel
  : 'https://vm8.ludus.internal';  // Production (if exposed later)
```

---

## 4. Implementation Checklist

### Phase 1: Setup (Immediate — Sep 28)

- [ ] Verify gcloud CLI installed + auth configured
- [ ] Confirm IAP role assigned to lab767@gmail.com
- [ ] Test IAP tunnel connection: `gcloud compute ssh panopticon-mirror-vm --tunnel-through-iap`
- [ ] Confirm VM8 services are running (or document when they will be deployed)

### Phase 2: Frontend Integration (Sep 29)

- [ ] Create `RovLakeManager` class in webtypicon2/ludus-game.js
- [ ] Implement API client methods: `getServiceData()`, `getCalendarData()`, `getBatchStatus()`
- [ ] Add error handling + caching strategy
- [ ] Add UI panel/tab for ROV Lake (reuse webtypicon2 design system)
- [ ] Test with IAP tunnel from localhost:8090

### Phase 3: Manual Testing (Sep 30)

- [ ] Open IAP tunnel to VM8:8090
- [ ] Load ludus-game.html in browser
- [ ] Verify ROV Lake tab appears + loads data from VM8
- [ ] Check browser dev tools console for API errors
- [ ] Confirm data renders correctly (services, calendar, batch status)

### Phase 4: Quest 3 Device Testing (Oct 1)

- [ ] Deploy ludus with ROV Lake integration to webtypicon2
- [ ] Connect Quest 3 to WiFi
- [ ] Open web browser on device → ludus-game.html
- [ ] Interact with ROV Lake tab from device (VR mode + browser)
- [ ] Monitor for network/latency issues

---

## 5. API Contract (VM8 Endpoints)

### 5.1 Service Data

**Request:**
```
GET /api/service?date=2026-09-28&lang=en
```

**Response (200 OK):**
```json
{
  "date": "2026-09-28",
  "language": "en",
  "services": [
    {
      "id": "service:2026-09-28:matins",
      "type": "matins",
      "title": "Matins of the Holy Angels",
      "troparion": "Hail, O divine, ...",
      "kontakion": "Rejoice, O exalted ...",
      "verses": [...]
    },
    {
      "id": "service:2026-09-28:divine-liturgy",
      "type": "divine-liturgy",
      "title": "Divine Liturgy of St. John Chrysostom",
      ...
    }
  ],
  "translations": {
    "availability": "en:100%, ru:95%, es:30%, fr:0%"
  }
}
```

### 5.2 Calendar Data

**Request:**
```
GET /api/calendar?month=2026-09
```

**Response (200 OK):**
```json
{
  "month": "2026-09",
  "days": [
    {
      "date": "2026-09-01",
      "dayOfWeek": "Tuesday",
      "saints": [
        {
          "name": "Simeon Stylites the Younger",
          "commemoration": "major",
          "feastType": "righteous"
        }
      ],
      "fasting": "no-restriction"
    },
    ...
  ]
}
```

### 5.3 Batch Status

**Request:**
```
GET /api/batch-status
```

**Response (200 OK):**
```json
{
  "status": "running",
  "currentBatch": {
    "language": "es",
    "progress": "45/100 items translated",
    "estimatedCompletion": "2026-09-30T14:00:00Z"
  },
  "queue": [
    { "language": "fr", "priority": "high" },
    { "language": "de", "priority": "medium" }
  ]
}
```

### 5.4 Error Responses

```json
// 400 Bad Request — Invalid date/language
{
  "error": "Invalid date format. Expected YYYY-MM-DD",
  "requestedDate": "invalid-date"
}

// 503 Service Unavailable — VM8 offline
{
  "error": "Batch processor unavailable",
  "retryAfter": 300
}
```

---

## 6. Caching Strategy

**Client-Side Cache (IndexedDB):**
```typescript
async getServiceData(date: string, lang: string) {
  const cacheKey = `vm8_service_${date}_${lang}`;
  
  // Check IndexedDB (offline support)
  const cached = await idb.get('rov-lake', cacheKey);
  if (cached && isNotStale(cached.timestamp)) {
    return cached.data;
  }

  // Fetch from VM8
  const data = await fetch(`${VM8_URL}/api/service?date=${date}&lang=${lang}`)
    .then(r => r.json());

  // Cache for offline
  await idb.put('rov-lake', { [cacheKey]: data, timestamp: Date.now() });
  
  return data;
}
```

**Cache TTL:**
- Service data: 24 hours (changes daily)
- Calendar data: 7 days (static)
- Batch status: 5 minutes (updates frequently)

---

## 7. Error Handling & Fallbacks

```typescript
async function renderRovLake() {
  try {
    const serviceData = await rovLake.getServiceData(today, lang);
    displayService(serviceData);
  } catch (error) {
    if (navigator.onLine) {
      // Network error while online
      console.error('Failed to load ROV Lake data:', error);
      displayErrorMessage('ROV Lake service unavailable. Using cached data.');
      const cached = await idb.get('rov-lake', `vm8_service_${today}_${lang}`);
      if (cached) displayService(cached.data);
    } else {
      // Offline
      displayErrorMessage('Offline. ROV Lake unavailable.');
      const cached = await idb.get('rov-lake', `vm8_service_${today}_${lang}`);
      if (cached) {
        displayService(cached.data);
        addBadge('Cached data');
      }
    }
  }
}
```

---

## 8. Security Considerations

### 8.1 Access Control

- VM8 **internal-only** (no public endpoint)
- Browser → IAP tunnel → VM8:8090
- IAP authenticates via Google OAuth (built-in 2FA support)
- No API keys or secrets in frontend code

### 8.2 CORS Handling (If Frontend Deployed Separately)

VM8 Translation Viewer may need CORS headers for cross-origin requests:

```typescript
// webtypicon2/functions/viewer-server.js (add if needed)
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', 'https://ludus-game.web.app');
  res.header('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});
```

### 8.3 Data Privacy

- No PII transmitted (only liturgical data + batch status)
- Cache stored locally in IndexedDB (not sent anywhere)
- All traffic over HTTPS (IAP tunnel)

---

## 9. Timeline & Dependencies

| Milestone | Date | Duration | Blocker |
|-----------|------|----------|---------|
| Phase 1: IAP setup | Sep 28 | 15 min | None |
| Phase 2: Frontend code | Sep 29 | 2 hrs | Phase 1 complete |
| Phase 3: Manual testing | Sep 30 | 4 hrs | VM8 services deployed |
| Phase 4: Device testing | Oct 1 | 2 hrs | Phase 2 & 3 complete |

**Critical Path:** VM8 services must be deployed before manual testing (Sep 30).

---

## 10. References

- **webtypicon2 VM8 Access:** `webtypicon2/docs/PANOPTICON_VM_ACCESS.md`
- **VM8 Translation Viewer:** `webtypicon2/docs/HLD_VM_TRANSLATION_VIEWER.md`
- **Ludus Frontend:** `ludus/public/ludus-game.js`
- **Ludus Firestore Auth:** `ludus/docs/S12_FIRESTORE_AUTH.md`
- **Ludus Offline Sync:** `ludus/docs/A10_OFFLINE_SYNC.md`

---

**Status:** Ready for Phase 1 (IAP setup)  
**Owner:** Claude Haiku 4.5  
**Session:** 2026-09-28 10:50 UTC  
**Next:** Phase 1 IAP tunnel verification

## The view from the ROV: data and sources (2026-09-30)

- `public/ludus/ludus-lake-view.js` — the 360° window above the telemetry.
- `public/ludus/data/issyk-kul-fish.json` — 20 fish species with status,
  Red Book mark and loot rule (`keep` / `release`).
- `public/ludus/data/lake-objects-99.json` — 99 objects: every one of the
  80 real things of the register at least once
  (`scripts/lake/lake_objects.py`, `docs/LAKE_OBJECTS_99.md`).
- `docs/ISSYK_KUL_FISH.md` — the species list, its sources and what an
  ichthyologist, a geologist and an archaeologist must check before release.

