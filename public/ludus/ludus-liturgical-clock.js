/**
 * Ludus liturgical clock: which day it is in the Church, and which bell
 * orders the Typikon allows on it (HLD F1, DEF-010/019; CLAUDE.md TABOO
 * 0.2 item 5, TABOO 0.35 rule 9).
 *
 * The same peal is right or wrong depending on the date: a festal
 * трезвон on Great Friday is a falsehood in sound.  So every bell cue is
 * asked here first.  Rules implemented:
 *   - the liturgical day begins at Vespers (18:00 local), so an evening
 *     already belongs to the next day;
 *   - Pascha by the Julian computus (the Orthodox Paschalion), converted
 *     to the civil (Gregorian) date: +13 days for 1900-2099;
 *   - the orders each period allows are PERIOD_ORDERS, the
 *     "periodOrders" of the one bell table public/ludus/data/
 *     bell-rules.json (godot/data/bell-rules.json is the same file),
 *     where each list carries its source in the Typikon or the bell
 *     book (docs/HLD_BELL_RULES_TYPIKON_2026-09-30.md).  The test
 *     compares the two, so the web and the headset cannot drift:
 *     Great Friday: благовест and звон в двои (Typikon: «звон в двои,
 *     един долгий»; «клеплет в великое»), no трезвон; Great Saturday:
 *     благовест only; weekdays of Great Lent and Holy Week: благовест
 *     and двои; Pascha and Bright Week: благовест and трезвон; a
 *     Sunday or feast in Lent keeps its трезвон; other days all five.
 * Astronomy is used only for the Paschalion (TABOO 0.35 rule 23).
 * Pure logic with an injected date, so tests never depend on the clock;
 * the browser global is window.LudusLiturgicalClock.
 */

'use strict';

(function (root) {
  const DAY = 86400000;
  const VESPERS_HOUR = 18;

  // Julian computus (Meeus): Pascha as a Julian calendar date, then
  // shifted to the civil calendar.  Valid for 1900-2099 (+13 days).
  function paschaCivil(year) {
    const a = year % 4;
    const b = year % 7;
    const c = year % 19;
    const d = (19 * c + 15) % 30;
    const e = (2 * a + 4 * b - d + 34) % 7;
    const month = Math.floor((d + e + 114) / 31);
    const day = ((d + e + 114) % 31) + 1;
    const julian = Date.UTC(year, month - 1, day);
    return new Date(julian + 13 * DAY);
  }

  // Fixed great feasts on the civil calendar (Julian date + 13 days).
  const FIXED_FEASTS = {
    '01-07': 'Nativity of Christ',
    '01-19': 'Theophany',
    '02-15': 'Meeting of the Lord',
    '04-07': 'Annunciation',
    '08-19': 'Transfiguration',
    '08-28': 'Dormition',
    '09-21': 'Nativity of the Theotokos',
    '09-27': 'Exaltation of the Cross',
    '12-04': 'Entry of the Theotokos',
  };

  function utcDay(y, m, d) {
    return Date.UTC(y, m, d);
  }

  // The liturgical date for a local moment: after Vespers the next day.
  function liturgicalDate(now) {
    const local = new Date(now);
    let t = utcDay(local.getFullYear(), local.getMonth(), local.getDate());
    if (local.getHours() >= VESPERS_HOUR) {
      t += DAY;
    }
    return new Date(t);
  }

  function describe(now) {
    const day = liturgicalDate(now);
    const y = day.getUTCFullYear();
    let pascha = paschaCivil(y).getTime();
    const t = day.getTime();
    const offset = Math.round((t - pascha) / DAY);
    const md = `${String(day.getUTCMonth() + 1).padStart(2, '0')}-${
      String(day.getUTCDate()).padStart(2, '0')}`;
    const weekday = day.getUTCDay();
    let period = 'ordinary';
    let feast = FIXED_FEASTS[md] || null;
    if (offset === -2) {
      period = 'great-friday';
    } else if (offset === -1) {
      period = 'great-saturday';
    } else if (offset >= -6 && offset <= -3) {
      period = 'holy-week';
    } else if (offset === -7) {
      feast = 'Entry into Jerusalem';
    } else if (offset === 0) {
      period = 'pascha';
      feast = 'Pascha';
    } else if (offset >= 1 && offset <= 6) {
      period = 'bright-week';
    } else if (offset >= -48 && offset <= -8) {
      period = 'great-lent';
    } else if (offset === 39) {
      feast = 'Ascension';
    } else if (offset === 49) {
      feast = 'Pentecost';
    }
    const great = Boolean(feast) || weekday === 0;
    const rank = period === 'pascha' ? 'pascha' : (great ? 'great' : 'daily');
    return { date: day.toISOString().slice(0, 10), weekday, offset,
      period, feast, rank, pascha: new Date(pascha).toISOString()
        .slice(0, 10) };
  }

  // Bell orders the sources name for each period: "periodOrders" of
  // bell-rules.json, copied here so the module stays synchronous and
  // pure (tests/ludus-liturgical-clock.test.js checks the copy).
  const PERIOD_ORDERS = {
    ordinary: ['благовест', 'трезвон', 'перезвон', 'перебор', 'двои'],
    'great-lent/daily': ['благовест', 'двои'],
    'great-lent/great': ['благовест', 'трезвон', 'двои'],
    'holy-week': ['благовест', 'двои'],
    'great-friday': ['благовест', 'двои'],
    'great-saturday': ['благовест'],
    pascha: ['благовест', 'трезвон'],
    'bright-week': ['благовест', 'трезвон'],
  };

  // Bell orders the Typikon allows on this day.
  function allowedOrders(info) {
    let key = info.period;
    if (key === 'great-lent') {
      // A Lenten Sunday or great feast keeps its festal ringing; a
      // weekday has the call and the restrained ringing in two bells.
      key += info.rank === 'great' ? '/great' : '/daily';
    }
    return (PERIOD_ORDERS[key] || PERIOD_ORDERS.ordinary).slice();
  }

  function mayRing(order, now) {
    return allowedOrders(describe(now)).includes(order);
  }

  const api = { paschaCivil, liturgicalDate, describe, allowedOrders,
    mayRing, VESPERS_HOUR, PERIOD_ORDERS };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusLiturgicalClock = api;
  }
})(typeof window !== 'undefined' ? window : null);
