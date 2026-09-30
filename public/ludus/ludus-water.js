/**
 * Ludus: water physics for the ROV dive (HLD F3; CLAUDE.md TABOO 0.35
 * rule 19: deterministic and correct; a false constant is a "false
 * victory" a diver notices at once).
 *
 * Every value here is computed from telemetry, never guessed:
 *   - speed of sound: 1480 m/s above the thermocline, 1435 m/s below
 *     (the rule's figures for the cold, still hypolimnion);
 *   - echo delay of a sonar ping: out and back, 2 * range / c;
 *   - pressure: one standard atmosphere plus 1 bar per 10.2 m;
 *   - ascent rate in m/min from two readings, with the diver's limit
 *     of 10 m/min (faster risks decompression injury: PADI and most
 *     agencies teach 9-18 m/min at most, the safe side is kept);
 *   - colour fading with depth by Beer-Lambert over the absorption of
 *     clear water (Pope and Fry 1997: red 650 nm about 0.34 /m, green
 *     550 nm about 0.057 /m, blue 450 nm about 0.009 /m); real lake
 *     water absorbs more, so these are the lower bound;
 *   - bubble cadence: one plume per breath of the active hesychast
 *     pattern (ludus-sacred-synth.js BREATH), not a free number.
 * Pure functions; window.LudusWater in the browser.
 */

'use strict';

(function (root) {
  const C_ABOVE = 1480;
  const C_BELOW = 1435;
  const SURFACE_BAR = 1.01325;
  const METRES_PER_BAR = 10.2;
  const MAX_ASCENT_M_PER_MIN = 10;
  // Absorption of clear water, 1/m (Pope and Fry 1997).
  const ABSORPTION = { red: 0.34, green: 0.057, blue: 0.009 };

  function soundSpeed(depthM, thermoclineM) {
    return depthM > thermoclineM ? C_BELOW : C_ABOVE;
  }

  /** Seconds for a ping to reach a target at rangeM and come back. */
  function echoDelay(rangeM, depthM, thermoclineM) {
    return (2 * rangeM) / soundSpeed(depthM, thermoclineM);
  }

  function pressureBar(depthM) {
    return SURFACE_BAR + Math.max(0, depthM) / METRES_PER_BAR;
  }

  /**
   * Rate of ascent (positive when rising) from two readings.  Returns
   * {mPerMin, tooFast}; a zero or negative time step gives null.
   */
  function ascent(prevDepthM, depthM, dtSec) {
    if (!(dtSec > 0)) {
      return null;
    }
    const mPerMin = ((prevDepthM - depthM) / dtSec) * 60;
    return { mPerMin, tooFast: mPerMin > MAX_ASCENT_M_PER_MIN };
  }

  /** Fraction of surface light left in each band after depthM of water. */
  function lightLeft(depthM) {
    const d = Math.max(0, depthM);
    const out = {};
    Object.keys(ABSORPTION).forEach((band) => {
      out[band] = Math.exp(-ABSORPTION[band] * d);
    });
    return out;
  }

  /** Plumes per minute for a breathing pattern {inhale, holdIn, ...}. */
  function bubblesPerMinute(pattern) {
    const cycle = pattern.inhale + pattern.holdIn + pattern.exhale
      + pattern.holdOut;
    return 60 / cycle;
  }

  const api = { soundSpeed, echoDelay, pressureBar, ascent, lightLeft,
    bubblesPerMinute, C_ABOVE, C_BELOW, MAX_ASCENT_M_PER_MIN,
    ABSORPTION };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusWater = api;
  }
})(typeof window !== 'undefined' ? window : null);
