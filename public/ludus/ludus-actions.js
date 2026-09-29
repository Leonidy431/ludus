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
    practices: {},
  });

  // The rule of prayer: twelve practices, each answering one passion on
  // St John Climacus' Ladder (step numbers) or a named Patericon source.
  // kinds: 'count' adds one per act; 'daily' counts once per calendar
  // day; 'timer' counts only whole minutes actually completed.  The
  // first three keep the legacy keys that the gates read.  None of them
  // ever adds XP or attributes (TABOO 0.35 rule 16); 'secret' practices
  // are not even shown as a number, because a secret good deed that is
  // counted in front of the player feeds vainglory (Mt 6:3-4).
  const PRACTICES = [
    { id: 'prayer_rope', label: 'Prayer rope: one knot', kind: 'count',
      legacy: 'prayerCount', passion: 'all eight', virtue: 'prayer',
      source: 'Ladder, step 28' },
    { id: 'fast', label: "Keep today's fast", kind: 'daily',
      legacy: 'fastDays', passion: 'gluttony', virtue: 'temperance',
      source: 'Ladder, step 14' },
    { id: 'stillness', label: 'Stillness', kind: 'timer', minutes: 1,
      legacy: 'meditationHours', passion: 'vainglory, talkativeness',
      virtue: 'hesychia', source: 'Ladder, steps 11 and 27' },
    { id: 'prostrations', label: 'Prostration', kind: 'count',
      passion: 'pride', virtue: 'humility', source: 'Ladder, step 25' },
    { id: 'vigil', label: 'Night vigil', kind: 'timer', minutes: 10,
      passion: 'despondency', virtue: 'watchfulness',
      source: 'Ladder, steps 13 and 20' },
    { id: 'handiwork', label: 'Handiwork', kind: 'timer', minutes: 5,
      passion: 'despondency', virtue: 'patience',
      source: 'Apophthegmata, Antony the Great 1' },
    { id: 'alms', label: 'Give alms', kind: 'daily',
      passion: 'avarice', virtue: 'mercy', source: 'Ladder, steps 16-17' },
    { id: 'forgive', label: 'Forgive an offence', kind: 'daily',
      passion: 'anger', virtue: 'meekness', source: 'Ladder, steps 8-9' },
    { id: 'thanksgiving', label: 'Glory to God for all things',
      kind: 'daily', passion: 'sadness', virtue: 'joyful mourning',
      source: 'Ladder, step 7; St John Chrysostom' },
    { id: 'guard_thoughts', label: 'Evening watch over thoughts',
      kind: 'daily', passion: 'lust', virtue: 'chastity',
      source: 'Ladder, steps 15 and 26' },
    { id: 'obedience', label: "Fulfil the mentor's obedience",
      kind: 'daily', passion: 'pride (self-will)', virtue: 'obedience',
      source: 'Ladder, step 4' },
    { id: 'secret_deed', label: 'A good deed in secret', kind: 'daily',
      secret: true, passion: 'vainglory', virtue: 'simplicity',
      source: 'Ladder, step 22; Mt 6:3-4' },
  ];

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
    const practices = {};
    const srcPractices = src.practices && typeof src.practices === 'object'
      ? src.practices : {};
    PRACTICES.forEach((pr) => {
      const item = srcPractices[pr.id];
      if (!pr.legacy && item && typeof item === 'object') {
        practices[pr.id] = {
          count: Math.floor(num(item.count)),
          lastDay: typeof item.lastDay === 'string'
            && /^\d{4}-\d{2}-\d{2}$/.test(item.lastDay) ? item.lastDay : null,
        };
      }
    });
    // Meetings with the eight passions, kept by the server with the
    // rule (op passionEnd); the same shape as normalizeRecord() in
    // ludus-passion.js, so the road reads either source.
    const passions = {};
    const srcPa = src.passions && typeof src.passions === 'object'
      ? src.passions : {};
    Object.keys(srcPa).forEach((id) => {
      const item = srcPa[id];
      if (/^[a-z]{1,20}$/.test(id) && item && typeof item === 'object') {
        passions[id] = {
          meetings: Math.floor(num(item.meetings)),
          overcome: Math.floor(num(item.overcome)),
          captive: Math.floor(num(item.captive)),
          discerned: item.discerned === true,
        };
      }
    });
    return {
      practices,
      passions,
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

  // One act of a practice.  opts.day (YYYY-MM-DD) is required for daily
  // practices and opts.minutes (whole minutes completed) for timers; the
  // caller supplies both, so no clock is hidden in here.
  function doPractice(actions, id, opts) {
    const pr = PRACTICES.find((p) => p.id === id);
    const o = opts || {};
    if (!pr) {
      return normalize(actions);
    }
    if (pr.legacy === 'prayerCount') {
      return prayKnot(actions);
    }
    if (pr.legacy === 'fastDays') {
      return keepFast(actions, o.day);
    }
    if (pr.legacy === 'meditationHours') {
      return addStillness(actions, o.minutes);
    }
    const next = normalize(actions);
    const item = next.practices[id] || { count: 0, lastDay: null };
    if (pr.kind === 'count') {
      item.count += 1;
    } else if (pr.kind === 'daily') {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(o.day))
          || item.lastDay === o.day) {
        return next;
      }
      item.count += 1;
      item.lastDay = o.day;
    } else if (pr.kind === 'timer') {
      // Only a completed session of the practice's length counts.
      if (Math.floor(num(o.minutes)) < pr.minutes) {
        return next;
      }
      item.count += pr.minutes;
    }
    next.practices[id] = item;
    return next;
  }

  // What the panel may show: a number, or nothing for secret practices.
  function practiceTally(actions, id) {
    const pr = PRACTICES.find((p) => p.id === id);
    const a = normalize(actions);
    if (!pr) {
      return null;
    }
    if (pr.secret) {
      return { shown: false, text: 'known to God' };
    }
    let value;
    if (pr.legacy === 'meditationHours') {
      value = Math.floor(a.meditationHours * 60 + 1e-6);
    } else if (pr.legacy) {
      value = a[pr.legacy];
    } else {
      value = (a.practices[id] || { count: 0 }).count;
    }
    let unit = '';
    if (pr.kind === 'timer') {
      unit = ' min';
    } else if (pr.kind === 'daily') {
      unit = value === 1 ? ' day' : ' days';
    }
    return { shown: true, value, text: `${value}${unit}` };
  }

  function keptToday(actions, id, day) {
    const pr = PRACTICES.find((p) => p.id === id);
    const a = normalize(actions);
    if (!pr || pr.kind !== 'daily') {
      return false;
    }
    if (pr.legacy === 'fastDays') {
      return a.lastFastDay === day;
    }
    return (a.practices[id] || {}).lastDay === day;
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
    PRACTICES,
    doPractice,
    practiceTally,
    keptToday,
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
