---
id: ludus-vm8-backend-container
type: deployment-guide
tags: [ludus, vm8, docker, backend, panopticon-mirror-vm, container, deployment]
version: 1.0
status: design-ready
date: 2026-09-28
---

# VM8 Backend Container Deployment — Ludus Services on panopticon-mirror-vm

**Purpose:** Deploy Ludus game backend services in Docker on VM8 (panopticon-mirror-vm)  
**Infrastructure:** Google Cloud Platform e2-small (2 vCPU, 2 GB RAM)  
**Access:** IAP tunnel (secure, no public endpoint)  
**Services:** API gateway, telemetry collector, attribute mapper

---

## 1. VM8 Infrastructure Review

### 1.1 Current State

| Property | Value |
|----------|-------|
| **Hostname** | panopticon-mirror-vm |
| **Project** | studio-8655717756-3e0c1 |
| **Zone** | us-central1-a |
| **IP (Internal VPC)** | 10.20.0.2 |
| **IP (External)** | 34.122.125.182 (static) |
| **Machine Type** | e2-small (2 vCPU, 2 GB RAM) |
| **OS** | Debian 12 |
| **Docker** | ✅ Installed |
| **Storage** | `/data` mount (20 GB, pd-balanced) |
| **Network** | Isolated VPC (`panopticon-vpc`) |

### 1.2 Docker Status on VM8

```bash
# SSH to VM8
gcloud compute ssh panopticon-mirror-vm --zone us-central1-a --tunnel-through-iap

# Check Docker
docker --version
docker ps  # Should show 0-2 containers (existing translation services)
```

---

## 2. Ludus Backend Architecture (VM8-Deployed)

```
┌─────────────────────────────────────────────────────────────┐
│               VM8 (panopticon-mirror-vm)                    │
│                 Debian 12 + Docker                          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Docker Network: ludus-backend                       │  │
│  │                                                       │  │
│  │  ┌────────────────┐  ┌────────────────┐             │  │
│  │  │ ludus-api      │  │ ludus-metrics  │             │  │
│  │  │ Node.js/Express│  │ Monitoring     │             │  │
│  │  │ Port: 3000     │  │ Port: 3001     │             │  │
│  │  │ (internal only)│  │ (internal only)│             │  │
│  │  └────────────────┘  └────────────────┘             │  │
│  │       │                    │                         │  │
│  │       └────────┬───────────┘                         │  │
│  │                ▼                                      │  │
│  │  ┌──────────────────────────────┐                   │  │
│  │  │ Shared Volume: /ludus-data   │                   │  │
│  │  │ - Firestore credentials      │                   │  │
│  │  │ - Telemetry logs             │                   │  │
│  │  │ - Config files               │                   │  │
│  │  └──────────────────────────────┘                   │  │
│  │                                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  Exposed Ports (VPC-internal only):                        │
│  - 3000: ludus-api                                         │
│  - 3001: ludus-metrics                                     │
│  - (NO public-facing ports)                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
    Firestore (Cloud)
    ludus_nodes, ludus_edges, ludus_knowledge_gates
```

---

## 3. Docker Compose Configuration

### 3.1 Create `docker-compose.ludus.yml`

```yaml
version: '3.8'

services:
  ludus-api:
    container_name: ludus-api
    image: ludus-api:v0.1
    build:
      context: /path/to/ludus
      dockerfile: ./Dockerfile.ludus-api
    ports:
      - "10.20.0.2:3000:3000"  # VPC-internal only
    environment:
      NODE_ENV: production
      FIRESTORE_PROJECT_ID: ludus-dev
      FIRESTORE_CREDENTIALS: /ludus-data/firestore-service-account.json
      LOG_LEVEL: info
    volumes:
      - ludus-data:/ludus-data
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    networks:
      - ludus-backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"

  ludus-metrics:
    container_name: ludus-metrics
    image: ludus-metrics:v0.1
    build:
      context: /path/to/ludus
      dockerfile: ./Dockerfile.ludus-metrics
    ports:
      - "10.20.0.2:3001:3001"  # VPC-internal only
    environment:
      NODE_ENV: production
      FIRESTORE_PROJECT_ID: ludus-dev
      LOG_LEVEL: info
    volumes:
      - ludus-data:/ludus-data
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    networks:
      - ludus-backend
    depends_on:
      ludus-api:
        condition: service_healthy

networks:
  ludus-backend:
    driver: bridge

volumes:
  ludus-data:
    driver: local
```

### 3.2 Create Dockerfiles

**`Dockerfile.ludus-api`:**

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy ludus functions source
COPY functions/package*.json ./
RUN npm ci --production

# Copy compiled Cloud Functions
COPY functions/lib ./lib

# Copy Firestore rules + config
COPY firestore.rules ./
COPY firebase.json ./

# Health check script
RUN echo '#!/bin/sh' > /healthcheck.sh && \
    echo 'curl -f http://localhost:3000/health || exit 1' >> /healthcheck.sh && \
    chmod +x /healthcheck.sh

