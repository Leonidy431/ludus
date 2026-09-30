/**
 * Ludus: the tone (глас) of the week and its ison (HLD F2, DEF-012/022;
 * CLAUDE.md TABOO 0.35 rule 10).
 *
 * The Octoechos repeats eight tones, one per week.  The cycle starts
 * with tone 1 on Thomas Sunday (Antipascha) and runs through the year
 * until Palm Sunday; Holy Week has no tone of its own; in Bright Week
 * each day has its own tone (Pascha 1, Monday 2, Tuesday 3, Wednesday
 * 4, Thursday 5, Friday 6, Saturday 8; the grave tone 7 is not sung in
 * that week of joy).  The week's tone begins at Saturday Vespers, so
 * the liturgical date (evening = next day) decides it.
 *
 * The ison is held on the tonic (base note) of the tone.  Byzantine
 * bases, with Ni = C3 as the reference: Pa = D, Di = G, Ga = F,
 * Zo (flat) = B-flat, Ni = C.  The frequencies live in
 * ludus-sacred-synth.js (cues ison_glas_1..8); the test keeps both
 * tables equal.  Pure logic with an injected clock, so it runs in the
 * browser (window.LudusGlas) and in node tests.
 */

'use strict';

(function (root) {
  const DAY = 86400000;

  // tone: [Slavonic name, Byzantine name, genus, base note].
  const GLASY = {
    1: { ru: 'Глас 1', el: 'Ἦχος α΄', genus: 'diatonic', base: 'Pa' },
    2: { ru: 'Глас 2', el: 'Ἦχος β΄', genus: 'soft chromatic',
      base: 'Di' },
    3: { ru: 'Глас 3', el: 'Ἦχος γ΄', genus: 'enharmonic', base: 'Ga' },
    4: { ru: 'Глас 4', el: 'Ἦχος δ΄', genus: 'diatonic', base: 'Pa' },
    5: { ru: 'Глас 5', el: 'Ἦχος πλ. α΄', genus: 'diatonic',
      base: 'Pa' },
    6: { ru: 'Глас 6', el: 'Ἦχος πλ. β΄', genus: 'hard chromatic',
      base: 'Pa' },
    7: { ru: 'Глас 7', el: 'Ἦχος βαρύς', genus: 'enharmonic',
      base: 'Zo' },
    8: { ru: 'Глас 8', el: 'Ἦχος πλ. δ΄', genus: 'diatonic', base: 'Ni' },
  };

  // Bright Week: day offset from Pascha -> tone.
  const BRIGHT = [1, 2, 3, 4, 5, 6, 8];

  /**
   * The tone of a liturgical day, or null in Holy Week.
   * clock is window.LudusLiturgicalClock (or its node export).
   */
  function glasOf(now, clock) {
    const day = clock.liturgicalDate(now).getTime();
    const year = new Date(day).getUTCFullYear();
    const pascha = clock.paschaCivil(year).getTime();
    const offset = Math.round((day - pascha) / DAY);
    if (offset >= -6 && offset <= -1) {
      return null;
    }
    if (offset >= 0 && offset <= 6) {
      return BRIGHT[offset];
    }
    // Thomas Sunday of this year, or of the last one before Pascha.
    let thomas = pascha + 7 * DAY;
    if (day < thomas) {
      thomas = clock.paschaCivil(year - 1).getTime() + 7 * DAY;
    }
    const weeks = Math.floor(Math.round((day - thomas) / DAY) / 7);
    return (weeks % 8) + 1;
  }

  function describe(now, clock) {
    const glas = glasOf(now, clock);
    return glas ? Object.assign({ glas: glas, cue: 'ison_glas_' + glas },
      GLASY[glas]) : { glas: null, cue: null };
  }

  const api = { GLASY, glasOf, describe };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusGlas = api;
  }
})(typeof window !== 'undefined' ? window : null);
