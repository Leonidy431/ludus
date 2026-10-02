/**
 * Ludus: the small acts at the hearts of 26 places, for the web build
 * (docs/HLD_DEEDS_WEB_PARITY_2026-10-02.md; blind spot 13 of
 * docs/BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01.md).
 *
 * The acts are written once, in the headset's GDScript
 * (godot/scripts/deeds/*.gd).  Their walk, every state reachable by the
 * buttons and by waiting still, is data/place-deeds.json, written by
 * godot/tests/export_deeds_graph.gd; a Godot test fails when the code
 * and the file part.  This module only plays that graph, so the page
 * offers the same steps with the same words and the same answers as
 * the headset, and has no act logic of its own to drift.
 *
 * Like the headset, an act never changes FORM and gives no point: it is
 * done or not.  The record keeps how many times and the last day, once
 * a day, in the same shape as PlaceDeeds.record.  A wrong step answers
 * in the place's own craft and lets the player try again.  Nothing is
 * random (Constitution: no chance in outcomes).
 *
 * Constitution: ФОРМА (one act, written once, in the place's own craft)
 * → ДЕЙСТВИЕ (the same steps and words in the headset and on the page)
 * → ЦЕЛЬ (the lesson of the place is the same wherever it is learned).
 */

'use strict';

(function (root) {
  const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

  /** The text of index i in the graph's string table. */
  function text(graph, i) {
    const s = graph.strings[i];
    return typeof s === 'string' ? s : '';
  }

  function node(graph, st) {
    const act = graph.acts[st.act];
    return act ? act.nodes[st.node] : undefined;
  }

  /** The act ids in the graph, sorted. */
  function ids(graph) {
    return Object.keys(graph.acts).sort();
  }

  /**
   * The place of an act as the heart's panel shows it above the steps:
   * {id, title, heart, teaching}.
   */
  function place(graph, id) {
    const p = graph.acts[id] && graph.acts[id].place;
    return {
      id: p ? String(p.id) : '',
      title: p ? String(p.title) : '',
      heart: p ? String(p.heart) : '',
      teaching: p ? String(p.teaching) : '',
    };
  }

  /** The start of an act: its node 0. */
  function start(graph, id) {
    if (!graph.acts[id]) {
      throw new Error('unknown act: ' + id);
    }
    return { act: id, node: 0 };
  }

  /**
   * What the panel shows at a state: the body lines, the answer to the
   * last step, whether the act is closed, the buttons, and how long to
   * stand still when the act asks to wait.
   */
  function view(graph, st) {
    const n = node(graph, st);
    return {
      lines: n.lines.map((i) => text(graph, i)),
      reply: text(graph, n.reply),
      done: n.done,
      options: n.options.map((o) => ({
        id: o.id,
        text: text(graph, o.text),
        disabled: o.disabled,
        reason: text(graph, o.reason),
      })),
      waitSeconds: n.wait ? n.wait.seconds : 0,
    };
  }

  /**
   * The state after button c.  An unknown or closed button, or a closed
   * act, leaves the state as it is.
   */
  function choose(graph, st, c) {
    const n = node(graph, st);
    if (!n || n.done || !Object.prototype.hasOwnProperty.call(n.next, c)) {
      return st;
    }
    return { act: st.act, node: n.next[c] };
  }

  /** The state after standing still as long as the act asks. */
  function wait(graph, st) {
    const n = node(graph, st);
    if (!n || n.done || !n.wait) {
      return st;
    }
    return { act: st.act, node: n.wait.next };
  }

  /** The record in its known shape only, as PlaceDeeds.normalize. */
  function normalize(raw, graph) {
    const out = {};
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
      return out;
    }
    Object.keys(raw).forEach((id) => {
      const r = raw[id];
      if (!graph.acts[id] || !r || typeof r !== 'object'
          || Array.isArray(r)) {
        return;
      }
      const c = r.count;
      const d = r.lastDay;
      out[id] = {
        count: typeof c === 'number' && Number.isFinite(c)
          ? Math.max(0, Math.trunc(c)) : 0,
        lastDay: typeof d === 'string' && DAY_RE.test(d) ? d : null,
      };
    });
    return out;
  }

  /** The record after the act is done on day: once a day counts. */
  function record(rec, graph, id, day) {
    const out = normalize(rec, graph);
    if (out[id] && out[id].lastDay === day) {
      return out;
    }
    const n = out[id] ? out[id].count : 0;
    out[id] = { count: n + 1, lastDay: day };
    return out;
  }

  const api = { ids, place, start, view, choose, wait, normalize, record };
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusPlaceDeeds = api;
  }
})(typeof window !== 'undefined' ? window : null);