EXPOSE 3000

# Run ludus API server
CMD ["node", "lib/index.js"]
```

**`Dockerfile.ludus-metrics`:**

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY functions/package*.json ./
RUN npm ci --production

# Metrics-specific server
COPY functions/lib/api/ludus-health.js ./
COPY functions/lib/middleware ./middleware

EXPOSE 3001

CMD ["node", "-e", "require('./ludus-health.js').ludusMetrics(3001)"]
```

---

## 4. Deployment Procedure

### 4.1 Prerequisites on VM8

```bash
# SSH to VM8
gcloud compute ssh panopticon-mirror-vm \
  --zone us-central1-a \
  --tunnel-through-iap

# On VM8, verify Docker
docker --version
docker-compose --version
docker images | head -5
```

### 4.2 Clone/Pull Ludus Repo

```bash
# On VM8
cd /opt
git clone https://github.com/leonidy431/ludus.git
cd ludus
git checkout main
git pull

# Verify Dockerfiles exist
ls -la Dockerfile.ludus-*
```

### 4.3 Build Docker Images

```bash
# On VM8
cd /opt/ludus

# Build ludus-api image
docker build -f Dockerfile.ludus-api -t ludus-api:v0.1 .

# Build ludus-metrics image
docker build -f Dockerfile.ludus-metrics -t ludus-metrics:v0.1 .

# Verify images
docker images | grep ludus
# Expected:
# ludus-api        v0.1    ...
# ludus-metrics    v0.1    ...
```

### 4.4 Create Shared Data Volume

```bash
# On VM8
mkdir -p /data/ludus-data
chmod 755 /data/ludus-data

# Copy Firestore credentials (manually uploaded via SCP)
# scp functions/service-account.json VM8:/data/ludus-data/firestore-service-account.json

# Copy Firestore rules
cp firestore.rules /data/ludus-data/

# Verify
ls -la /data/ludus-data/
```

### 4.5 Create Docker Network

```bash
# On VM8
docker network create ludus-backend --driver bridge
docker network inspect ludus-backend
```

### 4.6 Start Containers

```bash
# On VM8, in /opt/ludus
docker-compose -f docker-compose.ludus.yml up -d

# Wait for containers to start
sleep 5

# Check status
docker ps
# Expected:
# CONTAINER ID   STATUS         PORTS
# xxx            Up 4 seconds   ludus-api
# yyy            Up 2 seconds   ludus-metrics
```

### 4.7 Verify Services

```bash
# On VM8, test API internally
curl -s http://10.20.0.2:3000/health | jq '.'

# Expected response:
# {
#   "status": "ok",
#   "timestamp": "2026-09-28T...",
#   "components": {
#     "firestore": { "status": "ok", "nodeCount": 25 }
#   }
# }

# Check logs
docker logs ludus-api
docker logs ludus-metrics
```

---

## 5. Access from Cloud Functions (Firestore → VM8)

### 5.1 Update Cloud Functions to Call VM8 Backend

```typescript
// functions/src/api/ludus-health.ts
import axios from 'axios';

const VM8_API_URL = 'http://10.20.0.2:3000';  // Internal VPC IP

export const ludusHealthProxy = functions.https.onRequest(async (req, res) => {
  try {
    // Forward request to VM8 backend (over Serverless VPC Connector)
    const response = await axios.get(`${VM8_API_URL}/health`, {
      timeout: 5000,
    });
    
    res.json(response.data);
  } catch (error) {
    console.error('[HealthProxy] Error calling VM8:', error.message);
    res.status(503).json({
      error: 'Backend service unavailable',
      service: 'VM8 ludus-api',
    });
  }
});
```

### 5.2 Configure Serverless VPC Connector

```bash
# Create VPC connector (Cloud Functions → VM8 VPC)
gcloud compute networks vpc-access connectors create ludus-connector \
  --network panopticon-vpc \
  --region us-central1 \
  --min-instances 2 \
  --max-instances 10

# Deploy functions with VPC access
firebase deploy --only functions \
  --set VPCCONNECTOR=ludus-connector
```

---

## 6. Telemetry Collection (VR Device → VM8)

### 6.1 Telemetry Endpoint on VM8

```typescript
// functions/api/ludus-telemetry.ts (deployed on VM8)
import * as express from 'express';
import { getFirestore } from 'firebase-admin/firestore';

const app = express();

// Receive telemetry from VR client
app.post('/api/ludus/telemetry', async (req, res) => {
  const { playerId, depth, velocity, power, heading } = req.body;
  
  // Map to D&D attributes
  const wisdom = mapDepthToWisdom(depth);
  const constitution = mapPowerToConstitution(power);
  const dexterity = mapVelocityToDexterity(velocity);
  
  // Update Firestore
  const db = getFirestore();
  await db.collection('ludus_nodes').doc(playerId).update({
    attributes: { wisdom, constitution, dexterity },
    telemetry: { depth, velocity, power, heading },
    lastTelemetryUpdate: new Date(),
  });
  
  res.json({ status: 'received', playerId, attributes: { wisdom, constitution, dexterity } });
});

function mapDepthToWisdom(depth: number): number {
  // 0-300m → 8-18
  return Math.min(18, Math.max(8, Math.floor(8 + (depth / 300) * 10)));
}

// Similar for constitution, dexterity...

export default app;
```

