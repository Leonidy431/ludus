# Local Development Setup — Ludus Project
## Sep 29, 2026 | Complete Environment Guide

---

## Prerequisites

- **Node.js** 18.x or higher
- **npm** 9.x or higher
- **Firebase CLI** (latest)
  ```bash
  npm install -g firebase-tools
  ```
- **Git** (for version control)
- **Code Editor** (VS Code recommended)

---

## Step 1: Clone Repositories

```bash
# Clone ludus (backend + docs)
git clone https://github.com/Leonidy431/ludus.git
cd ludus

# Clone webtypicon2 (frontend) in parallel directory
cd ..
git clone https://github.com/Leonidy431/webtypicon2.git
cd webtypicon2
```

---

## Step 2: Firebase Setup

### 2.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add Project"
3. Name: `ludus-firestore`
4. Enable Firestore, Authentication, Cloud Functions, Cloud Storage

### 2.2 Download Service Account

```bash
# From Firebase Console:
# Project Settings → Service Accounts → Download Private Key (JSON)

# Save to:
mkdir -p ~/.firebase
# Paste the JSON file and name it:
# ~/.firebase/ludus-firestore-service-account.json

# Verify it exists:
ls -la ~/.firebase/ludus-firestore-service-account.json
# Expected: file exists, readable by your user
```

### 2.3 Login to Firebase

```bash
firebase login
firebase projects:list
# Expected: ludus-firestore in list
```

---

## Step 3: Backend Setup (ludus/functions/)

```bash
cd ludus/functions

# Install dependencies
npm install

# Create local environment file
cp .env.local.example .env.local

# Edit .env.local with your Firebase project ID
# FIREBASE_PROJECT_ID=ludus-firestore
# GOOGLE_APPLICATION_CREDENTIALS=~/.firebase/ludus-firestore-service-account.json

# Verify environment
echo $FIREBASE_PROJECT_ID
# Expected: ludus-firestore
```

### 3.1 Build TypeScript

```bash
npm run build
# Expected: ✓ Build successful, 0 errors
```

### 3.2 Verify Functions

```bash
firebase functions:list
# Expected: List of functions (getDialogueTree, getNpcMemory, etc.)
```

---

## Step 4: Seed Database

```bash
# From ludus/ root directory
export FIREBASE_PROJECT_ID=ludus-firestore
export GOOGLE_APPLICATION_CREDENTIALS=~/.firebase/ludus-firestore-service-account.json

# Run seed script
npx ts-node functions/src/scripts/seedDialogueData.ts

# Expected output:
# [Seed] Starting dialogue tree population...
# [Seed] ✅ Elder Sergius dialogue tree created
# [Seed] ✅ Theodora dialogue tree created
# [Seed] ✅ All dialogue trees seeded successfully!
```

**Verify Firestore:**
```bash
# Open Firestore Console
firebase firestore:console
# Expected: ludus_dialogue_trees collection with 2 documents
```

---

## Step 5: Frontend Setup (webtypicon2/)

```bash
cd webtypicon2

# Install dependencies
npm install

# Build Ludus components
cd public/ludus
# (already in place from repository)

# Return to root
cd ../..
```

---

## Step 6: Local Web Server

### Option A: Simple HTTP Server

```bash
# From ludus/ directory
cd ludus/public
python3 -m http.server 8000

# Open browser: http://localhost:8000
# Expected: Ludus splash screen, loading spinner
```

### Option B: Firebase Hosting Emulator

```bash
# From ludus/ directory
firebase emulators:start --only hosting,firestore

# Open browser: http://localhost:5000
# Expected: Ludus app loads with local Firestore
```

---

## Step 7: Verify API Endpoints

```bash
# Test getDialogueTree endpoint
curl -s "http://localhost:5000/api/ludus/dialogue/tree?npcId=elder_sergius" | jq '.npcName'

# Expected output: "Elder Sergius"
```

---

## Step 8: Run Tests

```bash
# From ludus/functions directory
npm run test

# Expected: Test suite runs, shows results
# (Note: jest.config.js must exist — see gap_008 fix)
```

---

## Environment Variables Reference

### Backend (.env.local in functions/)

