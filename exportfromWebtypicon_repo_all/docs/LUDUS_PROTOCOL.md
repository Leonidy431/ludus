# Ludus Protocol — Game Development Guide

## Overview
**Ludus Protocol** is an AI-driven RPG gamification system for the webtypicon2 project. It transforms spiritual education and liturgical learning into an interactive game experience with character progression, resource management, and knowledge authentication.

## Core System Architecture

### 1. **Four Development Phases**
- **Phase 1 (Ingress)** ✅ COMPLETE
  - Terminal/entry system established
  - Foundation protocols documented
  
- **Phase 2 (Initiation)** 🔄 IN PROGRESS
  - Gates Protocol for node registration
  - Knowledge proof authentication system
  - CLI command handling per Brotherhood protocols
  
- **Phase 3 (Capital)** ⏳ PLANNED
  - Resource generation through learning
  - Phenomenon Explorer pipeline deployment
  - Topological engine for entity relationships
  
- **Phase 4 (Market)** ⏳ PLANNED
  - Launch ludus_market collection (Firestore)
  - Full market/economy integration

### 2. **Core Subsystems**

#### Demiurge Engine
- Graph-based world simulation
- Nodes = entities (characters, objects, concepts)
- Edges = interactions and relationships
- Aristotelian causality framework (Matter → Form → Action → Goal)

#### Cognitive Proxy System
- AI-driven mentorship module
- Character progression tracking
- Voice synthesis integration (TBD)
- Multiple persona support (Analyst, Critic, Designer, etc.)

#### Resource Management
- 12 agent disciplines with resource pools
- Kairotic Tasks (routine → game challenge conversion)
- Knowledge-testing gates (Proof of Knowledge auth)
- Capital accumulation mechanics

#### Knowledge Authentication
- Proof-of-Knowledge gates for progression
- Spiritual/liturgical education validation
- Multi-tier access control

---

## Immediate Tasks (Phase 2)

### Backend Implementation (Priority: HIGH)
1. **CLI Command Handler**
   - Parse Brotherhood protocol directives
   - Route to appropriate subsystems
   - Return structured responses

2. **Node Registration System**
   - Implement Gates Protocol for player registration
   - Knowledge proof validation
   - Profile initialization

3. **Topological Engine** 
   - Build entity relationship mapper
   - Graph construction and traversal
   - Path finding for quest chains

4. **Phenomenon Explorer Pipeline**
   - Text input processing
   - Entity extraction from liturgical corpus
   - Concept relationship mapping

### Frontend / UI (Priority: MEDIUM)
1. **Game Tab/Section**
   - New top-level navigation item
   - Scene Controller integration (Firebase state machine)
   - Multi-language i18n support

2. **Player Dashboard**
   - Character stats display
   - Resource inventory
   - Quest/task tracker
   - Progress visualization

3. **Knowledge Gate UI**
   - Question/answer interface
   - Proof-of-Knowledge validation feedback
   - Progression unlocks

### Data Integration (Priority: MEDIUM)
1. **Firestore Collections**
   - ludus_players (character profiles)
   - ludus_resources (inventory & capital)
   - ludus_market (economy system - Phase 4)
   - ludus_topology (entity relationship graph)
   - ludus_tasks (Kairotic Tasks list)

2. **Corpus Mapping**
   - Link liturgical texts to learning objectives
   - Map Ponomar/Greek corpus to game entities
   - Establish knowledge proof questions

3. **Localization**
   - Support Phase 2 languages: Spanish, Swahili, others
   - Use i18n keys (not localized strings)
   - Reactive locale switching

---

## Technical Specifications

### Development Standards
- **Backend**: TypeScript, Cloud Functions (Firebase)
- **Frontend**: TypeScript, reactive UI (Scene Controller)
- **Database**: Firestore (primary), cache layer for read-heavy operations
- **Authentication**: Proof-of-Knowledge gates (custom) + existing Firebase auth
- **State Management**: Scene Controller (declarative state machine)

### Architectural Constraints
1. **Contract-first**: JSON schemas for all data exchanges
2. **Pure functions**: Deterministic selection algorithms (same input → same output)
3. **Sandbox isolation**: All game logic in separate Cloud Function (not bolted onto `/api`)
4. **Idempotency**: All write operations must be idempotent
5. **Graceful degradation**: Game remains functional if Firestore is temporarily unavailable

### Security Requirements
- Proof-of-Knowledge validates via hashable, verifiable tokens
- All game write operations require authentication
- Rate limiting on CLI command handler
- Admin audit trail for resource changes

---

## Success Criteria (Phase 2 Completion)

- [ ] CLI command handler processes Brotherhood protocols
- [ ] Node registration works end-to-end with knowledge proof
- [ ] Topological engine builds entity relationship graphs
- [ ] Phenomenon Explorer extracts concepts from text
- [ ] Firestore collections initialized with seed data
- [ ] Game tab visible in UI (read-only player dashboard)
- [ ] Spanish & Swahili UI elements translated
- [ ] Zero-regression on existing API & corpus features
- [ ] Build + test coverage pass (see CLAUDE.md thresholds)
- [ ] Verified on Firebase Emulator + staging project

---

## File Reference
- `game_Orden` — Main specification (21K+ lines)
- `Game_orden_2` — Phase 1-2 detailed implementation
- `game_orden_3` → `game_orden_7` — Phase 2-4 architectures, algorithms, psychology
- `adds 02 07` — Current sprint task list & recommendations

---

## Related Documentation
- See `/CLAUDE.md` for deployment procedure, branch model, and security rules
- See `docs/SOURCE_REGISTRY.md` for corpus integration guidelines
- See `functions/src/middleware/security.ts` for rate-limiting & auth patterns

---

## Questions / Escalations
Contact: lab767@gmail.com