### 6.2 VR Client → VM8 Telemetry Flow

```csharp
// Unity: DemiurgeBridge.cs (modified)
void SyncTelemetryToVM8() {
  // Every 1 second, POST telemetry to VM8 API (via IAP tunnel)
  var payload = new {
    playerId = "player-001",
    depth = avgDepth,
    velocity = avgVelocity,
    power = avgPower,
    heading = currentHeading,
  };
  
  // POST to VM8 backend (accessible via IAP tunnel on :3000)
  // http://10.20.0.2:3000/api/ludus/telemetry
  
  using (var client = new HttpClient()) {
    var json = JsonConvert.SerializeObject(payload);
    var content = new StringContent(json, Encoding.UTF8, "application/json");
    var response = await client.PostAsync("http://10.20.0.2:3000/api/ludus/telemetry", content);
    
    if (response.IsSuccessStatusCode) {
      Debug.Log("[DemiurgeBridge] Telemetry sent to VM8");
    }
  }
}
```

---

## 7. Monitoring & Logging

### 7.1 View Container Logs

```bash
# On VM8
docker logs -f ludus-api
docker logs -f ludus-metrics

# Or via remote SSH
gcloud compute ssh panopticon-mirror-vm \
  --zone us-central1-a \
  --tunnel-through-iap \
  --command "docker logs -f ludus-api"
```

### 7.2 Health Monitoring

```bash
# From local machine (via IAP tunnel)
gcloud compute start-iap-tunnel panopticon-mirror-vm 3000 \
  --local-host-port=localhost:3000 \
  --zone us-central1-a

# In another terminal
curl http://localhost:3000/health | jq '.'
```

---

## 8. Security Considerations

### 8.1 Network Isolation

- ✅ Containers exposed on VPC-internal IP only (`10.20.0.2`)
- ✅ NO public-facing ports
- ✅ Access via IAP tunnel (authenticated by Google)
- ✅ Firewall rules enforce VPC-only access

### 8.2 Secrets Management

```bash
# Firestore credentials stored in volume (not in container)
/data/ludus-data/firestore-service-account.json

# Read-only mount
volumes:
  - /data/ludus-data:/ludus-data:ro
```

### 8.3 Resource Limits

```yaml
# docker-compose.ludus.yml
services:
  ludus-api:
    deploy:
      resources:
        limits:
          cpus: '0.5'        # Max 50% of 1 CPU
          memory: 512M       # Max 512 MB RAM
        reservations:
          cpus: '0.25'
          memory: 256M
```

---

## 9. Troubleshooting

### Issue: Container fails to start

```bash
docker logs ludus-api
# Check for:
# - Missing Firestore credentials
# - Port already in use
# - Insufficient memory
```

### Issue: Firestore connection fails

```bash
# Verify credentials file
cat /data/ludus-data/firestore-service-account.json | jq '.type'
# Should output: "service_account"

# Restart container
docker restart ludus-api
```

### Issue: VPC Connector not working

```bash
# Check connector status
gcloud compute networks vpc-access connectors describe ludus-connector \
  --region us-central1

# Redeploy functions
firebase deploy --only functions
```

---

## 10. Maintenance

### 10.1 Update Containers

```bash
# On VM8
cd /opt/ludus
git pull
docker-compose -f docker-compose.ludus.yml down
docker build -f Dockerfile.ludus-api -t ludus-api:v0.2 .
docker-compose -f docker-compose.ludus.yml up -d
```

### 10.2 Backup Data

```bash
# On VM8
cp -r /data/ludus-data /data/ludus-data-backup-$(date +%Y%m%d)

# Or remotely
gcloud compute scp panopticon-mirror-vm:/data/ludus-data ./ludus-data-backup \
  --zone us-central1-a \
  --tunnel-through-iap
```

---

## 11. Production Checklist

- [ ] Docker images built and tested locally
- [ ] docker-compose.ludus.yml configured (ports, volumes, env vars)
- [ ] Firestore credentials uploaded to VM8
- [ ] Containers pass health checks
- [ ] VPC Connector created (Cloud Functions → VM8)
- [ ] Telemetry endpoint tested (VR → VM8 → Firestore)
- [ ] Monitoring alerts configured
- [ ] Backup procedure documented

---

**Status:** Ready for deployment on VM8  
**Owner:** Claude Haiku 4.5  
**Session:** 2026-09-28  
**Next:** Execute Phase 2, then deploy VM8 backend (Phase 3)

