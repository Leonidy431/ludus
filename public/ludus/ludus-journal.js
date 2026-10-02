/**
 * Ludus: the player's journal as a Markdown page they keep (HLD F5,
 * improvement 96: journal export; logs are kept, TABOO 0.25 item 5).
 *
 * The page is the player's own record of the way: the seven attributes
 * of FORM, the rule of prayer as counted by the game, the steps of the
 * ladder that stand open, the passions met on the road and the acts done
 * at the hearts of places ("ludus.deeds", kept as the headset's save keeps
 * them under "deeds": how many times and the last day, nothing more).  It
 * is built on the device and handed to the player as a file; nothing is
 * sent.
 *
 * What it leaves out, on purpose:
 *   - the secret good deed: its count is "known to God" here too
 *     (Mt 6:3-4), exactly as on the rule panel;
 *   - the confession page: it is never stored, so it cannot be exported
 *     (TABOO 0.26);
 *   - any word that turns the record into a measure of holiness: the
 *     page says so in its closing line (TABOO 0.39).
 * Pure: toMarkdown() takes the state and returns text; window.LudusJournal.
 */

'use strict';

(function (root) {
  const ATTRS = ['wisdom', 'faith', 'dexterity', 'constitution',
    'charisma', 'cunning', 'erudition'];

  const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

  function cap(word) {
    return word.charAt(0).toUpperCase() + word.slice(1);
  }

  /**
   * The acts done at the hearts of places, in the known shape only and
   * in the order of their ids: [{title, count, lastDay}].  record is the
   * saved {id: {count, lastDay}}; places maps an act id to the title of
   * its place, and only these ids are known (as PlaceDeeds.normalize
   * keeps only its own).  An act never done is not listed.
   */
  function deedsDone(record, places) {
    const out = [];
    if (!record || typeof record !== 'object' || Array.isArray(record)
        || !places) {
      return out;
    }
    Object.keys(record).sort().forEach((id) => {
      const r = record[id];
      if (!Object.prototype.hasOwnProperty.call(places, id) || !r
          || typeof r !== 'object' || Array.isArray(r)) {
        return;
      }
      const c = r.count;
      const n = typeof c === 'number' && Number.isFinite(c)
        ? Math.max(0, Math.trunc(c)) : 0;
      const d = r.lastDay;
      if (n > 0) {
        out.push({ title: String(places[id]), count: n,
          lastDay: typeof d === 'string' && DAY_RE.test(d) ? d : null });
      }
    });
    return out;
  }

  /**
   * state: { form, actions, passions, passionData, now, deeds,
   *   deedPlaces }: deeds is the saved record of the place acts and
   *   deedPlaces maps an act id to the title of its place.
   * actionsApi: window.LudusActions (or its node export).
   */
  function toMarkdown(state, actionsApi) {
    const now = state.now || new Date();
    const form = state.form || {};
    const actions = actionsApi.normalize(state.actions || {});
    const lines = [
      '# The way: a page from my journal',
      '',
      `Written on ${now.toISOString().slice(0, 10)}.`,
      '',
      '## Form',
      '',
    ];
    ATTRS.forEach((a) => {
      lines.push(`- ${cap(a)}: ${Number(form[a]) || 0}`);
    });

    lines.push('', '## Rule of prayer', '');
    actionsApi.PRACTICES.forEach((pr) => {
      const tally = actionsApi.practiceTally(actions, pr.id);
      lines.push(`- ${pr.label} — ${tally ? tally.text : "0"}`);
    });

    lines.push('', '## Steps of the ladder', '');
    const ladder = actionsApi.evaluateLadder(form, actions);
    const open = actionsApi.GATES.filter((g, i) => ladder[i].open);
    if (open.length === 0) {
      lines.push('- None yet: the first step is still ahead.');
    } else {
      open.forEach((g) => lines.push(`- ${g.label}`));
    }

    lines.push('', '## On the road', '');
    const data = state.passionData;
    const rec = state.passions || {};
    const met = data ? data.order.filter((id) => rec[id]) : [];
    if (met.length === 0) {
      lines.push('- No thought met on the road yet.');
    } else {
      met.forEach((id) => {
        const p = data.passions.find((x) => x.id === id) || { name: id };
        const r = rec[id];
        const how = r.overcome > 0
          ? `passed; answered by ${p.virtue || 'its virtue'}`
          : 'met, and it will come back';
        const sign = r.discerned ? ', named at its first sign' : '';
        lines.push(`- ${p.name || id}: ${how}${sign} `
          + `(${r.meetings} meeting${r.meetings === 1 ? '' : 's'}).`);
      });
    }

    lines.push('', '## Deeds of places', '');
    const deeds = deedsDone(state.deeds, state.deedPlaces);
    if (deeds.length === 0) {
      lines.push('- No act at the heart of a place done yet.');
    }
    deeds.forEach((d) => {
      const last = d.lastDay ? `, last on ${d.lastDay}` : '';
      lines.push(`- ${d.title}: done ${d.count} `
        + `time${d.count === 1 ? '' : 's'}${last}.`);
    });

    lines.push('', '---', '',
      'One good deed is kept out of this page on purpose: it is known to '
      + 'God. This page counts steps on a road; it does not measure a '
      + 'soul.', '');
    return lines.join('\n');
  }

  const api = { toMarkdown, deedsDone };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusJournal = api;
  }
})(typeof window !== 'undefined' ? window : null);
