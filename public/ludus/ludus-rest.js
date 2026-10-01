/**
 * Ludus: a gentle word to rest (HLD F5, improvement 99; CLAUDE.md TABOO
 * 0.35 rule 21: no dark patterns).
 *
 * After 45 minutes of play that the player actually saw (a hidden tab
 * does not count), one quiet line suggests a pause; if the player plays
 * on, the next comes 30 minutes later.  Late at night the first comes
 * sooner.  The line speaks in the game's image language, not in church
 * words (TABOO 0.39): the fisher hangs up the net, the oar rests.
 *
 * What it never does: count, score, reward or punish rest; store
 * anything (the timer lives in memory and starts again with the page);
 * block play or nag with sound.  It is a word, not a lock.
 * Pure logic in next() and pick(); the browser part only shows the line.
 */

'use strict';

(function (root) {
  const FIRST_MIN = 45;
  const AGAIN_MIN = 30;
  const NIGHT_FIRST_MIN = 25;
  const NIGHT_FROM = 23;
  const NIGHT_TO = 5;

  // Deterministic order, no randomness (TABOO 0.35 rule 15).
  const LINES = [
    { en: 'The fisher hangs up his net before it tears. Rest a while.',
      ru: 'Рыбак вешает сеть сушиться, пока она не порвалась. '
        + 'Отдохни немного.' },
    { en: 'Even the oar rests between strokes. Step away from the screen.',
      ru: 'И весло отдыхает между гребками. Отойди от экрана.' },
    { en: 'Clay left to dry holds its shape. Let the day settle.',
      ru: 'Глина, оставленная сохнуть, держит форму. Дай дню улечься.' },
  ];

  function isNight(date) {
    const h = date.getHours();
    return h >= NIGHT_FROM || h < NIGHT_TO;
  }

  /** Minutes of seen play before the next word, given how many were said. */
  function next(said, date) {
    if (said > 0) {
      return AGAIN_MIN;
    }
    return isNight(date) ? NIGHT_FIRST_MIN : FIRST_MIN;
  }

  function pick(said) {
    return LINES[said % LINES.length];
  }

  const api = { next, pick, LINES, FIRST_MIN, AGAIN_MIN, NIGHT_FIRST_MIN };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (!root || !root.document) {
    return;
  }
  root.LudusRest = api;

  // ── Browser: count only seen minutes and show one line at a time. ──
  let seenMs = 0;
  let lastTick = Date.now();
  let said = 0;
  let dueMs = next(0, new Date()) * 60000;

  function show() {
    if (root.document.querySelector('.ludus-rest')) {
      return;
    }
    const line = pick(said);
    const box = root.document.createElement('div');
    box.className = 'ludus-rest';
    box.setAttribute('role', 'status');
    const ru = /^ru/i.test(root.navigator.language || '');
    const text = root.document.createElement('span');
    text.textContent = ru ? line.ru : line.en;
    const ok = root.document.createElement('button');
    ok.type = 'button';
    ok.className = 'ludus-link-btn';
    ok.textContent = ru ? 'Хорошо' : 'All right';
    ok.addEventListener('click', () => box.remove());
    box.append(text, ok);
    root.document.body.append(box);
  }

  function tick() {
    const now = Date.now();
    if (root.document.visibilityState === 'visible') {
      seenMs += now - lastTick;
    }
    lastTick = now;
    if (seenMs >= dueMs) {
      show();
      said += 1;
      dueMs = seenMs + next(said, new Date()) * 60000;
    }
  }

  root.setInterval(tick, 15000);
  root.document.addEventListener('visibilitychange', () => {
    lastTick = Date.now();
  });
  // Tests and the audit harness can move the clock without waiting.
  api._advance = function (minutes) {
    seenMs += minutes * 60000;
    tick();
  };
})(typeof window !== 'undefined' ? window : null);
