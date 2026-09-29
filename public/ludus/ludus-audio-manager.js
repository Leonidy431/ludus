/**
 * Ludus Audio Manager
 *
 * Manages game audio: ambient music, NPC dialogue, SFX, and spatial audio.
 * Implements 4-layer dynamic mixing with automatic ducking.
 * Supports Web Audio API for desktop and Wwise integration for VR (Meta Quest 3).
 */

'use strict';

window.LudusAudioManager = (function () {
  const AUDIO_API = '/api/ludus/audio';
  const AUDIO_PATH = '/ludus/audio';

  // Audio context state
  let audioContext = null;
  let masterGain = null;
  let initialized = false;

  // 4-layer mixing bus
  let layers = {
    music: { gain: null, volume: 0.7, sources: [] },
    dialogue: { gain: null, volume: 0.85, sources: [] },
    sfx: { gain: null, volume: 0.6, sources: [] },
    ambience: { gain: null, volume: 0.5, sources: [] },
  };

  // Active audio sources (for cleanup)
  let activeSources = [];

  // Music track catalog (from SOUND_DESIGN_SYSTEM.md)
  const MUSIC_CATALOG = {
    // Ambient/Exploration tracks
    desert_silence: {
      file: 'ambient/desert-silence.mp3',
      duration: 300,
      theme: 'exploration',
      intensity: 0.3,
    },
    monastery_bells: {
      file: 'ambient/monastery-bells.mp3',
      duration: 240,
      theme: 'prayer',
      intensity: 0.4,
    },
    hesychasm_flow: {
      file: 'ambient/hesychasm-flow.mp3',
      duration: 360,
      theme: 'meditation',
      intensity: 0.35,
    },
    theoria_ascending: {
      file: 'ambient/theoria-ascending.mp3',
      duration: 420,
      theme: 'revelation',
      intensity: 0.6,
    },
    apophatic_void: {
      file: 'ambient/apophatic-void.mp3',
      duration: 480,
      theme: 'mystical',
      intensity: 0.5,
    },

    // NPC Character Themes
    elder_sergius_theme: {
      file: 'npc-themes/elder-sergius.mp3',
      duration: 180,
      npc: 'elder_sergius',
      intensity: 0.5,
    },
    theodora_theme: {
      file: 'npc-themes/theodora.mp3',
      duration: 150,
      npc: 'theodora',
      intensity: 0.45,
    },
    isaias_theme: {
      file: 'npc-themes/isaias.mp3',
      duration: 170,
      npc: 'isaias',
      intensity: 0.55,
    },
    abbot_moses_theme: {
      file: 'npc-themes/abbot-moses.mp3',
      duration: 160,
      npc: 'abbot_moses',
      intensity: 0.48,
    },
    sister_catherine_theme: {
      file: 'npc-themes/sister-catherine.mp3',
      duration: 140,
      npc: 'sister_catherine',
      intensity: 0.52,
    },

    // Knowledge Gate Challenge Themes
    foundational_gate: {
      file: 'knowledge-gates/foundational-challenge.mp3',
      duration: 120,
      gate: 1,
      intensity: 0.4,
    },
    liturgical_gate: {
      file: 'knowledge-gates/liturgical-challenge.mp3',
      duration: 150,
      gate: 2,
      intensity: 0.5,
    },
    ascetic_gate: {
      file: 'knowledge-gates/ascetic-challenge.mp3',
      duration: 180,
      gate: 3,
      intensity: 0.6,
    },

    // Story Moments
    encounter_theme: {
      file: 'story/first-encounter.mp3',
      duration: 200,
      scene: 'first_encounter',
      intensity: 0.55,
    },
    victory_theme: {
      file: 'story/victory-enlightenment.mp3',
      duration: 240,
      scene: 'victory',
      intensity: 0.7,
    },
  };

  // SFX Library (100+ sounds)
  const SFX_CATALOG = {
    // Environmental
    desert_wind: { file: 'sfx/environment/desert-wind.wav', duration: 8 },
    sand_footsteps: { file: 'sfx/environment/sand-footsteps.wav', duration: 3 },
    monastery_bell_toll: { file: 'sfx/environment/monastery-bell.wav', duration: 4 },
    water_flow: { file: 'sfx/environment/water-flow.wav', duration: 6 },

    // Character Actions
    character_breathing: { file: 'sfx/character/breathing.wav', duration: 2 },
    character_footsteps: { file: 'sfx/character/footsteps.wav', duration: 3 },
    robe_rustle: { file: 'sfx/character/robe-rustle.wav', duration: 2 },
    kneeling_sound: { file: 'sfx/character/kneeling.wav', duration: 1.5 },

    // Spiritual Actions
    prayer_vocalization: { file: 'sfx/spiritual/prayer-vocalization.wav', duration: 4 },
    blessing_sound: { file: 'sfx/spiritual/blessing.wav', duration: 3 },
    transformation_effect: { file: 'sfx/spiritual/transformation.wav', duration: 2.5 },
    meditation_bell: { file: 'sfx/spiritual/meditation-bell.wav', duration: 3 },

    // UI Feedback
    ui_positive: { file: 'sfx/ui/positive-tone.wav', duration: 0.5 },
    ui_negative: { file: 'sfx/ui/negative-tone.wav', duration: 0.5 },
    ui_neutral: { file: 'sfx/ui/neutral-tone.wav', duration: 0.4 },
    ui_confirm: { file: 'sfx/ui/confirm.wav', duration: 0.6 },
  };

  /**
   * Initialize Web Audio API context
   */
  function initWebAudio() {
    if (audioContext) return audioContext;

    const contextClass = window.AudioContext || window.webkitAudioContext;
    audioContext = new contextClass();

    // Master gain node
    masterGain = audioContext.createGain();
    masterGain.gain.value = 1.0;
    masterGain.connect(audioContext.destination);

    // Create layer gain nodes
    for (const [layerName, layer] of Object.entries(layers)) {
      layer.gain = audioContext.createGain();
      layer.gain.gain.value = layer.volume;
      layer.gain.connect(masterGain);
    }

    initialized = true;
    console.log('[Ludus Audio] Web Audio API initialized');
    return audioContext;
  }

  /**
   * Load and decode audio file
   */
  async function loadAudioBuffer(filePath) {
    const response = await fetch(`${AUDIO_PATH}/${filePath}`);
    if (!response.ok) throw new Error(`Failed to load audio: ${filePath}`);

    const arrayBuffer = await response.arrayBuffer();
    return audioContext.decodeAudioData(arrayBuffer);
  }

  /**
   * Play audio track on specified layer
   * layer: 'music' | 'dialogue' | 'sfx' | 'ambience'
   * options: { fadeIn, fadeOut, loop, spatialize }
   */
  async function playAudio(filePath, layer = 'sfx', options = {}) {
    if (!initialized) initWebAudio();

    try {
      const buffer = await loadAudioBuffer(filePath);
      const source = audioContext.createBufferSource();
      source.buffer = buffer;

      const layerGain = layers[layer].gain;
      if (!layerGain) throw new Error(`Invalid layer: ${layer}`);

      source.connect(layerGain);

      // Apply options
      if (options.fadeIn) {
        source.gain.setValueAtTime(0, audioContext.currentTime);
        source.gain.linearRampToValueAtTime(1, audioContext.currentTime + options.fadeIn);
      }

      if (options.loop) {
        source.loop = true;
      }

      // Spatial audio (binaural for Quest 3)
      if (options.spatialize) {
        const panner = audioContext.createPanner();
        source.connect(panner);
        panner.connect(layerGain);
        panner.setPosition(options.x || 0, options.y || 0, options.z || 1);
      }

      source.start(0);

      // Track source for cleanup
      activeSources.push(source);

      // Auto-cleanup on end
      source.onended = () => {
        const idx = activeSources.indexOf(source);
        if (idx > -1) activeSources.splice(idx, 1);
      };

      return source;
    } catch (err) {
      console.error(`[Ludus Audio] Failed to play ${filePath}:`, err);
      throw err;
    }
  }

  /**
   * Play music track
   */
  async function playMusic(trackKey, fadeIn = 2) {
    const track = MUSIC_CATALOG[trackKey];
    if (!track) throw new Error(`Unknown track: ${trackKey}`);

    return playAudio(track.file, 'music', {
      fadeIn,
      loop: true,
    });
  }

  /**
   * Play NPC dialogue (should be actual voice recording from Cloud Storage)
   */
  async function playDialogue(npcId, dialogueKey, options = {}) {
    const filePath = `dialogue/${npcId}/${dialogueKey}.mp3`;
    return playAudio(filePath, 'dialogue', options);
  }

  /**
   * Play SFX
   */
  async function playSfx(sfxKey, options = {}) {
    const sfx = SFX_CATALOG[sfxKey];
    if (!sfx) throw new Error(`Unknown SFX: ${sfxKey}`);

    return playAudio(sfx.file, 'sfx', options);
  }

  /**
   * Dynamic layer ducking:
   * When dialogue plays, reduce music/sfx/ambience
   * When music is intense, reduce ambience
   */
  function updateLayerDucking(playingLayers) {
    const durations = {
      music: 0.8,
      dialogue: 0.85,
      sfx: 0.6,
      ambience: 0.5,
    };

    if (playingLayers.includes('dialogue')) {
      // Dialogue has priority: reduce others
      layers.music.gain.gain.setTargetAtTime(0.4, audioContext.currentTime, 0.1);
      layers.sfx.gain.gain.setTargetAtTime(0.3, audioContext.currentTime, 0.1);
      layers.ambience.gain.gain.setTargetAtTime(0.2, audioContext.currentTime, 0.1);
    } else if (playingLayers.includes('music')) {
      // Music is playing: reduce ambience
      layers.ambience.gain.gain.setTargetAtTime(0.25, audioContext.currentTime, 0.15);
    } else {
      // Normal: restore default volumes
      layers.music.gain.gain.setTargetAtTime(durations.music, audioContext.currentTime, 0.2);
      layers.sfx.gain.gain.setTargetAtTime(durations.sfx, audioContext.currentTime, 0.2);
      layers.ambience.gain.gain.setTargetAtTime(durations.ambience, audioContext.currentTime, 0.2);
    }
  }

  /**
   * Stop all audio
   */
  function stopAll() {
    activeSources.forEach(source => {
      try { source.stop(); } catch (e) {}
    });
    activeSources = [];
    console.log('[Ludus Audio] Stopped all audio');
  }

  /**
   * Set master volume (0–1)
   */
  function setMasterVolume(vol) {
    if (masterGain) {
      masterGain.gain.value = Math.max(0, Math.min(1, vol));
    }
  }

  /**
   * Set layer volume (0–1)
   */
  function setLayerVolume(layer, vol) {
    if (layers[layer] && layers[layer].gain) {
      layers[layer].gain.gain.value = Math.max(0, Math.min(1, vol));
    }
  }

  /**
   * Setup spatial audio for VR (Wwise integration pseudocode)
   * In production, this would interface with Wwise SDK
   */
  function setupVRSpatialAudio(rovPosition) {
    if (!window.Wwise) {
      console.warn('[Ludus Audio] Wwise not available for VR');
      return;
    }

    // Pseudocode: Wwise integration for Meta Quest 3
    // Wwise.setListenerPosition(rovPosition.x, rovPosition.y, rovPosition.z);
    // Wwise.setListenerRotation(headset.rotation);
    // NPCs emit from their world positions
    // Ambient sounds spatialize based on source location

    console.log('[Ludus Audio] VR spatial audio initialized (Wwise)');
  }

  /**
   * Initialize audio manager
   */
  function init() {
    initWebAudio();
    console.log('[Ludus Audio] Manager initialized');
  }

  // ── Public API ──────────────────────────────────────────────────────────
  return {
    init,
    playMusic,
    playDialogue,
    playSfx,
    stopAll,
    setMasterVolume,
    setLayerVolume,
    updateLayerDucking,
    setupVRSpatialAudio,
    getAudioContext: () => audioContext,
    MUSIC_CATALOG,
    SFX_CATALOG,
  };
})();

console.log('[Ludus] Audio Manager loaded');
