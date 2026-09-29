/**
 * Ludus: meeting a passion on the road (HLD F1, DEF-016/017).
 *
 * A passion is met as a thought, and the Fathers describe how a thought
 * takes hold in stages (St John Climacus, Ladder step 15; St Philotheus
 * of Sinai in the Philokalia):
 *   prilog     the suggestion appears            (прилог)
 *   converse   the mind talks with it            (сочетание)
 *   consent    the will agrees                   (сосложение)
 *   captive    the thought leads the person      (пленение)
 * The encounter is this ladder, walked down or refused:
 *   - the best answer is to cut the thought at the suggestion, either by
 *     naming its sign (discernment, taught by a mentor or reached by
 *     Wisdom) or by turning away into stillness;
 *   - repentance is open at every stage: "remember the word" always
 *     leads back to stillness;
 *   - stillness (hesychia) ends every good path and pays nothing, since
 *     prayer and stillness are never XP (CLAUDE.md TABOO 0.35 rule 16);
 *   - the only bonus is +1 Wisdom, once per passion, for discerning it
 *     at the first stage: understanding, not a prize for fighting;
 *   - consenting brings no damage: the passion simply returns later.
 * No holy object is a weapon here; a passion is overcome by sobriety
 * and stillness (TABOO 0.2 items 3-4).  Pure logic, no DOM, so the
 * same file runs in the browser (window.LudusPassion) and in tests.
 */

'use strict';

(function (root) {
  const STAGES = ['prilog', 'converse', 'consent', 'captive', 'stillness',
    'virtue'];

  function num(v) {
    const n = Number(v);
    return Number.isFinite(n) ? n : 0;
  }

  // Naming the sign needs either the mentor who teaches it or enough
  // Wisdom to see it unaided.
  function canName(passion, form, actions) {
    const met = actions && actions.met && actions.met[passion.teacher];
    return Boolean(met) || num(form && form.wisdom) >= passion.wisdomToName;
  }

  function start(passion) {
    return { passionId: passion.id, stage: 'prilog', named: false,
      turnedAtPrilog: false };
  }

  // The choices at a stage.  Every option has a fixed next stage, so the
  // same choices always lead to the same end (no randomness, TABOO 0.35
  // rule 15).
  function options(state, passion, form, actions) {
    switch (state.stage) {
      case 'prilog': {
        const list = [
          { id: 'look', text: 'Look closer', text_ru: 'Присмотреться',
            next: 'converse' },
          { id: 'turn', text: 'Turn away in silence',
            text_ru: 'Отвернуться в молчании', next: 'stillness' },
        ];
        if (canName(passion, form, actions)) {
          list.splice(1, 0, { id: 'name', text: `Name it: ${passion.cue}`,
            text_ru: `Назвать: ${passion.cue_ru}`, next: 'stillness' });
        }
        return list;
      }
      case 'converse':
        return [
          { id: 'answer', text: 'Answer it, argue it out',
            text_ru: 'Ответить ему, переспорить', next: 'consent' },
          { id: 'stop', text: 'Stop talking with it; be still',
            text_ru: 'Не беседовать с ним; умолкнуть', next: 'stillness' },
        ];
      case 'consent':
        return [
          { id: 'take', text: 'Take what it offers',
            text_ru: 'Взять предложенное', next: 'captive' },
          { id: 'remember', text: "Remember the mentor's word",
            text_ru: 'Вспомнить слово наставника', next: 'stillness' },
        ];
      case 'stillness':
        return [{ id: 'still', text: 'Be still for three breaths',
          text_ru: 'Помолчать три вдоха', next: 'virtue', breaths: 3 }];
      default:
        return [];
    }
  }

  function choose(state, optionId, passion, form, actions) {
    const opt = options(state, passion, form, actions)
      .find((o) => o.id === optionId);
    if (!opt) {
      return state;
    }
    return {
      ...state,
      stage: opt.next,
      named: state.named || opt.id === 'name',
      turnedAtPrilog: state.turnedAtPrilog
        || (state.stage === 'prilog' && opt.id === 'turn'),
    };
  }

  // The record of meetings with each passion.  Only the outcome is
  // kept, never what the player "said" to it.
  function normalizeRecord(raw) {
    const out = {};
    const src = raw && typeof raw === 'object' ? raw : {};
    Object.keys(src).forEach((id) => {
      if (/^[a-z]{1,20}$/.test(id) && src[id] && typeof src[id] === 'object') {
        out[id] = {
          meetings: Math.max(0, Math.floor(num(src[id].meetings))),
          overcome: Math.max(0, Math.floor(num(src[id].overcome))),
          captive: Math.max(0, Math.floor(num(src[id].captive))),
          discerned: src[id].discerned === true,
        };
      }
    });
    return out;
  }

  // Close an encounter.  Returns the new record and the FORM bonus, which
  // is +1 Wisdom only the first time a passion is named at its
  // suggestion.
  function finish(record, state) {
    const rec = normalizeRecord(record);
    const item = rec[state.passionId] || { meetings: 0, overcome: 0,
      captive: 0, discerned: false };
    item.meetings += 1;
    let bonus = {};
    if (state.stage === 'virtue') {
      item.overcome += 1;
      if (state.named && !item.discerned) {
        item.discerned = true;
        bonus = { wisdom: 1 };
      }
    } else if (state.stage === 'captive') {
      item.captive += 1;
    }
    rec[state.passionId] = item;
    return { record: rec, attributeBonuses: bonus };
  }

  // The next passion on the road: the first in Evagrius' order that has
  // not yet been overcome; a passion that took the player captive comes
  // back until it is overcome.
  function nextPassion(data, record) {
    const rec = normalizeRecord(record);
    return data.order.map((id) => data.passions.find((p) => p.id === id))
      .find((p) => p && !(rec[p.id] && rec[p.id].overcome > 0)) || null;
  }

  const api = { STAGES, start, options, choose, finish, nextPassion,
    normalizeRecord, canName };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusPassion = api;
  }
})(typeof window !== 'undefined' ? window : null);
