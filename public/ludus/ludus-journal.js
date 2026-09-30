/**
 * Ludus: the player's journal as a Markdown page they keep (HLD F5,
 * improvement 96: journal export; logs are kept, TABOO 0.25 item 5).
 *
 * The page is the player's own record of the way: the seven attributes
 * of FORM, the rule of prayer as counted by the game, the steps of the
 * ladder that stand open and the passions met on the road.  It is built
 * on the device and handed to the player as a file; nothing is sent.
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

  function cap(word) {
    return word.charAt(0).toUpperCase() + word.slice(1);
  }

  /**
   * state: { form, actions, passions, passionData, now }
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

    lines.push('', '---', '',
      'One good deed is kept out of this page on purpose: it is known to '
      + 'God. This page counts steps on a road; it does not measure a '
      + 'soul.', '');
    return lines.join('\n');
  }

  const api = { toMarkdown };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusJournal = api;
  }
})(typeof window !== 'undefined' ? window : null);
