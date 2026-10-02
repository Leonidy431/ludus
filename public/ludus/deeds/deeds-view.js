/**
 * Ludus: the page of the place acts (public/ludus/deeds/index.html).
 *
 * It shows the 26 acts as the heart's panel does in the headset: the
 * place, the heart's words, the teaching, the lines of the act, the
 * answer to the last step and the buttons; all of it from the walk in
 * ../data/place-deeds.json, played by LudusPlaceDeeds.  Where an act asks
 * to stand still, the page counts the same seconds as the headset while
 * the page is in view, and any other step stops the count.
 *
 * Stored: only the record of done acts, {id: {count, lastDay}}, under
 * "ludus.deeds" in this browser, as the hub save holds it under "deeds".
 * No score, no reward, no FORM change, nothing sent anywhere.
 */

'use strict';

(function () {
  const D = window.LudusPlaceDeeds;
  const KEY = 'ludus.deeds';
  const list = document.getElementById('deeds-list');
  const panel = document.getElementById('deeds-panel');
  let graph = null;
  let current = null;
  let record = {};
  let waitTimer = 0;
  let waitLeft = 0;

  function today() {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-'
      + pad(d.getDate());
  }

  function readRecord() {
    try {
      return D.normalize(JSON.parse(
        window.localStorage.getItem(KEY) || 'null'), graph);
    } catch (e) {
      return {};
    }
  }

  function writeRecord() {
    try {
      window.localStorage.setItem(KEY, JSON.stringify(record));
    } catch (e) {
      // A private window: the record lives for this visit only.
    }
  }

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) {
      e.className = cls;
    }
    if (text !== undefined) {
      e.textContent = text;
    }
    return e;
  }

  /** "1 раз", "2 раза", "5 раз": the count as Russian says it. */
  function times(n) {
    const d = n % 10;
    const h = n % 100;
    if (d >= 2 && d <= 4 && (h < 12 || h > 14)) {
      return n + ' раза';
    }
    return n + ' раз';
  }

  function stopWait() {
    if (waitTimer) {
      window.clearInterval(waitTimer);
      waitTimer = 0;
    }
    waitLeft = 0;
  }

  function step(next) {
    const was = D.view(graph, current).done;
    current = next;
    if (D.view(graph, current).done && !was) {
      record = D.record(record, graph, current.act, today());
      writeRecord();
    }
    render();
  }

  function startWait(seconds) {
    stopWait();
    waitLeft = seconds;
    waitTimer = window.setInterval(() => {
      // Only seconds the page is seen count, as only standing still does.
      if (document.hidden) {
        return;
      }
      waitLeft -= 1;
      if (waitLeft <= 0) {
        stopWait();
        step(D.wait(graph, current));
      } else {
        render();
      }
    }, 1000);
    render();
  }

  function renderList() {
    list.textContent = '';
    D.ids(graph).forEach((id) => {
      const p = D.place(graph, id);
      const li = el('li');
      const b = el('button');
      b.type = 'button';
      b.appendChild(el('div', '', p.title));
      const r = record[id];
      b.appendChild(el('div', 'count', r
        ? 'сделано ' + times(r.count) + ', последний — ' + r.lastDay
        : p.heart));
      b.setAttribute('aria-current', current && current.act === id
        ? 'true' : 'false');
      b.addEventListener('click', () => {
        stopWait();
        current = D.start(graph, id);
        render();
        // On a narrow screen the panel is below the list: bring it up.
        if (window.matchMedia('(max-width: 720px)').matches) {
          panel.scrollIntoView({ block: 'start' });
        }
      });
      li.appendChild(b);
      list.appendChild(li);
    });
  }

  function render() {
    renderList();
    panel.textContent = '';
    if (!current) {
      panel.appendChild(el('p', 'note', 'Выбери место слева.'));
      return;
    }
    const p = D.place(graph, current.act);
    const v = D.view(graph, current);
    panel.appendChild(el('h2', '', p.title));
    panel.appendChild(el('p', 'heart', p.heart));
    panel.appendChild(el('p', 'teaching', p.teaching));
    const lines = el('div', 'lines');
    v.lines.forEach((l) => lines.appendChild(el('p', '', l)));
    panel.appendChild(lines);
    if (v.reply) {
      panel.appendChild(el('p', 'reply', v.reply));
    }
    const r = record[current.act];
    if (r && r.lastDay === today()) {
      panel.appendChild(el('p', 'today', 'Сегодня уже сделано.'));
    }
    const steps = el('div', 'steps');
    v.options.forEach((o) => {
      const b = el('button', '', o.text);
      b.type = 'button';
      b.disabled = o.disabled;
      if (o.disabled && o.reason) {
        b.title = o.reason;
        b.textContent = o.text + ' — ' + o.reason;
      }
      b.addEventListener('click', () => {
        stopWait();
        step(D.choose(graph, current, o.id));
      });
      steps.appendChild(b);
    });
    if (v.waitSeconds > 0) {
      const b = el('button', '', waitLeft > 0
        ? 'Стоишь тихо… ещё ' + waitLeft + ' с'
        : 'Постоять тихо (' + v.waitSeconds + ' с)');
      b.type = 'button';
      b.addEventListener('click', () => {
        if (waitLeft > 0) {
          stopWait();
          render();
        } else {
          startWait(v.waitSeconds);
        }
      });
      steps.appendChild(b);
    }
    if (v.done) {
      const b = el('button', '', 'Начать заново');
      b.type = 'button';
      b.addEventListener('click', () => {
        current = D.start(graph, current.act);
        render();
      });
      steps.appendChild(b);
    }
    panel.appendChild(steps);
  }

  window.fetch('../data/place-deeds.json')
    .then((r) => r.json())
    .then((g) => {
      graph = g;
      record = readRecord();
      render();
    })
    .catch(() => {
      panel.textContent = 'Не удалось открыть дела мест.';
    });
})();
