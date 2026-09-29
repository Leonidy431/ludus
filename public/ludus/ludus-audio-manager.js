/**
 * Ludus Audio Manager (Meta Quest 3 browser build).
 *
 * Four mixing layers (music, dialogue, sfx, ambience) feed a master bus
 * and a brick-wall limiter.  Every sound is tied to a meaning from the
 * constitution ("sound is a language"), NPC voices are placed at the
 * NPC's position with HRTF panning, and a missing or undecodable asset
 * never throws into the game.  No recordings exist yet, so every key
 * is rendered by the deterministic procedural synth of the same name
 * (ludus-sacred-synth.js, window.LudusSacredSynth), cached after the
 * first render.  A file is fetched only when its path is listed in
 * SHIPPED_AUDIO, i.e. when it really is in the repository; asking for
 * a file that does not exist only produced a 404 in the console on
 * every guest session (TABOO 0.35 rule 8).  Only when the synth is
 * unavailable does a call resolve to null.  Sound rules:
 * docs/SOUND_THEOLOGY_RULES.md.
 *
 * Public global: window.LudusAudioManager (name is part of the shared
 * contract with ludus-npc-dialogue-ui.js and must not change).
 */

'use strict';

window.LudusAudioManager = (function () {
  const AUDIO_PATH = '/ludus/audio';
  const PREFS_KEY = 'ludus.audio.prefs.v1';

  // Time constant for setTargetAtTime.  About 30 ms is short enough to
  // feel instant but long enough to avoid the click of a hard jump.
  const SMOOTH = 0.03;

  // Ducking factors are multiplied on top of the user's layer volume,
  // so ducking never overwrites what the player chose in the settings.
  // The spec (SOUND_DESIGN_SYSTEM.md, layer 2) asks for music at -40 %
  // while someone is speaking.
  const DUCK_DIALOGUE = { music: 0.6, sfx: 0.5, ambience: 0.35 };
  const DUCK_MUSIC = { ambience: 0.5 };

  const DEFAULT_PREFS = {
    master: 1.0,
    muted: false,
    layers: { music: 0.7, dialogue: 0.85, sfx: 0.6, ambience: 0.5 },
  };

  // Audio graph state.  The context is created lazily and only after a
  // user gesture, because Quest Browser and Chrome refuse to start an
  // AudioContext that was created without one.
  let audioContext = null;
  let masterGain = null;
  let limiter = null;
  let initialized = false;
  let gestureSeen = false;
  let unlockArmed = false;

  const layers = {
    music: { gain: null, duck: null },
    dialogue: { gain: null, duck: null },
    sfx: { gain: null, duck: null },
    ambience: { gain: null, duck: null },
  };

  let prefs = loadPrefs();

  // Every playing voice is tracked so it can be stopped and fully
  // disconnected; an undisconnected node keeps its whole chain alive.
  let activeSources = [];
  let liveNodes = 0;
  let dialogueVoices = 0;

  // One decode per path.  Failed loads are cached as null so a missing
  // file is requested once, not on every click.
  const bufferCache = new Map();
  const warnedPaths = new Set();

  // One procedural rendering per catalogue key (see sacredBuffer).
  const synthCache = new Map();
  let synthMissingWarned = false;

  // NPC world positions, so a voice line is heard from where the NPC
  // stands without every caller having to pass coordinates.
  const npcPositions = new Map();

  // Recorded files that really ship under AUDIO_PATH, as paths
  // relative to it (for example 'npc-themes/theodora.mp3').  It is
  // empty because no recording exists yet.  Add a path here in the
  // same commit that adds the file; until then the synth renders the
  // key and no request is made.
  const SHIPPED_AUDIO = Object.freeze(new Set([]));

  function isShipped(filePath) {
    return Boolean(filePath) && SHIPPED_AUDIO.has(filePath);
  }

  // Music track catalog (from SOUND_DESIGN_SYSTEM.md).  plannedFile is
  // where a future recording will live; it is documentation only and
  // is never fetched unless it is also listed in SHIPPED_AUDIO.
  const MUSIC_CATALOG = {
    // Ambient and exploration tracks.
    desert_silence: {
      plannedFile: 'ambient/desert-silence.mp3',
      duration: 300,
      theme: 'exploration',
      intensity: 0.3,
    },
    monastery_bells: {
      plannedFile: 'ambient/monastery-bells.mp3',
      duration: 240,
      theme: 'prayer',
      intensity: 0.4,
    },
    hesychasm_flow: {
      plannedFile: 'ambient/hesychasm-flow.mp3',
      duration: 360,
      theme: 'meditation',
      intensity: 0.35,
    },
    theoria_ascending: {
      plannedFile: 'ambient/theoria-ascending.mp3',
      duration: 420,
      theme: 'revelation',
      intensity: 0.6,
    },
    apophatic_void: {
      plannedFile: 'ambient/apophatic-void.mp3',
      duration: 480,
      theme: 'mystical',
      intensity: 0.5,
    },

    // NPC character themes.
    elder_sergius_theme: {
      plannedFile: 'npc-themes/elder-sergius.mp3',
      duration: 180,
      npc: 'elder_sergius',
      intensity: 0.5,
    },
    theodora_theme: {
      plannedFile: 'npc-themes/theodora.mp3',
      duration: 150,
      npc: 'theodora',
      intensity: 0.45,
    },
    isaias_theme: {
      plannedFile: 'npc-themes/isaias.mp3',
      duration: 170,
      npc: 'isaias',
      intensity: 0.55,
    },
    abbot_moses_theme: {
      plannedFile: 'npc-themes/abbot-moses.mp3',
      duration: 160,
      npc: 'abbot_moses',
      intensity: 0.48,
    },
    sister_catherine_theme: {
      plannedFile: 'npc-themes/sister-catherine.mp3',
      duration: 140,
      npc: 'sister_catherine',
      intensity: 0.52,
    },

    // Knowledge gate challenge themes.
    foundational_gate: {
      plannedFile: 'knowledge-gates/foundational-challenge.mp3',
      duration: 120,
      gate: 1,
      intensity: 0.4,
    },
    liturgical_gate: {
      plannedFile: 'knowledge-gates/liturgical-challenge.mp3',
      duration: 150,
      gate: 2,
      intensity: 0.5,
    },
    ascetic_gate: {
      plannedFile: 'knowledge-gates/ascetic-challenge.mp3',
      duration: 180,
      gate: 3,
      intensity: 0.6,
    },

    // Story moments.
    encounter_theme: {
      plannedFile: 'story/first-encounter.mp3',
      duration: 200,
      scene: 'first_encounter',
      intensity: 0.55,
    },
    victory_theme: {
      plannedFile: 'story/victory-enlightenment.mp3',
      duration: 240,
      scene: 'victory',
      intensity: 0.7,
    },
  };

  // SFX library.  The "cue" field links each key to its meaning in
  // SEMANTIC_CUES.  While the recorded asset does not exist, the sacred
  // synth renders the SFX key itself (it knows every key here), and
  // plannedFile, as above, is never fetched unless shipped.
  const SFX_CATALOG = {
    // Environmental.
    desert_wind: {
      plannedFile: 'sfx/environment/desert-wind.wav', duration: 8,
      cue: 'world_change',
    },
    sand_footsteps: {
      plannedFile: 'sfx/environment/sand-footsteps.wav', duration: 3,
    },
    monastery_bell_toll: {
      plannedFile: 'sfx/environment/monastery-bell.wav', duration: 4,
      cue: 'prayer_delivered',
    },
    water_flow: {
      plannedFile: 'sfx/environment/water-flow.wav', duration: 6,
    },

    // Character actions.
    character_breathing: {
      plannedFile: 'sfx/character/breathing.wav', duration: 2,
    },
    character_footsteps: {
      plannedFile: 'sfx/character/footsteps.wav', duration: 3,
    },
    robe_rustle: {
      plannedFile: 'sfx/character/robe-rustle.wav', duration: 2,
    },
    kneeling_sound: {
      plannedFile: 'sfx/character/kneeling.wav', duration: 1.5,
      cue: 'constitution',
    },

    // Spiritual actions.
    prayer_vocalization: {
      plannedFile: 'sfx/spiritual/prayer-vocalization.wav', duration: 4,
    },
    blessing_sound: {
      plannedFile: 'sfx/spiritual/blessing.wav', duration: 3,
      cue: 'teaching_complete',
    },
    transformation_effect: {
      plannedFile: 'sfx/spiritual/transformation.wav', duration: 2.5,
      cue: 'world_change',
    },
    meditation_bell: {
      plannedFile: 'sfx/spiritual/meditation-bell.wav', duration: 3,
      cue: 'prayer_delivered',
    },

    // UI feedback.
    // No recording is planned for this key.  A "positive tone" would
    // be a reward ding, and the Wisdom voice it used to borrow made a
    // chant-like voice answer every bonus (TABOO 0.2 item 5, rule 16).
    // It is a plucked gusli string rising a step, rendered by the
    // synth under the same key (recipe form_growth).
    ui_positive: { duration: 1.3, cue: 'form_growth' },
    ui_negative: {
      plannedFile: 'sfx/ui/negative-tone.wav', duration: 0.5,
      cue: 'gate_locked',
    },
    ui_neutral: {
      plannedFile: 'sfx/ui/neutral-tone.wav', duration: 0.4,
      cue: 'choice',
    },
    ui_confirm: {
      plannedFile: 'sfx/ui/confirm.wav', duration: 0.6, cue: 'choice',
    },
  };

  // Semantic cue table: the meaning each sound carries (constitution,
  // "sound is a language").  Pitch follows FORM: high, rising voices
  // for Wisdom (spiritual ascent), low voices for Constitution
  // (rootedness).  The sound itself is rendered by LudusSacredSynth
  // under the same key; nothing is random, so the same event always
  // sounds the same.  Bells appear only in their liturgical meanings
  // and never as a reward ding (docs/SOUND_THEOLOGY_RULES.md).
  const SEMANTIC_CUES = {
    prayer_delivered: {
      meaning: 'One благовест stroke: the prayer has been delivered.',
      layer: 'sfx',
    },
    world_change: {
      meaning: 'Wind: the world is changing around the player.',
      layer: 'ambience',
    },
    teaching_complete: {
      // Stillness, not a peal: a bell never answers a UI event (TABOO
      // 0.35 rule 9); the silence after a word is the teaching's echo.
      meaning: 'Stillness after the word: a teaching has been received.',
      layer: 'sfx',
    },
    choice: {
      // The semantron (било) is a sacred object (TABOO 0.35 rule 6), so the
      // interface knocks are ordinary wood, not the monastery's board.
      meaning: 'One light tap on a wooden desk: a word was chosen.',
      layer: 'sfx',
    },
    gate_locked: {
      meaning: 'Muted knock on a wooden door: FORM is not yet sufficient.',
      layer: 'sfx',
    },
    // One cue per constitutional attribute, ordered high to low.  They
    // are wordless voices or wood, never bells.
    wisdom: {
      meaning: 'Voice rising a step: Wisdom grows (ascent, noesis).',
      layer: 'sfx',
    },
    faith: {
      meaning: 'Open fifth in voices: Faith strengthened.',
      layer: 'sfx',
    },
    erudition: {
      meaning: 'Parchment and a clear upper voice: Erudition.',
      layer: 'sfx',
    },
    charisma: {
      meaning: 'Voices in unison and octave: Charisma, the community.',
      layer: 'sfx',
    },
    dexterity: {
      meaning: 'Two quick semantron taps: Dexterity, practice.',
      layer: 'sfx',
    },
    cunning: {
      meaning: 'A muted low knock: Cunning, a hidden path.',
      layer: 'sfx',
    },
    constitution: {
      meaning: 'Low steady ison with октавист: Constitution, roots.',
      layer: 'sfx',
    },
    // Any FORM growth after a choice.  A folk string, not a voice or a
    // bell, so an ordinary game event never borrows a sacred sound.
    form_growth: {
      meaning: 'Two gusli plucks rising a step: FORM has grown.',
      layer: 'sfx',
    },
    // Ringing orders of the Typikon (kolokol research, chapter 25).
    blagovest: {
      meaning: 'Благовест: measured strokes call to prayer.',
      layer: 'sfx',
    },
    trezvon: {
      meaning: 'Трезвон: the joy of the feast.',
      layer: 'sfx',
    },
    perezvon: {
      meaning: 'Перезвон, large to small: solemn procession.',
      layer: 'sfx',
    },
    perebor: {
      meaning: 'Перебор, small to large then all: mourning.',
      layer: 'sfx',
    },
    zvon_v_dvoi: {
      meaning: 'Звон в двои: Lenten restraint.',
      layer: 'sfx',
    },
    semantron: {
      meaning: 'Semantron: the prophets\' voice before the Gospel.',
      layer: 'sfx',
    },
    ison: {
      meaning: 'Ison: the wordless drone of chant, breathing prayer.',
      layer: 'music',
    },
    // ROV lake.
    sonar_ping: {
      meaning: 'Sonar ping and echo: depth is known by listening.',
      layer: 'sfx',
    },
    water: {
      meaning: 'Lake water: the depth the ROV observes.',
      layer: 'ambience',
    },
    // Silence is a sound state with its own meaning.
    hesychia: {
      meaning: 'Hesychia: stillness, the room tone of a stone church.',
      layer: 'ambience',
    },
    // Antagonists: the passions never get sacred sounds.
    passion: {
      meaning: 'A passion: unresolved dissonance, stilled by hesychia.',
      layer: 'sfx',
    },
  };

  // The eight logismoi (Evagrius) as separate antagonist cues.
  ['gluttony', 'lust', 'avarice', 'sorrow', 'anger', 'acedia',
    'vainglory', 'pride'].forEach(function (name) {
    SEMANTIC_CUES['passion_' + name] = {
      meaning: `The passion of ${name}: dissonance that never resolves.`,
      layer: 'sfx',
    };
  });

  // ── Preferences ────────────────────────────────────────────────────
  // Storage can be missing or throw (private mode, blocked site data,
  // Quest Browser guest profile); the defaults must still work.
  function loadPrefs() {
    const result = JSON.parse(JSON.stringify(DEFAULT_PREFS));
    try {
      const raw = window.localStorage.getItem(PREFS_KEY);
      if (!raw) {
        return result;
      }
      const saved = JSON.parse(raw);
      if (typeof saved.master === 'number') {
        result.master = clamp01(saved.master);
      }
      result.muted = saved.muted === true;
      if (saved.layers && typeof saved.layers === 'object') {
        for (const name of Object.keys(result.layers)) {
          if (typeof saved.layers[name] === 'number') {
            result.layers[name] = clamp01(saved.layers[name]);
          }
        }
      }
    } catch (err) {
      // Corrupt or unavailable storage: fall back to defaults.
    }
    return result;
  }

  function savePrefs() {
    try {
      window.localStorage.setItem(PREFS_KEY, JSON.stringify(prefs));
    } catch (err) {
      // Not persisting is acceptable; the session still honours it.
    }
  }

  function clamp01(value) {
    const number = Number(value);
    if (!Number.isFinite(number)) {
      return 0;
    }
    return Math.max(0, Math.min(1, number));
  }

  // ── Graph construction ─────────────────────────────────────────────
  // Moves an AudioParam to a new value without a discontinuity.  The
  // current value is pinned first so a pending ramp does not jump.
  function smoothSet(param, value, timeConstant) {
    if (!audioContext) {
      return;
    }
    const now = audioContext.currentTime;
    param.cancelScheduledValues(now);
    param.setValueAtTime(param.value, now);
    param.setTargetAtTime(value, now, timeConstant || SMOOTH);
  }

  function masterTarget() {
    return prefs.muted ? 0 : prefs.master;
  }

  function buildGraph() {
    masterGain = audioContext.createGain();
    masterGain.gain.value = masterTarget();

    // Four layers at full volume can sum above 0 dBFS.  A fast, hard
    // compressor acts as a limiter so peaks never clip on the headset.
    limiter = audioContext.createDynamicsCompressor();
    limiter.threshold.value = -3;
    limiter.knee.value = 0;
    limiter.ratio.value = 20;
    limiter.attack.value = 0.003;
    limiter.release.value = 0.25;

    masterGain.connect(limiter);
    limiter.connect(audioContext.destination);

    for (const name of Object.keys(layers)) {
      const layer = layers[name];
      layer.duck = audioContext.createGain();
      layer.gain = audioContext.createGain();
      layer.gain.gain.value = prefs.layers[name];
      layer.duck.connect(layer.gain);
      layer.gain.connect(masterGain);
    }
  }

  // Returns the context only when it may legally exist, i.e. after a
  // gesture.  Creating it earlier yields a context stuck in 'suspended'
  // and a console warning on every page load.
  function ensureContext() {
    if (audioContext) {
      return audioContext;
    }
    const activation = navigator.userActivation;
    const activated = gestureSeen ||
      (activation && activation.hasBeenActive);
    if (!activated) {
      return null;
    }
    const ContextClass = window.AudioContext || window.webkitAudioContext;
    if (!ContextClass) {
      return null;
    }
    try {
      audioContext = new ContextClass({ latencyHint: 'interactive' });
    } catch (err) {
      console.warn('[Ludus Audio] AudioContext unavailable:', err);
      return null;
    }
    buildGraph();
    // The headset may suspend audio (headset removed, system overlay);
    // re-arm the gesture unlock so the next tap brings sound back.
    audioContext.addEventListener('statechange', function () {
      if (audioContext.state !== 'running') {
        armUnlock();
      }
    });
    initialized = true;
    console.log('[Ludus Audio] Web Audio API initialized');
    return audioContext;
  }

  // Resumes a suspended context.  The timeout keeps a call from hanging
  // when the browser silently ignores resume() outside a gesture.
  function resumeContext() {
    const context = ensureContext();
    if (!context) {
      return Promise.resolve(false);
    }
    if (context.state === 'running') {
      return Promise.resolve(true);
    }
    const attempt = context.resume().catch(function () {});
    const timeout = new Promise(function (resolve) {
      setTimeout(resolve, 300);
    });
    return Promise.race([attempt, timeout]).then(function () {
      return context.state === 'running';
    });
  }

  // ── Autoplay unlock ────────────────────────────────────────────────
  const UNLOCK_EVENTS = ['pointerdown', 'keydown', 'touchend'];

  function onGesture() {
    gestureSeen = true;
    resumeContext().then(function (running) {
      if (running) {
        disarmUnlock();
      }
    });
  }

  function armUnlock() {
    if (unlockArmed || typeof document === 'undefined') {
      return;
    }
    unlockArmed = true;
    for (const type of UNLOCK_EVENTS) {
      document.addEventListener(type, onGesture,
        { capture: true, passive: true });
    }
  }

  function disarmUnlock() {
    if (!unlockArmed) {
      return;
    }
    unlockArmed = false;
    for (const type of UNLOCK_EVENTS) {
      document.removeEventListener(type, onGesture, { capture: true });
    }
  }

  // ── Loading ────────────────────────────────────────────────────────
  // Resolves to an AudioBuffer, or null on 404, network or decode
  // failure.  Rejections are converted here so no caller can crash.
  function loadAudioBuffer(filePath) {
    if (bufferCache.has(filePath)) {
      return bufferCache.get(filePath);
    }
    const url = `${AUDIO_PATH}/${filePath}`;
    const pending = fetch(url)
      .then(function (response) {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.arrayBuffer();
      })
      .then(function (data) {
        return new Promise(function (resolve, reject) {
          // The callback form also works on older WebKit builds.
          const result = audioContext.decodeAudioData(data, resolve,
            reject);
          if (result && typeof result.catch === 'function') {
            result.catch(reject);
          }
        });
      })
      .catch(function (err) {
        if (!warnedPaths.has(filePath)) {
          warnedPaths.add(filePath);
          console.warn(`[Ludus Audio] Asset unavailable: ${url}`,
            err && err.message ? err.message : err);
        }
        return null;
      });
    bufferCache.set(filePath, pending);
    return pending;
  }

  // ── Spatial helpers ────────────────────────────────────────────────
  function readPosition(options) {
    if (options.position) {
      return options.position;
    }
    if (options.spatialize) {
      return { x: options.x || 0, y: options.y || 0, z: options.z || -1 };
    }
    return null;
  }

  function setPannerPosition(panner, pos) {
    const x = Number(pos.x) || 0;
    const y = Number(pos.y) || 0;
    const z = Number(pos.z) || 0;
    if (panner.positionX) {
      panner.positionX.value = x;
      panner.positionY.value = y;
      panner.positionZ.value = z;
    } else {
      panner.setPosition(x, y, z);
    }
  }

  // HRTF gives binaural cues on the Quest 3 speakers and headphones;
  // equal-power panning would only move the sound left and right.
  function createPanner(pos) {
    const panner = audioContext.createPanner();
    panner.panningModel = 'HRTF';
    panner.distanceModel = 'inverse';
    panner.refDistance = 1;
    panner.maxDistance = 50;
    panner.rolloffFactor = 1;
    setPannerPosition(panner, pos);
    liveNodes += 1;
    return panner;
  }

  /**
   * Updates the listener from the head pose (metres, WebXR axes).
   * pose: { position: {x, y, z}, forward: {x, y, z}, up: {x, y, z} }
   */
  function setListenerPose(pose) {
    if (!audioContext || !pose) {
      return;
    }
    const listener = audioContext.listener;
    const p = pose.position || { x: 0, y: 0, z: 0 };
    const f = pose.forward || { x: 0, y: 0, z: -1 };
    const u = pose.up || { x: 0, y: 1, z: 0 };
    if (listener.positionX) {
      const now = audioContext.currentTime;
      // Short ramps: the pose arrives every frame and a hard jump per
      // frame produces zipper noise in HRTF processing.
      listener.positionX.setTargetAtTime(p.x || 0, now, 0.02);
      listener.positionY.setTargetAtTime(p.y || 0, now, 0.02);
      listener.positionZ.setTargetAtTime(p.z || 0, now, 0.02);
      listener.forwardX.setTargetAtTime(f.x, now, 0.02);
      listener.forwardY.setTargetAtTime(f.y, now, 0.02);
      listener.forwardZ.setTargetAtTime(f.z, now, 0.02);
      listener.upX.setTargetAtTime(u.x, now, 0.02);
      listener.upY.setTargetAtTime(u.y, now, 0.02);
      listener.upZ.setTargetAtTime(u.z, now, 0.02);
    } else {
      listener.setPosition(p.x || 0, p.y || 0, p.z || 0);
      listener.setOrientation(f.x, f.y, f.z, u.x, u.y, u.z);
    }
  }

  /** Records where an NPC stands so its voice comes from there. */
  function setNpcPosition(npcId, position) {
    if (!npcId) {
      return;
    }
    if (position) {
      npcPositions.set(npcId, {
        x: Number(position.x) || 0,
        y: Number(position.y) || 0,
        z: Number(position.z) || 0,
      });
    } else {
      npcPositions.delete(npcId);
    }
  }

  // ── Voice lifecycle ────────────────────────────────────────────────
  // Wires source -> [panner] -> voice gain -> layer and makes sure the
  // whole chain is disconnected when the source ends, however it ends.
  function startVoice(source, layerName, options, onEnd) {
    const layer = layers[layerName];
    const now = audioContext.currentTime;
    const voice = audioContext.createGain();
    liveNodes += 2;  // The source and its voice gain.

    let head = source;
    let panner = null;
    const pos = readPosition(options);
    if (pos) {
      panner = createPanner(pos);
      source.connect(panner);
      head = panner;
    }
    head.connect(voice);
    voice.connect(layer.duck);

    const level = typeof options.volume === 'number' ?
      clamp01(options.volume) : 1;
    // A fade-in ramps the per-voice gain; AudioBufferSourceNode has no
    // gain of its own, which is why the old code threw here.
    if (options.fadeIn > 0) {
      voice.gain.setValueAtTime(0, now);
      voice.gain.linearRampToValueAtTime(level, now + options.fadeIn);
    } else {
      voice.gain.setValueAtTime(level, now);
    }

    const entry = { source, voice, panner, layer: layerName };
    activeSources.push(entry);

    // Callers such as the dialogue UI call source.stop() directly.  The
    // override fades the voice first so stopping never clicks.
    const rawStop = source.stop.bind(source);
    let stopped = false;
    source.stop = function (when) {
      if (stopped) {
        return;
      }
      stopped = true;
      const t = Math.max(audioContext.currentTime, Number(when) || 0);
      voice.gain.cancelScheduledValues(t);
      voice.gain.setValueAtTime(voice.gain.value, t);
      voice.gain.setTargetAtTime(0, t, 0.015);
      try {
        rawStop(t + 0.08);
      } catch (err) {
        // Never started or already stopped.
      }
    };

    source.onended = function () {
      const idx = activeSources.indexOf(entry);
      if (idx > -1) {
        activeSources.splice(idx, 1);
        source.disconnect();
        voice.disconnect();
        liveNodes -= 2;
        if (panner) {
          panner.disconnect();
          liveNodes -= 1;
        }
        if (onEnd) {
          onEnd();
        }
      }
    };

    source.start(now);
    return source;
  }

  // Automatic ducking: while any dialogue voice sounds, the other
  // layers step back so the teaching is intelligible.
  function dialogueStarted() {
    dialogueVoices += 1;
    applyDucking(['dialogue']);
  }

  function dialogueEnded() {
    dialogueVoices = Math.max(0, dialogueVoices - 1);
    if (dialogueVoices === 0) {
      applyDucking([]);
    }
  }

  // ── Procedural stand-ins ───────────────────────────────────────────
  // Renders a catalogue key with the sacred synth and caches the
  // buffer, so the render cost (tens to a few hundred milliseconds for
  // a thirty-second bed) is paid once per key per session.
  function sacredBuffer(key) {
    if (!key) {
      return Promise.resolve(null);
    }
    if (synthCache.has(key)) {
      return synthCache.get(key);
    }
    const synth = window.LudusSacredSynth;
    if (!synth || typeof synth.render !== 'function' || !synth.has(key)) {
      if (!synth && !synthMissingWarned) {
        synthMissingWarned = true;
        console.warn('[Ludus Audio] LudusSacredSynth not loaded; ' +
          'missing assets stay silent');
      }
      return Promise.resolve(null);
    }
    const job = Promise.resolve().then(function () {
      return synth.render(key, audioContext);
    }).catch(function (err) {
      console.warn(`[Ludus Audio] Cue render failed: ${key}`, err);
      return null;
    });
    synthCache.set(key, job);
    return job;
  }

  // ── Playback ───────────────────────────────────────────────────────
  // One-shots are dropped while the context cannot run; otherwise they
  // would all fire at once on the next tap, long after their moment.
  function isOneShot(layerName, options) {
    return !options.loop && layerName !== 'music';
  }

  /**
   * Plays a buffer on a layer.  Resolves to the AudioBufferSourceNode,
   * or null when audio is locked, the asset is missing or it is muted
   * out of existence.  Never rejects for asset problems.
   * layer: 'music' | 'dialogue' | 'sfx' | 'ambience'
   * options: { fadeIn, loop, volume, position: {x, y, z}, spatialize,
   *            x, y, z, synthKey, fallbackCue }
   * filePath is fetched only when it is listed in SHIPPED_AUDIO.
   * synthKey is the catalogue key rendered procedurally when there is
   * no shipped file; fallbackCue (a SEMANTIC_CUES key) is tried after
   * it.
   */
  async function playAudio(filePath, layer = 'sfx', options = {}) {
    if (!layers[layer]) {
      throw new Error(`Invalid layer: ${layer}`);
    }
    const running = await resumeContext();
    if (!audioContext) {
      return null;
    }
    if (!running && isOneShot(layer, options)) {
      return null;
    }

    // Only shipped files are requested; a missing one goes straight to
    // the synth instead of costing a 404 first.
    let buffer = isShipped(filePath) ? await loadAudioBuffer(filePath) :
      null;
    if (!buffer && options.synthKey) {
      buffer = await sacredBuffer(options.synthKey);
    }
    if (!buffer && options.fallbackCue &&
        SEMANTIC_CUES[options.fallbackCue]) {
      buffer = await sacredBuffer(options.fallbackCue);
    }
    if (!buffer) {
      return null;
    }

    const source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.loop = Boolean(options.loop);

    const isDialogue = layer === 'dialogue';
    if (isDialogue) {
      dialogueStarted();
    }
    return startVoice(source, layer, options,
      isDialogue ? dialogueEnded : null);
  }

  /** Plays a looping music track with a fade-in (seconds). */
  async function playMusic(trackKey, fadeIn = 2) {
    const track = MUSIC_CATALOG[trackKey];
    if (!track) {
      throw new Error(`Unknown track: ${trackKey}`);
    }
    return playAudio(track.plannedFile, 'music',
      { fadeIn, loop: true, synthKey: trackKey });
  }

  /**
   * Plays an NPC voice line.  Without an explicit position the voice is
   * placed where setNpcPosition() last saw the NPC.  No voice has
   * been recorded and the synth does not speak (a machine must not
   * imitate a mentor's voice), so until a line is listed in
   * SHIPPED_AUDIO this resolves to null without any request.
   */
  async function playDialogue(npcId, dialogueKey, options = {}) {
    const filePath = `dialogue/${npcId}/${dialogueKey}.mp3`;
    const merged = Object.assign({}, options);
    if (!readPosition(merged) && npcPositions.has(npcId)) {
      merged.position = npcPositions.get(npcId);
    }
    return playAudio(filePath, 'dialogue', merged);
  }

  /** Plays a catalogued SFX, falling back to its semantic cue. */
  async function playSfx(sfxKey, options = {}) {
    const sfx = SFX_CATALOG[sfxKey];
    if (!sfx) {
      throw new Error(`Unknown SFX: ${sfxKey}`);
    }
    const merged = Object.assign(
      { synthKey: sfxKey, fallbackCue: sfx.cue }, options);
    return playAudio(sfx.plannedFile, 'sfx', merged);
  }

  /**
   * Plays a sound by meaning (a key of SEMANTIC_CUES, for example
   * 'prayer_delivered' or an attribute name such as 'wisdom').
   */
  async function playCue(cueKey, options = {}) {
    const cue = SEMANTIC_CUES[cueKey];
    if (!cue) {
      throw new Error(`Unknown cue: ${cueKey}`);
    }
    const merged = Object.assign({ synthKey: cueKey }, options);
    return playAudio(cue.plannedFile || null, cue.layer, merged);
  }

  // ── Mixing ─────────────────────────────────────────────────────────
  function applyDucking(playingLayers) {
    if (!audioContext) {
      return;
    }
    const list = Array.isArray(playingLayers) ? playingLayers : [];
    let factors = {};
    if (list.includes('dialogue') || dialogueVoices > 0) {
      factors = DUCK_DIALOGUE;
    } else if (list.includes('music')) {
      factors = DUCK_MUSIC;
    }
    for (const name of Object.keys(layers)) {
      const target = typeof factors[name] === 'number' ?
        factors[name] : 1;
      // 100 ms to duck and 250 ms to recover sounds like a mixer
      // riding the fader, not like a gate slamming shut.
      smoothSet(layers[name].duck.gain, target,
        target < 1 ? 0.1 : 0.25);
    }
  }

  /**
   * Dynamic layer ducking.  ['dialogue'] ducks music, sfx and ambience;
   * ['music'] ducks ambience; [] restores the player's own levels.
   */
  function updateLayerDucking(playingLayers) {
    applyDucking(playingLayers);
  }

  /** Stops every voice with a short fade and releases its nodes. */
  function stopAll() {
    activeSources.slice().forEach(function (entry) {
      try {
        entry.source.stop();
      } catch (err) {
        // Already stopped.
      }
    });
    console.log('[Ludus Audio] Stopped all audio');
  }

  /** Sets master volume (0-1); persisted across sessions. */
  function setMasterVolume(vol) {
    prefs.master = clamp01(vol);
    savePrefs();
    if (masterGain) {
      smoothSet(masterGain.gain, masterTarget());
    }
  }

  function getMasterVolume() {
    return prefs.master;
  }

  /** Sets one layer's volume (0-1); persisted across sessions. */
  function setLayerVolume(layer, vol) {
    if (!Object.prototype.hasOwnProperty.call(prefs.layers, layer)) {
      return;
    }
    prefs.layers[layer] = clamp01(vol);
    savePrefs();
    if (layers[layer].gain) {
      smoothSet(layers[layer].gain.gain, prefs.layers[layer]);
    }
  }

  function getLayerVolume(layer) {
    return prefs.layers[layer];
  }

  /** Mutes or unmutes everything; persisted across sessions. */
  function setMuted(muted) {
    prefs.muted = Boolean(muted);
    savePrefs();
    if (masterGain) {
      smoothSet(masterGain.gain, masterTarget());
    }
  }

  function isMuted() {
    return prefs.muted;
  }

  function toggleMute() {
    setMuted(!prefs.muted);
    return prefs.muted;
  }

  /**
   * Places the listener at the ROV / player position.  A Wwise bridge,
   * when present, receives the same pose; otherwise Web Audio's HRTF
   * listener is used, which is what the Quest 3 browser build runs.
   */
  function setupVRSpatialAudio(rovPosition, orientation) {
    const pose = Object.assign({ position: rovPosition || null },
      orientation || {});
    if (window.Wwise && typeof window.Wwise.setListenerPose ===
        'function') {
      try {
        window.Wwise.setListenerPose(pose);
      } catch (err) {
        console.warn('[Ludus Audio] Wwise listener update failed:', err);
      }
    }
    setListenerPose(pose);
  }

  /** Diagnostic counters, used to detect leaked voices in tests. */
  function getStats() {
    return {
      contextState: audioContext ? audioContext.state : 'none',
      activeSources: activeSources.length,
      liveNodes: liveNodes,
      dialogueVoices: dialogueVoices,
      cachedBuffers: bufferCache.size,
      synthesizedCues: synthCache.size,
      muted: prefs.muted,
      master: prefs.master,
    };
  }

  /**
   * Prepares the manager.  Safe to call more than once and before any
   * gesture: it only arms the unlock listeners, and creates the context
   * immediately when the page has already been activated.
   */
  function init() {
    armUnlock();
    if (navigator.userActivation && navigator.userActivation.isActive) {
      onGesture();
    }
    console.log('[Ludus Audio] Manager initialized');
  }

  // Nothing in the page calls init() today, so arm the unlock on load;
  // otherwise the first sound would depend on who happened to call.
  armUnlock();

  // ── Public API ─────────────────────────────────────────────────────
  return {
    init,
    playMusic,
    playDialogue,
    playSfx,
    playCue,
    stopAll,
    setMasterVolume,
    getMasterVolume,
    setLayerVolume,
    getLayerVolume,
    setMuted,
    isMuted,
    toggleMute,
    updateLayerDucking,
    setupVRSpatialAudio,
    setListenerPose,
    setNpcPosition,
    resume: resumeContext,
    getStats,
    getAudioContext: () => audioContext,
    isInitialized: () => initialized,
    MUSIC_CATALOG,
    SFX_CATALOG,
    SEMANTIC_CUES,
  };
})();

console.log('[Ludus] Audio Manager loaded');
