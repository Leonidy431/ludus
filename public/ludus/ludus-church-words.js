/**
 * Ludus: the church-word stop-list matcher for the web build and the JS
 * tests (TABOO 0.39 item 3, 0.4 item 7: no church word on a button, a
 * label or a narrator's line).
 *
 * The words live once, in godot/data/church-words.json; this page reads
 * its byte-identical copy data/church-words.json (CI compares the two
 * with cmp).  The matching is the headset's LocationsCore.church_word
 * and the generator's church_words.py, line for line: lower case, ё read
 * as е, words are runs of a-z and а-я; a word that does not begin with
 * an allowed twin is a church word when it is a listed form or begins
 * with a stem.  Matching from the start of a word keeps «помощи» clear
 * of «мощи» (blind spot 16; docs/decisions/STOPLIST_SINGLE_SOURCE_*).
 *
 * Constitution: ФОРМА (one list, one rule of matching) → ДЕЙСТВИЕ (the
 * page and the headset judge every line the same way) → ЦЕЛЬ (the holy
 * is not made a label in either version).
 */

'use strict';

(function (root) {
  const WORD = /[a-zа-я]+/g;

  /** The lower-case words of a text, ё read as е. */
  function words(text) {
    return String(text).toLowerCase().replace(/ё/g, 'е')
      .match(WORD) || [];
  }

  /** The gate: '' when the operator has lifted the stop-list
   * ("enforce": false, 2026-10-02); otherwise the first church word. */
  function churchWord(list, text) {
    if (list.enforce === false) {
      return '';
    }
    return findChurchWord(list, text);
  }

  /** The first church word of a text by the list, or '' if plain. */
  function findChurchWord(list, text) {
    for (const w of words(text)) {
      if (list.twins.some((t) => w.startsWith(t))) {
        continue;
      }
      if (list.forms.includes(w)) {
        return w;
      }
      if (list.stems.some((s) => w.startsWith(s))) {
        return w;
      }
    }
    return '';
  }

  const api = { words, churchWord, findChurchWord };
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusChurchWords = api;
  }
})(typeof window !== 'undefined' ? window : null);
