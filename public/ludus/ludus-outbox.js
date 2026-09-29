/**
 * Ludus: the outbox — acts of the rule kept while the network is away
 * (HLD F4, improvement 83: saves and offline sync).
 *
 * When a signed-in player keeps a practice without a connection, the
 * act is not lost and not faked: it waits here and is sent, in order,
 * when the network returns.  The server stays the judge: it checks
 * each act against its own clock (a timer's length, "today" for a
 * daily practice), so an act that has grown too old is refused there
 * and dropped here with a plain note, never replayed forever.
 *
 * Only rule operations go through the outbox.  Nothing from the
 * confession page ever does: that module has no link to this one
 * (TABOO 0.26).  The queue holds operation names and ids only, no
 * text the player wrote.
 *
 * Pure logic over an injected store (localStorage in the browser, a
 * Map in tests); window.LudusOutbox in the browser.
 */

'use strict';

(function (root) {
  const KEY = 'ludus.outbox';
  const MAX_ITEMS = 200;
  // The server accepts a daily act within 1.5 days of "today"; older
  // ones would only bounce, so they are dropped before sending.
  const MAX_AGE_MS = 1.5 * 86400000;
  const ALLOWED = ['practice', 'prayKnot', 'keepFast', 'addStillness',
    'recordMeeting', 'passionEnd'];

  function read(store) {
    try {
      const raw = JSON.parse(store.getItem(KEY) || '[]');
      return Array.isArray(raw) ? raw : [];
    } catch (error) {
      return [];
    }
  }

  function write(store, list) {
    store.setItem(KEY, JSON.stringify(list));
  }

  /** Keep one operation; returns false for anything not allowed. */
  function enqueue(store, op, now) {
    if (!op || !ALLOWED.includes(op.op)) {
      return false;
    }
    const list = read(store);
    list.push({ op, at: now });
    // A full outbox keeps the newest acts; the oldest would be refused
    // by the server anyway.
    write(store, list.slice(-MAX_ITEMS));
    return true;
  }

  /**
   * Send every waiting operation in order with send(op) -> Promise of
   * {ok, status}.  Stops at the first network failure (the rest stay),
   * drops what the server refuses (4xx) or what is too old.
   * Resolves to {sent, dropped, left}.
   */
  async function flush(store, send, now) {
    const list = read(store);
    let sent = 0;
    let dropped = 0;
    let i = 0;
    for (; i < list.length; i++) {
      const item = list[i];
      if (now - item.at > MAX_AGE_MS) {
        dropped += 1;
        continue;
      }
      let res;
      try {
        res = await send(item.op);
      } catch (error) {
        break;
      }
      if (res && res.ok) {
        sent += 1;
      } else if (res && res.status >= 400 && res.status < 500) {
        dropped += 1;
      } else {
        break;
      }
    }
    const left = list.slice(i);
    write(store, left);
    return { sent, dropped, left: left.length };
  }

  function size(store) {
    return read(store).length;
  }

  const api = { enqueue, flush, size, KEY, MAX_AGE_MS, ALLOWED };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusOutbox = api;
  }
})(typeof window !== 'undefined' ? window : null);
