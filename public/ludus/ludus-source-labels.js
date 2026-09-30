/**
 * The Russian form of a source, for the panels of the web game.
 *
 * The campaign's data cites its sources in English, because it mirrors
 * the webtypicon2 game source and must not change.  The player reads
 * the Russian form: data/source-labels-ru.json maps each source string
 * to its rendering by Synodal and church conventions
 * ("Deuteronomy 22:1-3" -> "Втор. 22:1–3").  The headset reads the
 * same table through the same rule (godot/scripts/source_labels.gd).
 *
 * A source missing from the table is shown as it is.  Nothing is
 * logged and the player never sees an error: a quiet original is
 * better than a broken panel.
 *
 * Constitution: FORM (the source a teaching stands on) -> ACTION (the
 * panel names it in the reader's own tongue) -> GOAL (the player can
 * open the book and read the teaching for himself).
 */

'use strict';

(function (root) {
  const URL = '/ludus/data/source-labels-ru.json';

  // The labels of a table: the whole document or its "labels" map.
  function labelsOf(table) {
    if (!table || typeof table !== 'object') {
      return {};
    }
    return table.labels && typeof table.labels === 'object'
      ? table.labels : table;
  }

  // The Russian label of a source, or the source itself when the table
  // has no label for it.
  function labelRu(table, src) {
    const key = String(src === null || src === undefined ? '' : src);
    const labels = labelsOf(table);
    const entry = Object.prototype.hasOwnProperty.call(labels, key)
      ? labels[key] : null;
    return entry && typeof entry.ru === 'string' && entry.ru
      ? entry.ru : key;
  }

  // Fetch the table once.  A failed fetch gives null, so every source
  // falls back to its original string.
  let loading = null;
  function load(fetchImpl) {
    const f = fetchImpl || (root && root.fetch && root.fetch.bind(root));
    if (!f) {
      return Promise.resolve(null);
    }
    if (!loading) {
      loading = Promise.resolve()
        .then(() => f(URL))
        .then((res) => (res && res.ok ? res.json() : null))
        .catch(() => null);
    }
    return loading;
  }

  const api = { URL, labelRu, load };

  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusSourceLabels = api;
  }
})(typeof window !== 'undefined' ? window : null);
