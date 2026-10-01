---
id: ludus-backend-container-standalone
type: deployment-guide
tags: [ludus, docker, backend, vm8, panopticon, container, production]
version: 1.0
status: ready-to-deploy
date: 2026-09-29
---

# Ludus Backend Container — Standalone Deployment on VM8

**Purpose:** Deploy Ludus backend API as isolated Docker container on panopticon-mirror-vm  
**Infrastructure:** Google Cloud Platform, e2-small (2 vCPU, 2 GB RAM)  
**Access:** IAP tunnel (secure, VPC-internal only)  
**Container:** ludus-backend-api, isolated network, port 3000  
**Separate from:** Translation viewer, other VM8 services

---

## 1. Pre-Deployment Checklist

### 1.1 VM8 Infrastructure Verification

```bash
# SSH to VM8 via IAP tunnel
gcloud compute ssh panopticon-mirror-vm \
  --zone us-central1-a \
  --tunnel-through-iap

# On VM8, verify prerequisites
docker --version           # Docker Engine installed
docker-compose --version  # Docker Compose installed
df -h /data               # Storage available (20 GB pd-balanced)
free -h                   # Memory available (2 GB total)
```

**Expected output:**
```
Docker version 20.10+
docker-compose version 1.29+
/data: 20G available
Mem: 2.0G total
```

### 1.2 VM8 Directory Structure

```bash
# On VM8, create isolated directories
sudo mkdir -p /data/ludus-secrets
sudo mkdir -p /data/ludus-data
sudo chmod 755 /data/ludus-secrets
sudo chmod 755 /data/ludus-data

# Verify
ls -la /data/ludus-*
```

---

## 2. Container Configuration

### 2.1 Files Provided

| File | Purpose |
|------|---------|
| `docker-compose.ludus-backend.yml` | Standalone container orchestration |
| `Dockerfile.ludus-backend` | Ludus backend image definition |
| `functions/lib/` | Compiled Node.js backend code |
| `firestore.rules` | Firestore security rules |

### 2.2 Docker Compose Structure

```yaml
services:
  ludus-backend-api:
    image: ludus-backend:v0.1
    ports:
      - "10.20.0.2:3000:3000"   # VPC-internal IP only
    environment:
      FIRESTORE_PROJECT_ID: ludus-dev
      FIRESTORE_CREDENTIALS: /ludus-secrets/firestore-service-account.json
    volumes:
      - ludus-secrets:/ludus-secrets:ro
      - ludus-data:/ludus-data
    networks:
      - ludus-isolated
```

**Key points:**
- Port 3000 bound to VPC-internal IP `10.20.0.2` (no public exposure)
- Credentials mounted as read-only
- Isolated network (`ludus-isolated`) for backend only
- Resource limits: 0.75 vCPU, 768 MB RAM (within e2-small constraints)

---

## 3. Deployment Procedure

### Step 1: Clone Ludus Repository on VM8

```bash
# On VM8
cd /opt
git clone https://github.com/leonidy431/ludus.git
cd ludus
git checkout main
git pull origin main

# Verify files exist
ls -la docker-compose.ludus-backend.yml
ls -la Dockerfile.ludus-backend
ls -la functions/lib/
```

### Step 2: Build Docker Image

```bash
# On VM8, in /opt/ludus
docker build -f Dockerfile.ludus-backend -t ludus-backend:v0.1 .

# Verify image
docker images | grep ludus-backend
# Expected: ludus-backend    v0.1    <hash>    <size>
```

**Build time:** ~2-3 minutes (depends on network speed)

### Step 3: Upload Firestore Credentials

```bash
# On LOCAL machine, copy credentials to VM8
scp -i ~/.ssh/gcloud \
  functions/service-account.json \
  user@panopticon-mirror-vm:/data/ludus-secrets/firestore-service-account.json \
  --tunnel-through-iap

# Verify on VM8
ls -la /data/ludus-secrets/firestore-service-account.json
cat /data/ludus-secrets/firestore-service-account.json | jq '.type'
# Should output: "service_account"
```

**Security:** Credentials never stored in container image, only mounted at runtime.

### Step 4: Create Isolated Network

```bash
# On VM8
docker network create ludus-isolated --driver bridge

# Verify
docker network inspect ludus-isolated
# Should show: Driver: bridge, Subnet: 10.21.0.0/16
```

### Step 5: Start Ludus Backend Container

