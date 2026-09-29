/**
 * Ludus: preparation for confession — a page that is never kept.
 *
 * The game cannot and does not perform the sacrament of confession:
 * absolution is given only by a priest in the Church.  What the game
 * offers is the preparation that the Church asks of a penitent, the
 * examination of conscience, as a private page the player writes for
 * themselves and then burns (CLAUDE.md TABOO 0.26).
 *
 * Declaration, enforced by this file and by tests/ludus-confession.test.js:
 *   - the text lives only in the <textarea> and in no variable of this
 *     module; it is never copied into state, events or messages;
 *   - nothing is written to localStorage, sessionStorage, IndexedDB,
 *     cookies, the Cache API or the service worker;
 *   - nothing is sent over the network: no fetch, XHR, beacon, socket;
 *   - nothing is logged: no console output, no analytics, no journal;
 *   - there is no counter, reward, attribute, gate or achievement tied
 *     to it; opening, writing and burning leave no trace in the game;
 *   - spell-check, autocorrect and autocomplete are off, because some
 *     browsers send typed text to a cloud dictionary;
 *   - on "burn", on close and when the page is hidden, the field is
 *     overwritten and then emptied.
 * Honest limit: a browser's garbage collector decides when freed
 * memory is reused, and an operating system may swap memory to disk;
 * no web page can erase those copies.  The declaration therefore
 * promises what the code controls: the game never keeps, sends or
 * logs the text.  A player who wants no digital trace at all writes on
 * paper, as the page itself advises.
 *
 * This module deliberately depends on nothing else in Ludus, so no
 * other module can observe the text by accident.
 */

'use strict';

