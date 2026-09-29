# Phase 3: Quick Start Guide
## Oct 1–5, 2026 | Deployment & Testing

**Full checklist:** See `docs/reports/PHASE_3_DEPLOYMENT_CHECKLIST.md` (1000+ lines)

---

## 🚀 TL;DR — Critical Path (Oct 1–5)

### Monday Oct 1 — Deployment Day

```bash
# 1. Validate code (5 min)
cd /home/user/ludus/functions
npm run build
npm run lint
npm audit

# 2. Deploy functions (10 min)
firebase deploy --only functions

# 3. Seed data (3 min)
cd /home/user/ludus
export FIREBASE_PROJECT_ID=ludus-firestore
npx ts-node functions/src/scripts/seedDialogueData.ts

# 4. Verify APIs (20 min)
curl -s "https://us-central1-ludus.cloudfunctions.net/getDialogueTree?npcId=elder_sergius" | jq '.npcId'
# Expected: "elder_sergius"
```

### Tuesday Oct 2–3 — Desktop & Mobile Testing

```bash
# Desktop (Chrome): Open DevTools, test dialogue flow
# Expected: All interactions work, 60 FPS, < 500ms API responses

# Mobile (iPhone + Galaxy): Check responsive layout
# Expected: Text readable, buttons tap-able, no horizontal scroll
```

### Wed Oct 4–5 — Quest 3 VR Testing

```bash
# Real Meta Quest 3:
adb devices  # Verify connection
# Test in VR:
# - Load game (should show 72 FPS)
# - Click NPC → dialogue appears in VR space
# - Audio plays from NPC position (spatial)
# - Choices work via controller
# - 10-min play session stable
```

### Friday Oct 5 — Go/No-Go Decision

✅ **GO to Phase 4** if:
- All 5 APIs deployed and working
- Desktop/mobile/Quest 3 tests pass
- No P0 bugs
- Performance targets met (< 500ms, 72 FPS)

❌ **NO-GO** if:
- Functions crash or timeout
- Firestore quota exceeded
- VR performance drops below 60 FPS
- Audio spatial positioning broken

---

## 📋 Deployment Checklist (One-Liner Version)

| Step | Command | Expected Result | Status |
|------|---------|-----------------|--------|
| Build | `npm run build` | Exit code 0, no errors | ⏳ |
| Lint | `npm run lint` | 0 warnings/errors | ⏳ |
| Deploy | `firebase deploy --only functions` | 5 functions deployed | ⏳ |
| Seed | `npx ts-node seedDialogueData.ts` | 2 trees + 5 memory docs | ⏳ |
| Test Tree | `curl getDialogueTree?npcId=elder_sergius` | 200 OK, npcId present | ⏳ |
| Test Memory | `curl getNpcMemory?npcId=elder_sergius&playerId=p1` | 200 OK, firstMeeting: true | ⏳ |
| Test Persist | `curl -X POST persistDialogueState` (with JSON) | 200 OK, success: true | ⏳ |
| Test Stats | `curl getDialogueStats?playerId=p1` | 200 OK (or 404 if no player) | ⏳ |
| Desktop Test | Open webtypicon2, click NPC | Dialogue loads, choices work | ⏳ |
| Mobile Test | Test on iPhone + Galaxy | Responsive, readable | ⏳ |
| Quest Test | Connect Quest 3, play 10 min | 72 FPS, no crashes | ⏳ |
| **DECISION** | Review results | GO or NO-GO | ⏳ |

---

## 🛠️ Troubleshooting Quick Links

**Functions won't deploy?**
→ Check: `firebase login`, `firebase projects:list`, `npm install` in functions/

**Firestore queries returning empty?**
→ Check: Did `seedDialogueData.ts` complete? Check Firestore Console for collections.

**API returns 404 for existing NPC?**
→ Check: Is `npcId` exactly "elder_sergius" or "theodora"? Case-sensitive.

**Mobile doesn't show dialogue?**
→ Check: Is ludus-dialogue.css loaded? Network tab → CSS file present? DevTools console for JS errors.

**Quest 3 audio not spatial?**
→ Check: In `ludus-audio-manager.js`, does `setupVRSpatialAudio()` have Wwise integration? Oct 2–Nov 15 phase adds this.

**Performance drops on Quest?**
→ Check: Frame rate via Oculus Metrics Tool. If < 60 FPS, reduce draw calls or enable LOD.

---

## 📞 Decision Makers & Escalation

| Issue | Owner | Action |
|-------|-------|--------|
| Deploy failure | Leonidy431 | Check Firebase console, retry |
| Firestore errors | Leonidy431 | Check quota, wait 24h if exceeded |
| Performance below spec | Leonidy431 | Profile with DevTools, optimize or defer to Phase 4 |
| Go/No-Go call | Leonidy431 | Review all test results by Oct 5 17:00 UTC |

---

## 📊 Success Metrics (All Must Pass)

- ✅ All 5 Cloud Functions deployed to Firebase
- ✅ Firestore seeding complete (2 dialogue trees, 5 NPC memory docs)
- ✅ API responses < 500ms (warm)
- ✅ Desktop dialogue flow works end-to-end
- ✅ Mobile responsive without horizontal scroll
- ✅ Quest 3 renders at 72+ FPS
- ✅ Quest 3 spatial audio functional (voice from correct direction)
- ✅ 10-minute play session on Quest 3 without crashes
- ✅ No critical (P0) bugs blocking production
- ✅ Firestore under quota

---

## 📅 Daily Standup Template (Oct 1–5)

```
🚀 PHASE 3 STANDUP — Oct __, 2026

COMPLETED TODAY:
- [ ] Pre-deployment validation
- [ ] Firebase deployment
- [ ] Firestore seeding
- [ ] API verification
- [ ] Desktop testing
- [ ] Mobile testing
- [ ] Quest 3 testing

BLOCKERS:
- [ ] None
- [ ] [Issue]: [Description]

RISKS:
- [ ] [Risk]: [Mitigation]

DECISION MADE:
- [ ] Proceeding Oct __ (date)
- [ ] Retry Oct __ due to [reason]
```

---

## 🎯 Oct 1–5 Timeline (Actual)

| Date | AM | PM | Status |
|------|----|----|--------|
| Oct 1 | Validate + Deploy | API tests | 🟡 |
| Oct 2 | Desktop tests | Mobile setup | 🟡 |
| Oct 3 | Mobile tests | Quest emulator | 🟡 |
| Oct 4 | Quest emulator | Real Quest 3 | 🟡 |
| Oct 5 | Quest 3 (extended) | Go/No-Go decision | 🟡 |

---

**Owner:** Claude Haiku 4.5  
**Date:** 2026-09-29  
**Status:** Ready for Execution — Oct 1 Deployment Day