```bash
# On VM8, in /opt/ludus
docker-compose -f docker-compose.ludus-backend.yml up -d

# Wait for container to start
sleep 5

# Check status
docker ps | grep ludus-backend-api
# Expected: ludus-backend-api running

# View logs
docker logs ludus-backend-api
# Expected: "[Ludus Backend] Starting API server on port 3000"
```

### Step 6: Verify Container Health

```bash
# On VM8
docker inspect ludus-backend-api | grep -A 5 "State"
# Expected: "Running": true, "Health": "healthy"

# Test health endpoint (from within VM8)
curl -s http://10.20.0.2:3000/health | jq '.'

# Expected response:
# {
#   "status": "ok",
#   "timestamp": "2026-09-29T...",
#   "components": {
#     "firestore": {
#       "status": "ok",
#       "nodeCount": 25,
#       "edgeCount": 50
#     }
#   }
# }
```

---

## 4. Telemetry Integration

### 4.1 VR Device → Container → Firestore Flow

```
Quest 3 Device (DemiurgeBridge)
    ↓ POST /api/ludus/telemetry
    ↓ (30 Hz polling)
VM8 ludus-backend-api:3000
    ↓ Firestore write
    ↓ ludus_nodes/{playerId}/telemetry
Firestore (Cloud)
    ↓ Real-time subscription
webtypicon2 (ROV Lake tab)
```

### 4.2 Telemetry Endpoint

**POST `/api/ludus/telemetry`**

Request body:
```json
{
  "playerId": "player-abc123",
  "depth": 42.5,
  "velocity": 1.2,
  "power": 0.75,
  "heading": 270,
  "timestamp": "2026-09-29T12:30:45.123Z"
}
```

Response:
```json
{
  "status": "received",
  "playerId": "player-abc123",
  "attributes": {
    "wisdom": 12,
    "constitution": 15,
    "dexterity": 14
  }
}
```

---

## 5. Monitoring & Logging

### 5.1 View Container Logs

```bash
# Real-time logs
docker logs -f ludus-backend-api

# Last 50 lines
docker logs ludus-backend-api | tail -50

# With timestamps
docker logs -t ludus-backend-api | tail -20
```

### 5.2 Container Resource Usage

```bash
# Monitor CPU, memory, network
docker stats ludus-backend-api

# Expected output:
# CONTAINER          CPU %    MEM USAGE / LIMIT
# ludus-backend-api  2-5%     120-200 MB / 768 MB
```

### 5.3 Remote Monitoring (from local machine)

```bash
# Access logs via IAP tunnel
gcloud compute ssh panopticon-mirror-vm \
  --zone us-central1-a \
  --tunnel-through-iap \
  --command "docker logs -f ludus-backend-api"
```

---

## 6. Network Access

### 6.1 VM8 Firewall Rules

**Verify:** Only VPC-internal traffic on port 3000

```bash
# On VM8, check open ports
netstat -tulnp | grep 3000
# Expected: tcp 0 0 10.20.0.2:3000 0.0.0.0:* LISTEN

# NOT listening on 0.0.0.0 or public IP (secure ✅)
```

### 6.2 Access from Cloud Functions

Cloud Functions can reach ludus-backend-api via Serverless VPC Connector:

```typescript
const VM8_BACKEND = 'http://10.20.0.2:3000';

const response = await axios.get(`${VM8_BACKEND}/health`, {
  timeout: 5000,
  headers: { 'User-Agent': 'ludus-cloud-functions/v0.1' },
});
```

### 6.3 Access from webtypicon2