(function (root) {
  // Questions for the examination follow the eight passions of the
  // Ladder (St John Climacus) and the Beatitudes (Mt 5:3-12).  They are
  // prompts in the player's own heart, not a checklist that is scored.
  const QUESTIONS = [
    { passion: 'gluttony', q: 'Did I serve my appetite before people?',
      q_ru: 'Не служил ли я чреву прежде людей?', source: 'Ladder, 14' },
    { passion: 'lust', q: 'Did I let my eyes and thoughts wander?',
      q_ru: 'Не блуждали ли мои глаза и помыслы?', source: 'Ladder, 15' },
    { passion: 'avarice', q: 'Did I hold on to what I should have given?',
      q_ru: 'Не удержал ли я того, что должен был отдать?',
      source: 'Ladder, 16-17' },
    { passion: 'anger', q: 'Whom did I wound with a word, and not forgive?',
      q_ru: 'Кого я ранил словом и не простил?', source: 'Ladder, 8-9' },
    { passion: 'sadness', q: 'Did I grieve over what was taken, not over '
      + 'what I did?', q_ru: 'Не скорбел ли я о потерянном, а не о '
      + 'содеянном?', source: 'Ladder, 7' },
    { passion: 'despondency', q: 'Where did I give up and call it rest?',
      q_ru: 'Где я опустил руки и назвал это отдыхом?',
      source: 'Ladder, 13' },
    { passion: 'vainglory', q: 'What good did I do so that others would '
      + 'see it?', q_ru: 'Какое добро я сделал, чтобы это видели?',
      source: 'Ladder, 22; Mt 6:1' },
    { passion: 'pride', q: 'Whom did I judge as lower than myself?',
      q_ru: 'Кого я осудил как худшего себя?', source: 'Ladder, 23' },
  ];

  // On a headset there is no field at all.  The Quest system keyboard
  // offers voice dictation, which the operating system handles and may
  // send to Meta's servers; a web page cannot switch it off, so a
  // warning there would promise what the code cannot keep.  The page
  // shows the questions only and leaves the answer to paper or to the
  // silence of the heart (decision recorded in TABOO 0.26 item 9).
  function isHeadset() {
    const ua = (root && root.navigator && root.navigator.userAgent) || '';
    return /OculusBrowser|Quest|Pico|Wolvic/i.test(ua);
  }

  // A page opened twice must not keep the first text, so the dialog is
  // built anew every time and removed from the DOM when it closes.
  let dialog = null;
  let onHide = null;

  // Overwrite then empty.  Assigning '' alone lets some engines keep the
  // old string until garbage collection; writing a same-length run of
  // spaces first replaces the visible buffer the field holds.
  function burnField(field) {
    if (!field) {
      return;
    }
    field.value = ' '.repeat(field.value.length);
    field.value = '';
  }

  function close() {
    if (!dialog) {
      return;
    }
    burnField(dialog.querySelector('textarea'));
    if (onHide) {
      document.removeEventListener('visibilitychange', onHide);
      window.removeEventListener('pagehide', onHide);
      onHide = null;
    }
    if (typeof dialog.close === 'function' && dialog.open) {
      dialog.close();
    }
    dialog.remove();
    dialog = null;
  }

  function el(tag, attrs, text) {
    const node = document.createElement(tag);
    Object.keys(attrs || {}).forEach((k) => node.setAttribute(k, attrs[k]));
    if (text) {
      node.textContent = text;
    }
    return node;
  }

  // Build the page.  Everything is created with textContent, never
  // innerHTML, and the typed text is never read by this code except to
  // overwrite it.
  function open() {
    close();
    dialog = el('dialog', {
      class: 'ludus-confession',
      'aria-labelledby': 'ludus-confession-h',
    });
    dialog.append(
      el('h3', { id: 'ludus-confession-h' }, 'Before confession'),
      el('p', { class: 'ludus-confession-note' },
        'This is not the sacrament. Forgiveness is given by a priest in '
        + 'church; here you only prepare your heart. What you write is '
        + 'never saved, sent or logged, and it is burned when you close '
        + 'this page. If you want no digital trace at all, write on '
        + 'paper.'),
      el('p', { class: 'ludus-confession-note', lang: 'ru' },
        'Это не таинство. Прощение даёт священник в храме; здесь вы '
        + 'только готовите сердце. Написанное не сохраняется, не '
        + 'отправляется и не записывается в журнал, а при закрытии '
        + 'сгорает. Если не хотите никакого цифрового следа, пишите на '
        + 'бумаге.'));

    const list = el('ol', { class: 'ludus-confession-questions' });
    QUESTIONS.forEach((item) => {
      const li = el('li', { title: item.source });
      li.append(el('span', {}, item.q), el('span', { lang: 'ru',
        class: 'ludus-confession-ru' }, item.q_ru));
      list.append(li);
    });
    dialog.append(list);

    if (isHeadset()) {
      dialog.append(el('p', { class: 'ludus-confession-note' },
        'On a headset this page has no place to write: voice dictation '
        + 'cannot be switched off by the game. Answer these questions '
        + 'on paper, or in the silence of your heart.'),
      el('p', { class: 'ludus-confession-note', lang: 'ru' },
        'В шлеме на этом листке писать нельзя: голосовой ввод игра '
        + 'выключить не может. Ответьте на вопросы на бумаге или в '
        + 'тишине сердца.'));
      const close1 = el('button', { type: 'button', class: 'ludus-rule-btn' },
        'Close');
      close1.addEventListener('click', close);
      const row1 = el('div', { class: 'ludus-rule-actions' });
      row1.append(close1);
      dialog.append(row1);
      dialog.addEventListener('cancel', (event) => {
        event.preventDefault();
        close();
      });
      document.body.append(dialog);
      if (typeof dialog.showModal === 'function') {
        dialog.showModal();
      } else {
        dialog.setAttribute('open', '');
      }
      close1.focus();
      return;
    }

    dialog.append(el('p', { class: 'ludus-confession-note' },
      'Do not dictate by voice: your device may send speech to its '
      + 'maker\'s servers. A third-party keyboard may keep what you '
      + 'type; use the system keyboard or paper.'),
    el('p', { class: 'ludus-confession-note', lang: 'ru' },
      'Не диктуйте голосом: устройство может отправить речь на серверы '
      + 'производителя. Сторонняя клавиатура может хранить набранное; '
      + 'пишите системной клавиатурой или на бумаге.'));

    const field = el('textarea', {
      'aria-label': 'Your page (never saved)',
      rows: '8',
      autocomplete: 'off',
      autocorrect: 'off',
      autocapitalize: 'off',
      spellcheck: 'false',
      'data-gramm': 'false',
      'data-lpignore': 'true',
    });
    dialog.append(field);

    const burn = el('button', { type: 'button',
      class: 'ludus-rule-btn ludus-confession-burn' },
    'Burn the page');
    const leave = el('button', { type: 'button', class: 'ludus-rule-btn' },
      'Close (the page burns)');
    burn.addEventListener('click', () => burnField(field));
    leave.addEventListener('click', close);
    const row = el('div', { class: 'ludus-rule-actions' });
    row.append(burn, leave);
    dialog.append(row);

    // Escape closes a <dialog> natively; route it through close() so the
    // field is burned first.
    dialog.addEventListener('cancel', (event) => {
      event.preventDefault();
      close();
    });
    // Leaving the tab or the page burns the page too.
    onHide = () => {
      if (document.visibilityState === 'hidden') {
        close();
      }
    };
    document.addEventListener('visibilitychange', onHide);
    window.addEventListener('pagehide', onHide);

    document.body.append(dialog);
    if (typeof dialog.showModal === 'function') {
      dialog.showModal();
    } else {
      dialog.setAttribute('open', '');
    }
    field.focus();
  }

  const api = { open, close, QUESTIONS, isHeadset };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusConfession = api;
  }
})(typeof window !== 'undefined' ? window : null);
