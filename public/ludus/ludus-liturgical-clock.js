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
 *   - Great Friday and Great Saturday: no трезвон and no перезвон; a
 *     slow перебор (mourning) is allowed for the burial rite;
 *   - weekdays of Great Lent: благовест only (the Lenten call), no
 *     трезвон;
 *   - Bright Week: трезвон all day, it is the ringing of joy;
 *   - Sundays and the twelve great feasts are ranked "great" and allow
 *     the full order; other days allow благовест and трезвон for the
 *     services.
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

  // Bell orders the Typikon allows on this day.
  function allowedOrders(info) {
    switch (info.period) {
      case 'great-friday':
      case 'great-saturday':
        return ['благовест', 'перебор'];
      case 'holy-week':
        return ['благовест'];
      case 'great-lent':
        // A Lenten Sunday or great feast keeps its festal ringing; a
        // weekday has the call and the restrained ringing in two bells.
        return info.rank === 'great' ? ['благовест', 'трезвон', 'двои']
          : ['благовест', 'двои'];
      case 'pascha':
      case 'bright-week':
        return ['благовест', 'трезвон', 'перезвон'];
      default:
        return ['благовест', 'трезвон', 'перезвон', 'перебор', 'двои'];
    }
  }

  function mayRing(order, now) {
    return allowedOrders(describe(now)).includes(order);
  }

  const api = { paschaCivil, liturgicalDate, describe, allowedOrders,
    mayRing, VESPERS_HOUR };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusLiturgicalClock = api;
  }
})(typeof window !== 'undefined' ? window : null);