webtypicon2 accesses backend via IAP tunnel (user's browser):

```bash
# User runs locally:
gcloud compute start-iap-tunnel panopticon-mirror-vm 3000 \
  --local-host-port=localhost:3000 \
  --zone us-central1-a

# Browser requests: http://localhost:3000/health
```

---

## 7. Container Lifecycle

### 7.1 Stop Container

```bash
docker-compose -f docker-compose.ludus-backend.yml down

# Verify
docker ps | grep ludus-backend-api
# (should be empty)
```

### 7.2 Restart Container

```bash
docker-compose -f docker-compose.ludus-backend.yml restart ludus-backend-api

# Wait for health check
sleep 5
docker ps | grep ludus-backend-api
```

### 7.3 Update & Redeploy

```bash
# On VM8
cd /opt/ludus
git pull origin main

# Rebuild image
docker build -f Dockerfile.ludus-backend -t ludus-backend:v0.2 .

# Update docker-compose to use new version
# Edit: docker-compose.ludus-backend.yml
#   image: ludus-backend:v0.2

# Restart with new image
docker-compose -f docker-compose.ludus-backend.yml down
docker-compose -f docker-compose.ludus-backend.yml up -d

# Verify
docker logs ludus-backend-api
```

---

## 8. Resource Management

### 8.1 Container Resource Limits

Current limits in docker-compose:
- CPU: 0.75 vCPU (hard limit), 0.5 vCPU (reservation)
- Memory: 768 MB (hard limit), 512 MB (reservation)

**Why these limits:**
- VM8 machine: e2-small = 2 vCPU, 2 GB RAM
- Leave headroom for host OS, other services
- Ludus backend is I/O-bound (Firestore), not CPU-bound

### 8.2 Disk Usage

```bash
# Check volume sizes
du -sh /data/ludus-*

# Clean up old logs if needed
docker exec ludus-backend-api rm -f /var/log/ludus-*.old.log
```

### 8.3 Memory Monitoring

If container approaches memory limit:

```bash
# Check memory usage
docker stats ludus-backend-api

# If > 600 MB, increase in docker-compose.ludus-backend.yml:
# deploy.resources.limits.memory: 1G
# deploy.resources.reservations.memory: 768M

# Restart container
docker-compose -f docker-compose.ludus-backend.yml restart ludus-backend-api
```

---

## 9. Troubleshooting

### Issue: Container fails to start

```bash
docker logs ludus-backend-api
# Check for:
# - ENOENT firestore-service-account.json
# - EADDRINUSE 3000 (port conflict)
# - OOMKilled (out of memory)
```

**Fix:**
```bash
# Verify credentials
cat /data/ludus-secrets/firestore-service-account.json | head -5

# Check port availability
netstat -tulnp | grep 3000

# Increase memory limit if OOMKilled
# Edit docker-compose.ludus-backend.yml and redeploy
```

### Issue: Health check fails

```bash
# Manual health check
docker exec ludus-backend-api curl -f http://localhost:3000/health

# Check Firestore connectivity
docker logs ludus-backend-api | grep -i firestore
```

**Fix:**
```bash
# Verify Firestore credentials are valid
gcloud firestore collections list --project ludus-dev

# Restart container
docker-compose -f docker-compose.ludus-backend.yml restart ludus-backend-api
```

### Issue: Telemetry not being written to Firestore

```bash
# Check incoming requests in logs
docker logs ludus-backend-api | grep "telemetry"

# Verify Firestore rules allow write
cat firestore.rules | grep "ludus_nodes"

# Test with curl
curl -X POST http://10.20.0.2:3000/api/ludus/telemetry \
  -H "Content-Type: application/json" \
  -d '{"playerId":"player-test","depth":10}'
```

---

## 10. Security Best Practices

### 10.1 Network Isolation

✅ Container listens on VPC-internal IP only (10.20.0.2)  
✅ No public-facing ports  
✅ Isolated Docker network (ludus-isolated)  
✅ Access via IAP tunnel (authenticated by Google)

### 10.2 Credentials Management

✅ Service account mounted read-only  
✅ Not embedded in image  
✅ Permissions: only read ludus-dev Firestore  

### 10.3 Container Hardening

✅ Non-root user (UID 1000)  
✅ Read-only filesystem for Firestore rules  
✅ dumb-init for proper signal handling  
✅ Health checks enabled

---

## 11. Production Checklist

- [ ] Docker image built and tested locally
- [ ] Dockerfile.ludus-backend compiles without errors
- [ ] VM8 has 20 GB available in /data
- [ ] Firestore service account uploaded to /data/ludus-secrets
- [ ] docker-compose.ludus-backend.yml configured
- [ ] Container starts and health checks pass
- [ ] Telemetry endpoint responds to test requests
- [ ] Firestore rules published to production
- [ ] Monitoring alerts configured
- [ ] Backup procedure documented (see VM8_BACKEND_CONTAINER_DEPLOYMENT.md)

---

## 12. Next Steps

1. **Deploy container** on VM8 using this guide
2. **Test telemetry flow** with Phase 3 emulator testing (Sep 30)
3. **Monitor health** during Phase 3 (Sep 29–Oct 1)
4. **Go/no-go decision** on Oct 2 for production

---

**Status:** Ready for deployment  
**Owner:** Claude Haiku 4.5  
**Date:** 2026-09-29  
**Environment:** VM8 (panopticon-mirror-vm, Google Cloud e2-small)  
**Next Review:** After Oct 1 device testing
