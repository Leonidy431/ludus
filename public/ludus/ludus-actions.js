/**
 * Ludus ACTION layer: ritual counters and the three-part gate check.
 *
 * CLAUDE.md, constitution section 4 and TABOO 0.35 rule 14: a knowledge
 * gate opens only when three things hold at once:
 *   1. the FORM threshold (Wisdom 4, 6, 8, 10, 12, 14);
 *   2. conversations with the named mentors;
 *   3. a ritual counter from actions{} (prayer, fasting, stillness).
 * A Wisdom-only check was the bug this module replaces (DEF-009).
 *
 * Gates 4-6 are "a gift, not a wage": when the conditions are met the
 * gate still waits for an act of humility, a bow with the words "not
 * to me", because theosis is synergy (St Gregory Palamas), not a prize
 * for points.  Cunning opens no gate.
 *
 * The counters are only shown to the player.  Prayer and stillness
 * never add XP, damage or multipliers (TABOO 0.35 rule 16): a gate
 * asks whether the player prayed, not how much the prayer "earned".
 *
 * Pure logic, no DOM: the same file runs in the browser
 * (window.LudusActions) and in node tests (module.exports).
 */

'use strict';

(function (root) {
  // The keys match the Firestore shape in CLAUDE.md ("Firestore as
  // Heaven"): players/{id}.actions.{prayerCount, fastDays,
  // meditationHours}.  Meetings and accepted gifts are kept beside them.
  const EMPTY = Object.freeze({
    prayerCount: 0,
    fastDays: 0,
    meditationHours: 0,
    lastFastDay: null,
    met: {},
    gifts: {},
  });

  // Each gate names its mentors and its rite.  The rites climb from
  // the Jesus Prayer on the prayer rope, through fasting, to stillness
  // (hesychia), following the ladder the gate names describe.
  const GATES = [
    { id: 'foundational', label: 'Foundational', wisdom: 4,
      mentors: ['theodora'],
      rite: { key: 'prayerCount', min: 10, label: 'knots of the prayer rope' } },
    { id: 'liturgical', label: 'Liturgical', wisdom: 6,
      mentors: ['theodora', 'elder_sergius'],
      rite: { key: 'prayerCount', min: 33, label: 'knots of the prayer rope' } },
    { id: 'ascetic', label: 'Ascetic', wisdom: 8,
      mentors: ['abba_john'],
      rite: { key: 'fastDays', min: 1, label: 'day of fasting' } },
    { id: 'contemplative', label: 'Contemplative', wisdom: 10,
      mentors: ['elder_sergius'], gift: true,
      rite: { key: 'meditationHours', min: 10 / 60,
        label: 'minutes of stillness', perMinute: true } },
    { id: 'mystical', label: 'Mystical', wisdom: 12,
      mentors: ['sister_catherine'], gift: true,
      rite: { key: 'meditationHours', min: 30 / 60,
        label: 'minutes of stillness', perMinute: true } },
    { id: 'apophatic', label: 'Apophatic', wisdom: 14,
      mentors: ['elder_sergius', 'theodora', 'abba_john',
        'sister_catherine'],
      gift: true,
      rite: { key: 'meditationHours', min: 1,
        label: 'minutes of stillness', perMinute: true } },
  ];

  function num(value) {
    const n = Number(value);
    return Number.isFinite(n) && n > 0 ? n : 0;
  }

  // Normalise anything read from storage or Firestore; unknown keys
  // are dropped so a tampered record cannot smuggle in new counters.
  function normalize(raw) {
    const src = raw && typeof raw === 'object' ? raw : {};
    const met = {};
    const gifts = {};
    Object.keys(src.met || {}).forEach((id) => {
      if (/^[a-z_]{1,40}$/.test(id)) {
        met[id] = Math.floor(num(src.met[id]));
      }
    });
    GATES.forEach((gate) => {
      if (src.gifts && src.gifts[gate.id] === true) {
        gifts[gate.id] = true;
      }
    });
    return {
      prayerCount: Math.floor(num(src.prayerCount)),
      fastDays: Math.floor(num(src.fastDays)),
      meditationHours: num(src.meditationHours),
      lastFastDay: typeof src.lastFastDay === 'string'
        && /^\d{4}-\d{2}-\d{2}$/.test(src.lastFastDay)
        ? src.lastFastDay : null,
      met,
      gifts,
    };
  }

  // One knot of the prayer rope.  The count is shown, never rewarded.
  function prayKnot(actions) {
    const next = normalize(actions);
    next.prayerCount += 1;
    return next;
  }

  // A fast is kept once per calendar day; the caller passes the date
  // (YYYY-MM-DD) so tests stay deterministic and no clock is hidden.
  function keepFast(actions, isoDay) {
    const next = normalize(actions);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(isoDay))) {
      return next;
    }
    if (next.lastFastDay !== isoDay) {
      next.fastDays += 1;
      next.lastFastDay = isoDay;
    }
    return next;
  }

  // Stillness is counted only for whole minutes actually completed.
  function addStillness(actions, minutes) {
    const next = normalize(actions);
    const whole = Math.floor(num(minutes));
    next.meditationHours = +(next.meditationHours + whole / 60).toFixed(4);
    return next;
  }

  function recordMeeting(actions, npcId) {
    const next = normalize(actions);
    if (/^[a-z_]{1,40}$/.test(String(npcId))) {
      next.met[npcId] = (next.met[npcId] || 0) + 1;
    }
    return next;
  }

  // The bow for gates 4-6.  It is accepted only when every other
  // condition already holds, so it cannot be used to skip a step.
  function acceptGift(actions, form, gateId) {
    const next = normalize(actions);
    const gate = GATES.find((g) => g.id === gateId);
    if (!gate || !gate.gift) {
      return next;
    }
    const check = evaluate(gate, form, next);
    if (check.readyForGift) {
      next.gifts[gate.id] = true;
    }
    return next;
  }

  function riteProgress(gate, actions) {
    const have = num(actions[gate.rite.key]);
    const scale = gate.rite.perMinute ? 60 : 1;
    return {
      have: Math.floor(have * scale + 1e-6),
      need: Math.round(gate.rite.min * scale),
      label: gate.rite.label,
      done: have + 1e-9 >= gate.rite.min,
    };
  }

  // The three-part check.  Returns what is still missing, in the order
  // the player should see it: FORM, then conversations, then the rite,
  // then (gates 4-6) the gift.
  function evaluate(gate, form, rawActions) {
    const actions = normalize(rawActions);
    const wisdom = num(form && form.wisdom);
    const missing = [];
    if (wisdom < gate.wisdom) {
      missing.push({ kind: 'form',
        text: `Wisdom ${gate.wisdom} (now ${wisdom})` });
    }
    const unmet = gate.mentors.filter((id) => !actions.met[id]);
    if (unmet.length) {
      missing.push({ kind: 'dialogue', mentors: unmet,
        text: `Speak with ${unmet.join(', ')}` });
    }
    const rite = riteProgress(gate, actions);
    if (!rite.done) {
      missing.push({ kind: 'rite',
        text: `${rite.have}/${rite.need} ${rite.label}` });
    }
    const readyForGift = gate.gift === true && missing.length === 0;
    if (gate.gift && !actions.gifts[gate.id]) {
      missing.push({ kind: 'gift',
        text: 'Received as a gift, not earned: bow and say "not to me"' });
    }
    return { gate, open: missing.length === 0, missing, rite,
      readyForGift };
  }

  // Gates are a ladder: a higher gate never opens before a lower one.
  function evaluateLadder(form, actions) {
    let blocked = false;
    return GATES.map((gate) => {
      const check = evaluate(gate, form, actions);
      if (blocked && check.open) {
        check.open = false;
        check.missing.push({ kind: 'ladder',
          text: 'Pass the previous gate first' });
      }
      if (!check.open) {
        blocked = true;
      }
      return check;
    });
  }

  function currentGate(form, actions) {
    let current = null;
    evaluateLadder(form, actions).forEach((check) => {
      if (check.open) {
        current = check.gate;
      }
    });
    return current;
  }

  const api = {
    GATES,
    EMPTY,
    normalize,
    prayKnot,
    keepFast,
    addStillness,
    recordMeeting,
    acceptGift,
    evaluate,
    evaluateLadder,
    currentGate,
  };

  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusActions = api;
  }
})(typeof window !== 'undefined' ? window : null);