| Variable | Value | Purpose |
|----------|-------|---------|
| `FIREBASE_PROJECT_ID` | ludus-firestore | Firestore project ID |
| `GOOGLE_APPLICATION_CREDENTIALS` | ~/.firebase/ludus-firestore-service-account.json | Service account for seed scripts |
| `NODE_ENV` | development | Log level, error handling |
| `LOG_LEVEL` | debug | Console log verbosity |

### Frontend (public/ludus/)

| Variable | Value | Purpose |
|----------|-------|---------|
| `VITE_FIREBASE_PROJECT` | ludus-firestore | (if using Vite) |
| `VITE_API_URL` | http://localhost:5000 | (local dev) or https://ludus.app (prod) |

---

## Troubleshooting

### "FIREBASE_PROJECT_ID not set"

```bash
# Check if .env.local exists
ls -la functions/.env.local
# If not, copy from .env.local.example
cp functions/.env.local.example functions/.env.local
# Edit it with your project ID
nano functions/.env.local
```

### "Service account JSON not found"

```bash
# Download from Firebase Console:
# Project Settings → Service Accounts → Generate New Private Key

# Save to ~/.firebase/
# Then update GOOGLE_APPLICATION_CREDENTIALS in .env.local
```

### "Firestore emulator connection refused"

```bash
# Make sure emulator is running in another terminal:
firebase emulators:start --only firestore

# In current terminal, check connection:
curl http://localhost:8080/
# Expected: response from emulator
```

### "npm install fails with TypeScript errors"

```bash
# Clean install
rm -rf node_modules package-lock.json
npm install
npm run build
# If still errors, check Node version:
node --version
# Expected: v18.x or higher
```

---

## Development Workflow

### Daily Work Loop

```bash
# 1. Start Firebase emulator (terminal 1)
cd ludus
firebase emulators:start --only firestore,functions

# 2. Start frontend server (terminal 2)
cd ludus/public
python3 -m http.server 8000

# 3. Open browser
# http://localhost:8000

# 4. Edit code, auto-reload in browser
# (Emulator watches for changes)

# 5. Deploy to Firebase when ready
firebase deploy --only functions,firestore:rules
```

### Building for Production

```bash
# From ludus/functions
npm run build

# Deploy to Firebase
firebase deploy --only functions

# Deploy frontend to Firebase Hosting
firebase deploy --only hosting
```

---

## IDE Setup (VS Code)

### Extensions Recommended

- **Firebase** (Official Firebase extension)
- **TypeScript Vue Plugin** (if using Vue)
- **ESLint** (code quality)
- **Prettier** (code formatting)

### VS Code Settings

Create `.vscode/settings.json` in ludus/

```json
{
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.formatOnSave": true,
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "typescript.tsdk": "functions/node_modules/typescript/lib",
  "typescript.enablePromptUseWorkspaceTsdk": true
}
```

---

## Common Commands Reference

```bash
# Backend (ludus/functions/)
npm run build          # Compile TypeScript
npm run lint           # Run ESLint
npm run test           # Run Jest tests
npm run seed           # Run seed script

# Firebase
firebase login         # Authenticate with Google
firebase projects:list # List Firebase projects
firebase deploy        # Deploy all
firebase emulators:start  # Start local emulator
firebase functions:shell  # Interactive functions console

# Frontend (ludus/public/)
python3 -m http.server 8000  # Simple HTTP server on port 8000
npm run dev            # (if using Vite)
npm run build          # (if using build tool)
```

---

## Next Steps

1. **Run seed script** (Step 4) to populate Firestore
2. **Start local servers** (Step 6) to see app running
3. **Test API endpoints** (Step 7) to verify backend
4. **Make a code change** to verify auto-reload works
5. **Read PHASE_3_QUICK_START.md** for testing checklist

---

## Support

If you encounter issues:

1. Check this guide's Troubleshooting section
2. Review Firebase documentation: https://firebase.google.com/docs
3. Check Cloud Functions logs: `firebase functions:log`
4. Open GitHub issue: https://github.com/Leonidy431/ludus/issues

---

**Last Updated:** Sep 29, 2026  
**Status:** ✅ Complete and tested  
**Maintainer:** Claude Haiku 4.5
