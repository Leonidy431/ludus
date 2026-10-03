/**
 * Ludus missions and gate thresholds: the campaign made playable.
 *
 * CLAUDE.md constitution: FORM (7 attributes) -> ACTION -> GOAL.  The
 * campaign spine (data/campaign-spine.json: a prologue, five acts and a
 * finale, 99 missions) had titles only.  This module turns each mission
 * into four steps of the game's own ACTION layer:
 *   - find: a real object of Issyk-Kul from data/lake-objects-99.json,
 *     handed over, noted or checked against the chronicle;
 *   - practice: one deed of the rule from LudusActions.PRACTICES (alms,
 *     forgiveness, obedience, a fast, a deed in secret);
 *   - dialogue: one exchange with a person of the valley, read from
 *     data/dialogue-trees.json, so every line keeps its meaning and its
 *     source from the closed canon (TABOO 0.35 rule 18);
 *   - dive: a descent of the ROV with the real physics of the lake
 *     (1 bar per 10.2 m plus 1.01325 bar, sound at 1480 m/s).
 *
 * Consequences are deterministic (TABOO 0.35 rule 15): +1..+5 to one of
 * the seven attributes by the depth of the choice (surface choices pay
 * nothing, and mission growth stops at a ceiling per act), a path
 * opened, or a person who greets you differently next time.  No random number is
 * drawn anywhere in this file (the test greps for it), and the order
 * of steps and objects follows the mission's place in its act.
 *
 * The fall replaces losing.  When the player takes a passion's lure,
 * "the passion took its own": the light dims and two paths close (the
 * deep answers and the road to the next mission).  Nothing is counted:
 * there is no sin counter, no attribute is taken away, and the fall is
 * forgotten once it is lifted.  It is lifted by sobriety (the evening
 * watch over thoughts, or a minute of stillness) together with a talk
 * with the mentor who teaches that passion's sign.  Prayer itself never
 * pays: the practices of prayer are not mission steps and give no
 * bonus anywhere here (TABOO 0.35 rule 16).
 *
 * Missions the chorus flagged (needsChorusRewrite) are shown as "on
 * rewrite with the chorus" and never run.
 *
 * Gate thresholds: data/gate-trials.json holds one trial per gate.  A
 * trial is a choice by understanding, not a quiz: every option leads
 * somewhere (through, back to the mentor, or into a fall).  It is
 * offered only when the three conditions of the gate already hold.
 *
 * Pure logic first (module.exports for node tests), then a small
 * browser controller (window.LudusMissions) that renders #ludus-missions
 * and listens for "ludus:gate-selected".
 */

'use strict';

(function (root) {
  const ATTRS = ['wisdom', 'faith', 'dexterity', 'constitution', 'charisma',
    'cunning', 'erudition'];

  // The six gates in ladder order; act N (N >= 2) opens only after the
  // threshold of gate N-2 is crossed, so the story climbs with the soul.
  const GATE_IDS = ['foundational', 'liturgical', 'ascetic',
    'contemplative', 'mystical', 'apophatic'];
  const GATE_FOR_ACT = { 2: 'foundational', 3: 'liturgical', 4: 'ascetic',
    5: 'contemplative', 6: 'mystical' };

  // Words of the Church that never stand on a button or a label (TABOO
  // 0.39 item 3, TABOO 0.4 rule 7).  The tests read this list.  JS \b
  // only knows ASCII letters, so the end of a Cyrillic word is written
  // as "no Cyrillic letter follows".
  const STOP_WORDS = new RegExp('(мученик|свят(ой|ая|ое|ые|ого|ому|ым|ых|ую)'
    + '(?![а-яё])|благодат|таинств|спасени)', 'i');

  // Only deeds, never the practices of prayer: a mission step that pays
  // (opens a path) must not turn prayer into a key (TABOO 0.35 rule 16).
  const PRACTICE_RU = {
    alms: { label: 'Подать милостыню',
      after: 'Ты отдал без счёта; у ворот стало на одного сытого больше.' },
    forgive: { label: 'Простить обиду',
      after: 'Обида положена, как тюк у колодца; идти стало легче.' },
    obedience: { label: 'Исполнить послушание наставника',
      after: 'Ты сделал, как сказали, не споря; дорога стала прямее.' },
    fast: { label: 'Сохранить сегодняшний пост',
      after: 'Ты ел в свой час и мало и никому об этом не сказал.' },
    // A good deed in secret opens nothing visible: a secret that pays in
    // front of the player feeds vainglory (Mt 6:3-4).
    secret_deed: { label: 'Сделать доброе тайно',
      after: 'Об этом никто не узнал. И не нужно.', hidden: true },
  };

  // Sobriety lifts a fall.  These two are read from the rule, not done
  // here: the evening watch over thoughts (daily) or stillness (timer).
  const SOBRIETY = [
    { id: 'guard_thoughts', label: 'Вечерний дозор над помыслами' },
    { id: 'stillness', label: 'Безмолвие: одна минута' },
  ];

  // The passions' own lures in the language of profit (TABOO 0.39).
  // Each is a choice the player may take; its sign is taught by the
  // passion's teacher (passions.json), as prelest requires (TABOO 0.2
  // item 8).  Lust is not used on the road of the missions at all.
  const LURES = {
    gluttony: {
      find: 'Сначала поесть: привал рядом, находка подождёт сытого часа.',
      dive: 'Не лезть в холодную воду натощак: погружение подождёт до завтра.',
    },
    avarice: {
      find: 'Спрятать в пояс: никто не видел, а зимы длинные.',
      dive: 'Нырнуть за блеском раньше других: кто первый, того и серебро.',
    },
    vainglory: {
      find: 'Отнести находку на базар и рассказать, кто её нашёл.',
      dive: 'Уйти глубже всех, чтобы на пристани запомнили твоё имя.',
    },
    sadness: {
      find: 'Сесть над находкой и горевать: здесь уже не будет как прежде.',
      dive: 'Не спускаться: всё хорошее давно утонуло.',
    },
    anger: {
      find: 'Швырнуть находку в воду: это вещь тех, кто тебя обидел.',
      dive: 'Дёрнуть трос со злостью: пусть на лодке знают, что ты недоволен.',
    },
    pride: {
      find: 'Объявить находку своим открытием: ты нашёл сам, без братии.',
      dive: 'Отстегнуть страховочный конец: ты и без него умеешь.',
    },
    acedia: {
      find: 'Не наклоняться: день всё равно не кончится, пусть лежит.',
      dive: 'Остаться на берегу: вода та же, что вчера, смысла нет.',
    },
  };

  // One plan per act of the spine.  npcs name the person of the step
  // and two nodes of their tree: where they start, and where they start
  // once the player has handed a find over honestly ("warm").  Finds and
  // dives are ids of the real objects in lake-objects-99.json.  meaning
  // and source are the act's teaching, from the canon.
  const ACT_PLAN = {
    prologue: {
      passion: 'gluttony',
      npcs: [{ npc: 'sargis', node: 'scales_greeting', warm: 'open_hand' },
        { npc: 'anahit', node: 'a_gate', warm: 'a_first_night' }],
      finds: ['yakor.shallows.0', 'gruzilo.shallows.0'],
      dives: ['caustics.shallows.0', 'spring.shallows.0'],
      practices: ['obedience', 'fast'],
      intro: 'Дорога к озеру: «{title}».',
      practiceScene: 'На привале у колодца наставник даёт тебе дело.',
      findPlace: 'На отмели у брода',
      meaning: 'The road begins by leaving: a stranger on the way learns '
        + 'to depend on God and on the hospitality of others.',
      source: 'Ladder, step 3',
    },
    trade: {
      passion: 'avarice',
      npcs: [{ npc: 'sargis', node: 'scales_greeting', warm: 'open_hand' },
        { npc: 'vardan', node: 'v_ledger', warm: 'v_marks' },
        { npc: 'melik', node: 'm_scales', warm: 'm_weights' },
        { npc: 'anahit', node: 'a_gate', warm: 'a_first_night' },
        { npc: 'khan', node: 'k_start', warm: 'k_yasa' },
        { npc: 'theodora', node: 'greeting', warm: 'one_loaf' }],
      finds: ['khum.shallows.0', 'kotel.shallows.0', 'bulla.shallows.0',
        'cherepki.shallows.1', 'glazur.shallows.0', 'zhernov.shallows.0',
        'kayrak.shallows.0'],
      dives: ['svaya.shallows.2', 'karman.shallows.1', 'shafts.shallows.0',
        'boulder.shallows.1'],
      practices: ['alms', 'secret_deed', 'forgive'],
      intro: 'Караванная дорога: «{title}».',
      practiceScene: 'У ворот каравансарая ждут те, кому нечем платить.',
      findPlace: 'На отмели у пристани фактории',
      meaning: 'A false balance is an abomination to the Lord; honest '
        + 'weights are the first teaching of the road of trade.',
      source: 'Proverbs 11:1',
    },
    spiritual: {
      passion: 'vainglory',
      npcs: [{ npc: 'theodora', node: 'greeting', warm: 'one_loaf' },
        { npc: 'kassiani', node: 'k_greeting', warm: 'k_song' },
        { npc: 'ikonopisets', node: 'i_greeting', warm: 'i_layers' },
        { npc: 'abba_moses', node: 'greeting', warm: 'cell_teaches' },
        { npc: 'elder_sergius', node: 'greeting', warm: 'still_water' },
        { npc: 'photius', node: 'library', warm: 'margin_art' }],
      finds: ['glazur.shallows.1', 'bulla.shallows.0', 'fundament.shallows.0',
        'kirpich.shallows.0'],
      dives: ['shafts.shallows.1', 'terrace.shelf.2', 'snow.shelf.0'],
      practices: ['secret_deed', 'obedience', 'forgive'],
      intro: 'Знаки в глине и камне: «{title}». На отмели и в скриптории '
        + 'лежат следы тех, кто молился у озера до нас.',
      practiceScene: 'В скриптории брат просит о помощи, пока никто не видит.',
      findPlace: 'На отмели под старой кладкой',
      meaning: 'Signs in clay and stone are honoured for what they point '
        + 'to; the image leads to its prototype and is never a charm.',
      source: 'St John of Damascus, Treatises on the Divine Images',
    },
    hydrology: {
      passion: 'sadness',
      npcs: [{ npc: 'rybak_issyk_kul', node: 'greeting', warm: 'mending' },
        { npc: 'elder_sergius', node: 'greeting', warm: 'still_water' },
        { npc: 'abba_john', node: 'greeting', warm: 'watch_hand' },
        { npc: 'tabib', node: 'greeting', warm: 'bandage' }],
      finds: ['svaya.shelf.2', 'fundament.shallows.1', 'ochag.shallows.0',
        'balka.shallows.0'],
      dives: ['terrace.slope.2', 'thermo.slope.0', 'intwave.slope.0',
        'upwelling.slope.0', 'slope-edge.slope.2', 'silt.slope.0'],
      practices: ['fast', 'alms', 'obedience'],
      intro: 'Вода поднимается: «{title}». Что было берегом, стало дном.',
      practiceScene: 'На пристани рыбаки чинят сети после пустого сезона.',
      findPlace: 'Там, где был прежний берег',
      meaning: 'The sea great and wide is full of works made in wisdom; '
        + 'the one who goes down to look sees the Maker in the made.',
      source: 'Psalm 103:24-25 (LXX; 104 in Hebrew numbering)',
    },
    diplomacy: {
      passion: 'anger',
      npcs: [{ npc: 'khan', node: 'k_start', warm: 'k_yasa' },
        { npc: 'strazhnik', node: 'gate_watch', warm: 'night_watch' },
        { npc: 'melik', node: 'm_scales', warm: 'm_weights' },
        { npc: 'macrina', node: 'greeting', warm: 'teaching' },
        { npc: 'abba_moses', node: 'greeting', warm: 'cell_teaches' }],
      finds: ['bulla.shallows.0', 'kosti.shallows.0', 'kleshchi.shallows.0',
        'kotel.shallows.0'],
      dives: ['seiche.shallows.0', 'langmuir.shallows.0', 'plume.shallows.1',
        'turbid.shallows.0'],
      practices: ['forgive', 'obedience', 'alms'],
      intro: 'Ханы и послы: «{title}». У каждого свои весы, а обители '
        + 'нужно слово, которое держит мир.',
      practiceScene: 'Посол ушёл, хлопнув дверью; его люди ещё во дворе.',
      findPlace: 'У брода, где стоят шатры посольства',
      meaning: 'As far as it depends on you, live peaceably with all; the '
        + 'word that keeps peace is weighed before it is spoken.',
      source: 'Romans 12:18',
    },
    craft: {
      passion: 'pride',
      npcs: [{ npc: 'sister_catherine', node: 'greeting',
        warm: 'wax_and_flame' },
      { npc: 'ikonopisets', node: 'i_greeting', warm: 'i_layers' },
      { npc: 'tabib', node: 'greeting', warm: 'bandage' },
      { npc: 'abba_john', node: 'greeting', warm: 'watch_hand' },
      { npc: 'theodora', node: 'greeting', warm: 'one_loaf' }],
      finds: ['kleshchi.shallows.1', 'shlak.shallows.0', 'zhernov.shallows.1',
        'kirpich.shallows.0', 'khum.shallows.1'],
      dives: ['clay.shelf.0', 'gravel.shallows.0', 'sandstone.shallows.0',
        'bubbles.shelf.1'],
      practices: ['obedience', 'secret_deed', 'fast'],
      intro: 'Мастерская обители: «{title}». Руки заняты, язык молчит, '
        + 'дело учит.',
      practiceScene: 'Мастер просит сделать работу так, как он велел.',
      findPlace: 'У старой кузни на отмели',
      meaning: 'The work of the hands keeps the heart from despondency; '
        + 'the elders plaited rope and prayed.',
      source: 'Apophthegmata Patrum, alphabetical collection, Antony the '
        + 'Great 1',
    },
    narrative: {
      passion: 'acedia',
      npcs: [{ npc: 'vardan', node: 'v_ledger', warm: 'v_marks' },
        { npc: 'photius', node: 'library', warm: 'margin_art' },
        { npc: 'rybak_issyk_kul', node: 'greeting', warm: 'mending' },
        { npc: 'elder_sergius', node: 'greeting', warm: 'still_water' },
        { npc: 'macrina', node: 'greeting', warm: 'teaching' },
        { npc: 'kassiani', node: 'k_greeting', warm: 'k_song' }],
      finds: ['svaya.shelf.2', 'bulla.shallows.0', 'ochag.shallows.0',
        'balka.shallows.0'],
      dives: ['terrace.slope.2', 'slope-edge.slope.0', 'thermo.slope.2',
        'silt.slope.0'],
      practices: ['forgive', 'secret_deed', 'alms'],
      intro: 'Камень под водой: «{title}». Книга находок почти дописана.',
      practiceScene: 'Перед тем как закрыть книгу, надо уладить старое.',
      findPlace: 'На старой береговой террасе',
      meaning: 'A thousand years are as yesterday; what the water keeps '
        + 'is kept for memory, not for gain.',
      source: 'Psalm 89:4 (LXX; 90:4 in Hebrew numbering)',
    },
  };

  // Short openings for the prologue and Act I, written from the titles
  // of the spine.  Later acts use the act's own opening line.
  const INTRO = {
    1: 'Обитель у озера принимает караван на ночь. Саргис считает '
      + 'верблюдов, Анаит топит тонир; тебе велено помочь у ворот.',
    3: 'Двое купцов спорят о весе тюка и зовут епископа рассудить. Пока '
      + 'он в пути, тебя просят приготовить вещи, свидетелей и книгу.',
    2: 'Армянская фактория на берегу: склады, писцовая, весы. В книге '
      + 'прихода не сходится столбец.',
    4: 'Хан обещает защиту дороги тем, кто держит честные весы. Обители '
      + 'предлагают стать свидетелем договора.',
    5: 'Погонщик просит зерна в долг до осени, залога у него нет. Решать '
      + 'будут по слову, а не по серебру.',
    6: 'Хлеб и воду надо развезти по трём стоянкам вдоль берега. '
      + 'Верблюдов мало, дорога длинная.',
    7: 'Генуэзцы из Таны и армянские купцы договариваются о пути. Им '
      + 'нужен человек, которому верят обе стороны.',
    8: 'На базаре ссора из-за подпиленной гири. Тебя зовут не судить, а '
      + 'помочь сверить меру.',
    9: 'Караван везёт зерно в голодное селение за перевалом. Груз даровой, '
      + 'и потому его особенно хочется пересчитать.',
    10: 'Мелик собирает пошлину; рыбаки просят отсрочки после пустого '
      + 'сезона. Тебя просят передать их слова.',
    11: 'Обитель ведёт счёт своим амбарам: где хлеб лежит без дела, а где '
      + 'его не хватает.',
    12: 'Шёлковый караван оставляет тюки на хранение, и купцы спрашивают, '
      + 'можно ли доверить тебе ключ.',
    13: 'Купцы разных земель собираются у каравансарая решить спор о '
      + 'дороге. Речь у них торопливая, а слово должно быть взвешенным.',
    15: 'Караванщики договариваются помогать друг другу в пути: колодцы, '
      + 'запасные верблюды, общий кров. Нужен тот, кто запишет устав.',
  };

  const KIND_RU = { find: 'находка', practice: 'дело',
    dialogue: 'разговор', dive: 'погружение' };
  const STEP_ORDER = ['find', 'practice', 'dialogue', 'dive'];

  const CLOSED_RU = {
    deep: 'глубокие ответы (сверка, запись, спуск по открытому пути)',
    road: 'дорога к следующей миссии',
  };

  // Physics of the lake (TABOO 0.35 rule 19).
  const SOUND_M_S = 1480;
  const BAR_PER_M = 1 / 10.2;
  const SURFACE_BAR = 1.01325;

  // ---------------------------------------------------------------
  // State.
  // ---------------------------------------------------------------

  function emptyState() {
    return { v: 1, done: {}, current: null, flags: {}, lines: {},
      trials: {}, trialWait: {}, fall: null };
  }

  function num(value) {
    const n = Number(value);
    return Number.isFinite(n) && n > 0 ? n : 0;
  }

  // Keep only known shapes from storage, so a hand-edited record cannot
  // smuggle in counters or a fall that cannot be lifted.
  function normalizeState(raw) {
    const src = raw && typeof raw === 'object' ? raw : {};
    const st = emptyState();
    Object.keys(src.done || {}).forEach((id) => {
      if (/^\d{1,3}$/.test(id) && src.done[id] === true) {
        st.done[id] = true;
      }
    });
    Object.keys(src.flags || {}).forEach((id) => {
      if (/^[a-z0-9_.:-]{1,60}$/.test(id) && src.flags[id] === true) {
        st.flags[id] = true;
      }
    });
    Object.keys(src.lines || {}).forEach((npc) => {
      const node = src.lines[npc];
      if (/^[a-z_]{1,40}$/.test(npc) && /^[a-z_]{1,40}$/.test(String(node))) {
        st.lines[npc] = String(node);
      }
    });
    GATE_IDS.forEach((g) => {
      if (src.trials && src.trials[g] === true) {
        st.trials[g] = true;
      }
      if (src.trialWait && Number.isFinite(Number(src.trialWait[g]))) {
        st.trialWait[g] = Math.floor(num(src.trialWait[g]));
      }
    });
    const cur = src.current;
    if (cur && /^\d{1,3}$/.test(String(cur.id))) {
      st.current = {
        id: Number(cur.id),
        step: Math.max(0, Math.floor(num(cur.step))),
        scene: cur.scene && typeof cur.scene === 'object' ? {
          text: String(cur.scene.text || ''),
          speaker: String(cur.scene.speaker || ''),
          source: String(cur.scene.source || ''),
          meaning: String(cur.scene.meaning || ''),
          choice: String(cur.scene.choice || ''),
        } : null,
      };
    }
    const f = src.fall;
    if (f && typeof f === 'object' && LURES[f.passion]) {
      st.fall = {
        passion: f.passion,
        teacher: /^[a-z_]{1,40}$/.test(String(f.teacher))
          ? String(f.teacher) : 'elder_sergius',
        closed: ['deep', 'road'],
        since: {
          sobriety: Math.floor(num(f.since && f.since.sobriety)),
          met: Math.floor(num(f.since && f.since.met)),
        },
      };
    }
    return st;
  }

  // ---------------------------------------------------------------
  // The campaign.
  // ---------------------------------------------------------------

  function chorusIds(spine) {
    return new Set((spine.needsChorusRewrite || []).map((m) => m.id));
  }

  function actOf(spine, missionId) {
    return spine.acts.findIndex((a) => a.missions.includes(missionId));
  }

  function titleOf(spine, missionId) {
    const m = spine.missions.find((x) => x.id === missionId);
    return m ? m.title : String(missionId);
  }

  function lakeObject(ctx, id) {
    return (ctx.lake.objects || []).find((o) => o.id === id) || null;
  }

  // The deterministic shape of one mission: which person, which object,
  // which deed and which dive.  Neighbours in an act differ because each
  // pool is walked by the mission's place in the act.
  function buildMission(ctx, missionId) {
    const spine = ctx.spine;
    const actIndex = actOf(spine, missionId);
    if (actIndex < 0) {
      return null;
    }
    const act = spine.acts[actIndex];
    const plan = ACT_PLAN[act.id];
    const pos = act.missions.indexOf(missionId);
    const pick = (pool) => pool[pos % pool.length];
    const title = titleOf(spine, missionId);
    return {
      id: missionId,
      title,
      actIndex,
      actId: act.id,
      actTitle: act.title_ru,
      chorus: chorusIds(spine).has(missionId),
      intro: INTRO[missionId] || plan.intro.replace('{title}', title),
      meaning: plan.meaning,
      source: plan.source,
      passion: plan.passion,
      // The FORM threshold of the deep answers grows with the act; a
      // guest (1 in every attribute) can reach the first ones.
      depthNeed: 1 + actIndex * 2,
      // Growth earned inside a mission raises an attribute only up to
      // this ceiling, two above the gate of the act.  Past it the player
      // grows by sitting with the mentors (the mentor cards), so walking
      // many missions cannot replace understanding (constitution 4).
      ceiling: 4 + actIndex * 2,
      steps: STEP_ORDER.map((kind) => {
        if (kind === 'find') {
          return { kind, object: pick(plan.finds), place: plan.findPlace };
        }
        if (kind === 'practice') {
          return { kind, practice: pick(plan.practices),
            scene: plan.practiceScene };
        }
        if (kind === 'dialogue') {
          return Object.assign({ kind }, pick(plan.npcs));
        }
        return { kind, object: pick(plan.dives) };
      }),
    };
  }

  function actComplete(spine, state, actIndex) {
    const chorus = chorusIds(spine);
    return spine.acts[actIndex].missions
      .every((id) => chorus.has(id) || state.done[id]);
  }

  function actLock(spine, state, actIndex) {
    if (actIndex === 0) {
      return null;
    }
    if (!actComplete(spine, state, actIndex - 1)) {
      return `Сначала пройди: ${spine.acts[actIndex - 1].title_ru}`;
    }
    const gate = GATE_FOR_ACT[actIndex];
    if (gate && !state.trials[gate]) {
      return `Нужен порог: ${gateTitle(gate)}`;
    }
    return null;
  }

  const GATE_TITLE_RU = {
    foundational: 'первый, основание',
    liturgical: 'второй, общий голос',
    ascetic: 'третий, прядь до вечера',
    contemplative: 'четвёртый, мутный кувшин',
    mystical: 'пятый, незажжённая свеча',
    apophatic: 'шестой, без лампы',
  };

  function gateTitle(gateId) {
    return GATE_TITLE_RU[gateId] || gateId;
  }

  // The next mission to walk: the first unfinished, runnable mission of
  // the first act that is not complete.  Missions are walked in order.
  function nextMission(spine, state) {
    const chorus = chorusIds(spine);
    for (let i = 0; i < spine.acts.length; i += 1) {
      if (actComplete(spine, state, i)) {
        continue;
      }
      if (actLock(spine, state, i)) {
        return null;
      }
      return spine.acts[i].missions
        .find((id) => !chorus.has(id) && !state.done[id]) || null;
    }
    return null;
  }

  function catalog(ctx, state) {
    const spine = ctx.spine;
    const chorus = chorusIds(spine);
    const next = nextMission(spine, state);
    return spine.acts.map((act, i) => ({
      id: act.id,
      title: act.title_ru,
      lock: actLock(spine, state, i),
      complete: actComplete(spine, state, i),
      missions: act.missions.map((id) => {
        let status = 'locked';
        if (chorus.has(id)) {
          status = 'chorus';
        } else if (state.done[id]) {
          status = 'done';
        } else if (state.current && state.current.id === id) {
          status = 'current';
        } else if (id === next) {
          status = 'next';
        }
        return { id, title: titleOf(spine, id), status };
      }),
    }));
  }

  function canStart(ctx, state, missionId) {
    const spine = ctx.spine;
    if (chorusIds(spine).has(missionId)) {
      return { ok: false, reason: 'на переписке у хора' };
    }
    if (state.current) {
      return { ok: false, reason: 'Сначала закончи начатую миссию.' };
    }
    if (state.fall) {
      return { ok: false, reason: 'Дорога закрыта, пока свет не вернётся.' };
    }
    if (nextMission(spine, state) !== missionId) {
      return { ok: false, reason: 'Эта миссия ещё впереди.' };
    }
    return { ok: true, reason: '' };
  }

  function start(ctx, state, missionId) {
    const st = normalizeState(state);
    if (!canStart(ctx, st, missionId).ok) {
      return st;
    }
    st.current = { id: missionId, step: 0, scene: null };
    return st;
  }

  // ---------------------------------------------------------------
  // Steps.
  // ---------------------------------------------------------------

  // Bonuses: only the seven attributes, whole numbers 1..5.
  function cleanBonuses(raw) {
    const out = {};
    ATTRS.forEach((k) => {
      const v = Math.floor(num(raw && raw[k]));
      if (v > 0) {
        out[k] = Math.min(5, v);
      }
    });
    return out;
  }

  function capBonuses(bonuses, form, ceiling) {
    const out = {};
    Object.keys(bonuses).forEach((k) => {
      const room = ceiling - num(form && form[k]);
      if (room > 0) {
        out[k] = Math.min(bonuses[k], Math.floor(room));
      }
    });
    return out;
  }

  function meetsCondition(cond, form) {
    return Object.keys(cond || {}).every((k) => ATTRS.includes(k)
      && num(form && form[k]) >= num(cond[k]));
  }

  function passionOf(ctx, id) {
    return ((ctx.passions && ctx.passions.passions) || [])
      .find((p) => p.id === id) || null;
  }

  // The sign of a passion is shown under its lure once the player has
  // sat with the teacher who teaches it, or understands enough to name
  // it (the same rule as the road in ludus-passion.js).
  function lureChoice(ctx, mission, kind, form, actions) {
    const p = passionOf(ctx, mission.passion);
    const met = actions && actions.met ? actions.met : {};
    const taught = p && (num(met[p.teacher]) > 0
      || num(form && form.wisdom) >= num(p.wisdomToName));
    return { id: 'lure', text: LURES[mission.passion][kind], lure: true,
      cue: taught && p ? `Признак: ${p.cue_ru}` : '' };
  }

  function treeNode(ctx, npc, nodeId) {
    const tree = ctx.trees.trees[npc];
    if (!tree) {
      return null;
    }
    return tree.nodes.find((n) => n.id === nodeId)
      || tree.nodes.find((n) => n.id === tree.startNode) || null;
  }

  function stepView(ctx, state, mission, index, form, actions) {
    const step = mission.steps[index];
    const deepClosed = Boolean(state.fall);
    const closedNote = 'Путь закрыт, пока свет не вернётся.';
    const need = mission.depthNeed;
    if (step.kind === 'find') {
      const obj = lakeObject(ctx, step.object);
      const handover = obj && obj.flags && obj.flags.loot === 'hand-over';
      return {
        kind: 'find',
        title: 'Находка',
        text: `${step.place}: ${obj ? obj.ru : step.object}.`,
        meaning: 'What is found belongs to its owner and to memory; it is '
          + 'returned, never kept as loot.',
        source: 'Deuteronomy 22:1-3',
        choices: [
          { id: 'handover', text: handover
            ? 'Передать находку в книгу обители.'
            : 'Оставить на месте и записать, где лежит.' },
          { id: 'note', text: 'Отметить место и идти дальше.' },
          { id: 'deep', text: 'Сверить находку с летописью фактории.',
            deep: true,
            disabled: deepClosed || num(form && form.erudition) < need,
            reason: deepClosed ? closedNote
              : `Нужна Erudition ${need}.` },
          lureChoice(ctx, mission, 'find', form, actions),
        ],
      };
    }
    if (step.kind === 'practice') {
      const pr = PRACTICE_RU[step.practice];
      const src = actionSource(ctx, step.practice);
      return {
        kind: 'practice',
        title: 'Дело',
        text: step.scene,
        meaning: 'A deed of the rule answers a passion; it is done, not '
          + 'paid for.',
        source: src,
        choices: [
          { id: 'keep', text: `${pr.label}.` },
          { id: 'later', text: 'Отложить: дорога торопит.' },
        ],
      };
    }
    if (step.kind === 'dialogue') {
      const tree = ctx.trees.trees[step.npc];
      const nodeId = state.lines[step.npc] || step.node;
      const node = treeNode(ctx, step.npc, nodeId);
      const branches = (node && node.branches) || [];
      const choices = branches.map((b, i) => ({
        id: `b${i}`,
        text: b.text_ru || b.text,
        disabled: !meetsCondition(b.condition, form),
        reason: b.condition ? 'Нужно: ' + Object.keys(b.condition)
          .map((k) => `${k} ${b.condition[k]}`).join(', ') : '',
      }));
      if (!choices.some((c) => !c.disabled)) {
        choices.push({ id: 'bow', text: 'Молча поклониться и выйти.' });
      }
      return {
        kind: 'dialogue',
        title: `Разговор: ${tree ? tree.npcName_ru : step.npc}`,
        speaker: tree ? tree.npcName_ru : step.npc,
        npc: step.npc,
        node: node ? node.id : nodeId,
        text: node ? node.text_ru : '',
        voice: node ? node.voice : '',
        meaning: node ? node.meaning : '',
        source: node ? node.source : '',
        choices,
      };
    }
    const obj = lakeObject(ctx, step.object);
    const depth = obj ? obj.depth[1] : 5;
    const pathFlag = `m${mission.id}.kept`;
    return {
      kind: 'dive',
      title: 'Погружение',
      text: `ROV уходит на ${depth} м: давление ${pressureBar(depth)} бар, `
        + `эхо от дна вернётся через ${echoMs(depth)} мс. `
        + `Внизу: ${obj ? obj.ru : step.object}.`,
      meaning: 'The creatures of the deep are works made in wisdom; the '
        + 'one who descends slowly sees them.',
      source: 'Psalm 103:24-25 (LXX; 104 in Hebrew numbering)',
      choices: [
        { id: 'rope', text: 'Спускаться по тросу медленно и слушать эхо.' },
        { id: 'record', text: 'Задержаться у дна и записать, что видишь.',
          deep: true,
          disabled: deepClosed || num(form && form.wisdom) < need,
          reason: deepClosed ? closedNote : `Нужна Wisdom ${need}.` },
        { id: 'path', text: 'Спуститься туда, куда открыл путь сделанный '
          + 'долг.', deep: true,
        disabled: deepClosed || !state.flags[pathFlag],
        reason: deepClosed ? closedNote
          : 'Путь открывает сделанное в этой миссии дело.' },
        lureChoice(ctx, mission, 'dive', form, actions),
      ],
    };
  }

  function actionSource(ctx, practiceId) {
    const api = ctx.actionsApi;
    const pr = api && api.PRACTICES.find((p) => p.id === practiceId);
    return pr ? pr.source : '';
  }

  function pressureBar(depth) {
    return (SURFACE_BAR + depth * BAR_PER_M).toFixed(2);
  }

  function echoMs(depth) {
    return Math.round((2 * depth / SOUND_M_S) * 1000 * 10) / 10;
  }

  // What the player sees now: the current step, or the scene that a
  // choice produced (with a button to walk on).
  function view(ctx, state, form, actions) {
    const st = normalizeState(state);
    if (!st.current) {
      return null;
    }
    const mission = buildMission(ctx, st.current.id);
    const index = Math.min(st.current.step, mission.steps.length - 1);
    return {
      mission,
      index,
      total: mission.steps.length,
      kindRu: KIND_RU[mission.steps[index].kind],
      step: stepView(ctx, st, mission, index, form, actions),
      scene: st.current.scene,
      last: index === mission.steps.length - 1,
    };
  }

  function sobrietyOf(actions) {
    const a = actions || {};
    const guard = a.practices && a.practices.guard_thoughts
      ? num(a.practices.guard_thoughts.count) : 0;
    return guard + Math.floor(num(a.meditationHours) * 60 + 1e-6);
  }

  function fallInto(ctx, st, passionId, actions) {
    // The first fall stands until it is lifted: its snapshot is what
    // sobriety and the mentor's talk are measured against, so a second
    // fall must not quietly reset it.
    if (st.fall) {
      return;
    }
    const p = passionOf(ctx, passionId);
    const teacher = p ? p.teacher : 'elder_sergius';
    const met = actions && actions.met ? num(actions.met[teacher]) : 0;
    // The snapshot is what lifting is measured against; it is not a
    // tally and is dropped with the fall.
    st.fall = { passion: passionId, teacher, closed: ['deep', 'road'],
      since: { sobriety: sobrietyOf(actions), met } };
  }

  // Take one choice of the current step.  Returns the new state and the
  // effects the game must apply (bonuses, a meeting, a practice).
  function choose(ctx, state, choiceId, form, actions) {
    const st = normalizeState(state);
    const effects = { bonuses: {}, meet: null, practice: null, fall: null,
      opens: null, line: null };
    const v = view(ctx, st, form, actions);
    if (!v || v.scene) {
      return { state: st, effects };
    }
    const choice = v.step.choices.find((c) => c.id === choiceId);
    if (!choice || choice.disabled) {
      return { state: st, effects };
    }
    const mission = v.mission;
    const step = mission.steps[v.index];
    const scene = { text: '', speaker: '', source: '', meaning: '',
      choice: choice.text };
    if (choice.lure) {
      fallInto(ctx, st, mission.passion, actions);
      effects.fall = mission.passion;
      const p = passionOf(ctx, mission.passion);
      scene.text = `Помысел (${p ? p.name_ru : mission.passion}) взял `
        + 'своё. Свет вокруг потускнел, и два пути закрылись: '
        + `${CLOSED_RU.deep} и ${CLOSED_RU.road}. Их открывает трезвение `
        + 'и разговор с наставником.';
      scene.source = p ? p.ladder : '';
    } else if (step.kind === 'find') {
      const obj = lakeObject(ctx, step.object);
      const name = obj ? obj.ru.split(':')[0] : step.object;
      if (choiceId === 'handover') {
        // An honest find pays in trust, not in points: the person
        // of this mission starts from their "warm" node.  Surface choices
        // give no bonus, so FORM grows by understanding (the deep answers
        // and the talk), not by walking many missions.
        const talk = mission.steps.find((s) => s.kind === 'dialogue');
        st.lines[talk.npc] = talk.warm;
        effects.line = { npc: talk.npc, node: talk.warm };
        scene.text = `${name} записан в книгу находок с местом и глубиной. `
          + 'Весть о честной находке ушла вперёд тебя.';
      } else if (choiceId === 'note') {
        scene.text = `Ты отметил место камнем и пошёл дальше. ${name} `
          + 'остался лежать, как лежал.';
      } else {
        effects.bonuses = { erudition: 2 };
        scene.text = `В летописи фактории нашлась строка о таком же: ${
          name}. Находка встала на своё место в истории берега.`;
      }
      scene.source = v.step.source;
    } else if (step.kind === 'practice') {
      const pr = PRACTICE_RU[step.practice];
      if (choiceId === 'keep') {
        effects.practice = step.practice;
        if (!pr.hidden) {
          const flag = `m${mission.id}.kept`;
          st.flags[flag] = true;
          effects.opens = flag;
        }
        scene.text = pr.after;
      } else {
        scene.text = 'Дело осталось несделанным. Дорога за это не '
          + 'наказывает, но и нового пути не открывает.';
      }
      scene.source = v.step.source;
    } else if (step.kind === 'dialogue') {
      effects.meet = step.npc;
      const node = treeNode(ctx, step.npc, v.step.node);
      const idx = Number(String(choiceId).slice(1));
      const branch = choiceId === 'bow' ? null : node.branches[idx];
      effects.bonuses = cleanBonuses(branch && branch.attributeBonuses);
      const reply = branch && branch.nextNodeId
        ? treeNode(ctx, step.npc, branch.nextNodeId) : null;
      scene.speaker = v.step.speaker;
      if (reply && reply.id === branch.nextNodeId) {
        scene.text = reply.text_ru;
        scene.source = reply.source;
        scene.meaning = reply.meaning;
      } else {
        scene.text = `${v.step.speaker} молча кивает.`;
        scene.source = v.step.source;
        scene.meaning = v.step.meaning;
      }
    } else {
      const obj = lakeObject(ctx, step.object);
      const depth = obj ? obj.depth[1] : 5;
      const what = obj ? obj.ru : step.object;
      if (choiceId === 'rope') {
        scene.text = `Медленно, по тросу, до ${depth} м. ${what}. `
          + 'Всплытие — не быстрее 10 м/мин.';
      } else if (choiceId === 'record') {
        effects.bonuses = { wisdom: 1 };
        scene.text = `${what}: записано с глубиной ${depth} м и `
          + `давлением ${pressureBar(depth)} бар. Запись пойдёт в книгу `
          + 'обители. Всплытие — не быстрее 10 м/мин.';
      } else {
        effects.bonuses = { constitution: 2 };
        scene.text = `Сделанное дело открыло спуск дальше: у ${what} `
          + 'видно то, чего не видно с тропы. Всплытие — не быстрее '
          + '10 м/мин.';
      }
      scene.source = v.step.source;
    }
    effects.bonuses = capBonuses(effects.bonuses, form, mission.ceiling);
    st.current.scene = scene;
    return { state: st, effects };
  }

  // Walk on after a scene.  The last step completes the mission.
  function advance(ctx, state) {
    const st = normalizeState(state);
    if (!st.current || !st.current.scene) {
      return { state: st, completed: null };
    }
    const mission = buildMission(ctx, st.current.id);
    if (st.current.step + 1 >= mission.steps.length) {
      st.done[mission.id] = true;
      st.current = null;
      return { state: st, completed: mission.id };
    }
    st.current.step += 1;
    st.current.scene = null;
    return { state: st, completed: null };
  }

  // ---------------------------------------------------------------
  // The fall.
  // ---------------------------------------------------------------

  function fallStatus(ctx, state, actions) {
    const st = normalizeState(state);
    if (!st.fall) {
      return { fallen: false };
    }
    const f = st.fall;
    const p = passionOf(ctx, f.passion);
    const met = actions && actions.met ? num(actions.met[f.teacher]) : 0;
    const sober = sobrietyOf(actions) > f.since.sobriety;
    const taught = met > f.since.met;
    const tree = ctx.trees && ctx.trees.trees[f.teacher];
    return {
      fallen: true,
      passion: f.passion,
      passionRu: p ? p.name_ru : f.passion,
      cue: p ? p.cue_ru : '',
      virtueRu: p ? p.virtue_ru : '',
      source: p ? p.ladder : '',
      teacher: f.teacher,
      teacherRu: tree ? tree.npcName_ru : f.teacher,
      closed: f.closed.map((k) => CLOSED_RU[k]),
      sober,
      taught,
      canLift: sober && taught,
    };
  }

  // The fall is dropped whole when it is lifted: nothing remains that
  // could be counted later.
  function liftFall(ctx, state, actions) {
    const st = normalizeState(state);
    if (fallStatus(ctx, st, actions).canLift) {
      st.fall = null;
    }
    return st;
  }

  // ---------------------------------------------------------------
  // Gate thresholds.
  // ---------------------------------------------------------------

  function trialFor(ctx, gateId) {
    return ((ctx.trials && ctx.trials.trials) || [])
      .find((t) => t.gateId === gateId) || null;
  }

  // A Firestore gate card carries a tier (1-6); the ladder carries the
  // gate id.  Both lead to the same threshold.
  function resolveGate(detail) {
    const d = detail || {};
    if (GATE_IDS.includes(d.gateId)) {
      return d.gateId;
    }
    const tier = parseInt(d.tier, 10);
    return tier >= 1 && tier <= 6 ? GATE_IDS[tier - 1] : null;
  }

  function trialView(ctx, state, gateId, form, actions) {
    const st = normalizeState(state);
    const trial = trialFor(ctx, gateId);
    if (!trial) {
      return null;
    }
    const api = ctx.actionsApi;
    const check = api ? api.evaluateLadder(form, actions, st.trials)
      .find((c) => c.gate.id === gateId) : null;
    const open = Boolean(check && check.open);
    // A fall closes every threshold, not only the deep paths: a choice
    // made in the dark would be made by the passion, not by the player.
    const locked = Boolean(st.fall);
    const met = actions && actions.met ? num(actions.met[trial.mentor]) : 0;
    const waiting = gateId in st.trialWait && met <= st.trialWait[gateId];
    const tree = ctx.trees && ctx.trees.trees[trial.mentor];
    return {
      trial,
      open,
      passed: Boolean(st.trials[gateId]),
      missing: check ? check.missing.map((m) => m.text) : [],
      waiting,
      locked,
      reason: locked ? 'fall' : '',
      mentorRu: tree ? tree.npcName_ru : trial.mentor,
      options: trial.options.map((o) => ({ id: o.id, text: o.text_ru,
        disabled: !open || waiting || locked
          || Boolean(st.trials[gateId]) })),
    };
  }

  function chooseTrial(ctx, state, gateId, optionId, form, actions) {
    const st = normalizeState(state);
    const tv = trialView(ctx, st, gateId, form, actions);
    const opt = tv && tv.trial.options.find((o) => o.id === optionId);
    const shown = tv && tv.options.find((o) => o.id === optionId);
    if (!opt || !shown || shown.disabled) {
      return { state: st, outcome: null, reply: '' };
    }
    if (opt.outcome === 'through') {
      st.trials[gateId] = true;
      delete st.trialWait[gateId];
    } else if (opt.outcome === 'return') {
      const met = actions && actions.met
        ? num(actions.met[tv.trial.mentor]) : 0;
      st.trialWait[gateId] = met;
    } else if (opt.outcome === 'fall') {
      fallInto(ctx, st, opt.passion, actions);
    }
    return { state: st, outcome: opt.outcome, reply: opt.reply_ru,
      source: opt.source, passion: opt.passion || null };
  }

  const api = {
    ATTRS,
    GATE_IDS,
    GATE_FOR_ACT,
    STOP_WORDS,
    PRACTICE_RU,
    SOBRIETY,
    LURES,
    ACT_PLAN,
    STEP_ORDER,
    emptyState,
    normalizeState,
    buildMission,
    nextMission,
    catalog,
    canStart,
    start,
    view,
    choose,
    advance,
    fallStatus,
    liftFall,
    trialFor,
    resolveGate,
    trialView,
    chooseTrial,
    pressureBar,
    echoMs,
  };

  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (!root || typeof document === 'undefined') {
    return;
  }
  root.LudusMissions = api;

  // ---------------------------------------------------------------
  // Browser controller.
  // ---------------------------------------------------------------

  const DATA = {
    spine: '/ludus/data/campaign-spine.json',
    trials: '/ludus/data/gate-trials.json',
    trees: '/ludus/data/dialogue-trees.json',
    lake: '/ludus/data/lake-objects-99.json',
    passions: '/ludus/data/passions.json',
  };
  // A guest keeps the road on the device, like FORM and the rule
  // (ludus-game.js); a signed-in player keeps it per player id.
  const GUEST_KEY = 'ludus.guest.missions';

  const ui = { ctx: null, loading: null, state: emptyState(),
    playerId: null, lastScene: null, trialGate: null, trialReply: null,
    labels: null };

  function esc(value) {
    return String(value === null || value === undefined ? '' : value)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function game() {
    return root.__LudusModule || null;
  }

  function storageKey() {
    const id = ui.playerId;
    return !id || id === 'guest' ? GUEST_KEY : `ludus.missions.${id}`;
  }

  function load() {
    try {
      ui.state = normalizeState(JSON.parse(
        root.localStorage.getItem(storageKey()) || 'null'));
    } catch (error) {
      console.warn('[Ludus] Missions unavailable:', error.message);
      ui.state = emptyState();
    }
  }

  function save() {
    try {
      root.localStorage.setItem(storageKey(), JSON.stringify(ui.state));
    } catch (error) {
      // A refused write keeps the road for this session only.
      console.warn('[Ludus] Missions not saved:', error.message);
    }
  }

  async function loadData() {
    if (ui.ctx) {
      return ui.ctx;
    }
    if (!ui.loading) {
      ui.loading = Promise.all(Object.keys(DATA).map(async (key) => {
        const res = await fetch(DATA[key]);
        if (!res.ok) {
          throw new Error(`${DATA[key]}: HTTP ${res.status}`);
        }
        return [key, await res.json()];
      })).then(async (pairs) => {
        // The Russian labels of the sources are for display only: a
        // missing table never stops the road.
        const L = root.LudusSourceLabels;
        ui.labels = L ? await L.load() : null;
        const ctx = { actionsApi: root.LudusActions || null };
        pairs.forEach(([k, v]) => { ctx[k] = v; });
        ui.ctx = ctx;
        return ctx;
      });
    }
    return ui.loading;
  }

  function form() {
    const g = game();
    return (g && g.getPlayerForm && g.getPlayerForm()) || {};
  }

  function actions() {
    const g = game();
    return (g && g.getActions && g.getActions()) || {};
  }

  // The fall dims the light of the whole game view (the CSS keeps it
  // short and honours reduced motion).
  function paintLight() {
    const box = document.getElementById('ludus-game-container');
    if (box) {
      box.classList.toggle('ludus-is-fallen', Boolean(ui.state.fall));
    }
  }

  function choiceButton(c, action) {
    const cls = `ludus-mission-choice${c.lure ? ' is-lure' : ''}`
      + `${c.deep ? ' is-deep' : ''}`;
    return '<div class="ludus-mission-option">'
      + `<button type="button" class="${cls}" data-action="${action}"`
      + ` data-choice-id="${esc(c.id)}"${c.disabled ? ' disabled' : ''}>`
      + `${esc(c.text)}</button>`
      + (c.disabled && c.reason
        ? `<span class="ludus-mission-reason">${esc(c.reason)}</span>` : '')
      + (c.cue ? `<span class="ludus-mission-cue">${esc(c.cue)}</span>` : '')
      + '</div>';
  }

  // The panel shows a source in its Russian form (data/source-labels-
  // ru.json, ludus-source-labels.js); the data keeps the original, and
  // a source without a label is shown as it is.
  function sourceLine(src) {
    const L = root.LudusSourceLabels;
    const shown = L ? L.labelRu(ui.labels, src) : src;
    return src ? `<p class="ludus-mission-source">Источник: ${esc(shown)}</p>`
      : '';
  }

  function renderFall(fs) {
    const g = game();
    const a = actions();
    const kept = g && root.LudusActions && root.LudusActions.keptToday
      ? (id) => root.LudusActions.keptToday(a, id, isoDay()) : () => false;
    const sober = SOBRIETY.map((s) => '<button type="button"'
      + ' class="ludus-mission-choice" data-action="mission-sober"'
      + ` data-practice-id="${s.id}"${fs.sober || kept(s.id)
        ? ' disabled' : ''}>${esc(s.label)}</button>`).join('');
    return '<section class="ludus-fall" role="status"'
      + ' aria-labelledby="ludus-fall-h">'
      + '<h4 id="ludus-fall-h">Свет приглушён</h4>'
      + `<p>Помысел (${esc(fs.passionRu)}) взял своё. Это не проигрыш: `
      + 'дорога ждёт.</p>'
      + '<p>Закрыто: ' + fs.closed.map(esc).join('; ') + '.</p>'
      + `<p class="ludus-mission-cue">Его признак: ${esc(fs.cue)}</p>`
      + '<ol class="ludus-fall-steps">'
      + `<li class="${fs.sober ? 'is-done' : ''}">Трезвение: `
      + `${fs.sober ? 'сделано' : 'одно из двух'}`
      + `<div class="ludus-mission-actions">${sober}</div></li>`
      + `<li class="${fs.taught ? 'is-done' : ''}">Разговор с наставником: `
      + `${esc(fs.teacherRu)}${fs.taught ? ' — был' : ''}`
      + '<div class="ludus-mission-actions"><button type="button"'
      + ' class="ludus-mission-choice" data-action="mission-mentor"'
      + ` data-npc-id="${esc(fs.teacher)}"${fs.taught ? ' disabled' : ''}>`
      + `Поговорить: ${esc(fs.teacherRu)}</button></div></li>`
      + '</ol>'
      + sourceLine(fs.source)
      + '</section>';
  }

  function renderCatalog(cat) {
    const status = { done: 'пройдена', current: 'в пути', next: 'следующая',
      locked: 'впереди', chorus: 'на переписке у хора' };
    return '<details class="ludus-mission-acts"><summary>Все акты и '
      + 'миссии</summary>'
      + cat.map((act) => '<section class="ludus-mission-act'
        + `${act.lock ? ' is-locked' : ''}" data-act-id="${esc(act.id)}">`
        + `<h5>${esc(act.title)}${act.complete ? ' — пройден' : ''}</h5>`
        + (act.lock ? `<p class="ludus-mission-reason">${esc(act.lock)}</p>`
          : '')
        + '<ol>' + act.missions.map((m) => '<li class="ludus-mission-item'
          + ` is-${m.status}" data-mission-id="${m.id}">${m.id}. `
          + `${esc(m.title)} <span>(${status[m.status]})</span></li>`)
          .join('') + '</ol></section>').join('')
      + '</details>';
  }

  function render() {
    const box = document.getElementById('ludus-missions');
    if (!box) {
      return;
    }
    if (!ui.ctx) {
      box.innerHTML = '';
      return;
    }
    const ctx = ui.ctx;
    const f = form();
    const a = actions();
    const fs = fallStatus(ctx, ui.state, a);
    paintLight();
    let body = '';
    const v = view(ctx, ui.state, f, a);
    if (v) {
      const s = v.step;
      const sc = v.scene;
      body = `<article class="ludus-mission-card is-${s.kind}"`
        + ` data-mission-id="${v.mission.id}" data-step="${v.index}"`
        + ` data-kind="${s.kind}"${s.node ? ` data-node="${esc(s.node)}"`
          : ''}>`
        + `<h4>${v.mission.id}. ${esc(v.mission.title)}</h4>`
        + `<p class="ludus-mission-intro">${esc(v.mission.intro)}</p>`
        + `<p class="ludus-mission-step">Шаг ${v.index + 1} из ${v.total}: `
        + `${esc(v.kindRu)}</p>`
        + `<h5>${esc(s.title)}</h5>`
        + `<p class="ludus-mission-text" data-voice="${esc(s.voice || '')}">`
        + `${esc(s.text)}</p>`
        + sourceLine(s.source);
      if (sc) {
        body += '<div class="ludus-mission-scene" aria-live="polite">'
          + `<p class="ludus-mission-chosen">— ${esc(sc.choice)}</p>`
          + (sc.speaker ? `<p class="ludus-mission-speaker">${
            esc(sc.speaker)}:</p>` : '')
          + `<p class="ludus-mission-reply">${esc(sc.text)}</p>`
          + sourceLine(sc.source)
          + '<div class="ludus-mission-actions"><button type="button"'
          + ' class="ludus-mission-next" data-action="mission-next">'
          + `${v.last ? 'Завершить миссию' : 'Дальше'}</button></div>`
          + '</div>';
      } else {
        body += '<div class="ludus-mission-actions">'
          + s.choices.map((c) => choiceButton(c, 'mission-choice')).join('')
          + '</div>';
      }
      body += '</article>';
    } else {
      const next = nextMission(ctx.spine, ui.state);
      if (next) {
        const m = buildMission(ctx, next);
        const can = canStart(ctx, ui.state, next);
        body = '<article class="ludus-mission-card is-start"'
          + ` data-mission-id="${m.id}">`
          + `<p class="ludus-mission-step">${esc(m.actTitle)}</p>`
          + `<h4>${m.id}. ${esc(m.title)}</h4>`
          + `<p class="ludus-mission-intro">${esc(m.intro)}</p>`
          + sourceLine(m.source)
          + '<div class="ludus-mission-actions"><button type="button"'
          + ' class="ludus-mission-next" data-action="mission-start"'
          + ` data-mission-id="${m.id}"${can.ok ? '' : ' disabled'}>`
          + 'Выйти в путь</button>'
          + (can.ok ? '' : `<span class="ludus-mission-reason">${
            esc(can.reason)}</span>`)
          + '</div></article>';
      } else {
        const lockAct = catalog(ctx, ui.state).find((act) => act.lock
          && !act.complete);
        body = '<p class="ludus-mission-intro">'
          + (lockAct ? `${esc(lockAct.title)}: ${esc(lockAct.lock)}.`
            : 'Все миссии, что можно пройти, пройдены.') + '</p>';
      }
    }
    box.innerHTML = '<section class="ludus-missions"'
      + ' aria-labelledby="ludus-missions-h">'
      + '<h3 id="ludus-missions-h">Дорога обители</h3>'
      + (fs.fallen ? renderFall(fs) : '')
      + (ui.lastScene ? `<p class="ludus-mission-done" role="status">${
        esc(ui.lastScene)}</p>` : '')
      + body
      + renderCatalog(catalog(ctx, ui.state))
      + '</section>';
  }

  function isoDay() {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  }

  function emit(name, detail) {
    document.dispatchEvent(new CustomEvent(name, { detail }));
  }

  function commit(next) {
    ui.state = next;
    save();
    render();
  }

  // Effects go through the game module, which owns FORM and the rule
  // and already syncs them (guest storage or /api/ludus/actions).
  function applyEffects(effects) {
    const g = game();
    if (!g) {
      return;
    }
    if (effects.meet && g.recordMeeting) {
      g.recordMeeting(effects.meet);
    }
    if (effects.practice && g.doPractice) {
      g.doPractice(effects.practice);
    }
    if (Object.keys(effects.bonuses).length && g.applyBonuses) {
      g.applyBonuses(effects.bonuses);
    }
    if (effects.fall) {
      emit('ludus:fall', { passion: effects.fall });
    }
  }

  // Lifting is checked whenever the rule or FORM changes: the watch or
  // the talk may be done from the rule panel or the mentor cards too.
  function checkLift() {
    if (!ui.ctx || !ui.state.fall) {
      return;
    }
    const a = actions();
    if (fallStatus(ui.ctx, ui.state, a).canLift) {
      ui.state = liftFall(ui.ctx, ui.state, a);
      ui.lastScene = 'Свет вернулся. Закрытые пути снова открыты.';
      save();
      emit('ludus:fall-lifted', {});
      const g = game();
      if (g && g.refreshGates) {
        g.refreshGates();
      }
    }
  }

  function onClick(event) {
    const target = event.target instanceof Element
      ? event.target.closest('[data-action]') : null;
    if (!target || !ui.ctx || target.disabled) {
      return;
    }
    const action = target.getAttribute('data-action');
    const f = form();
    const a = actions();
    if (action === 'mission-start') {
      ui.lastScene = null;
      commit(start(ui.ctx, ui.state,
        Number(target.getAttribute('data-mission-id'))));
    } else if (action === 'mission-choice') {
      const res = choose(ui.ctx, ui.state,
        target.getAttribute('data-choice-id'), f, a);
      ui.state = res.state;
      save();
      applyEffects(res.effects);
      render();
    } else if (action === 'mission-next') {
      const res = advance(ui.ctx, ui.state);
      if (res.completed) {
        ui.lastScene = `Миссия ${res.completed} пройдена.`;
        emit('ludus:mission-completed', { missionId: res.completed });
      }
      commit(res.state);
    } else if (action === 'mission-sober') {
      const g = game();
      if (g && g.doPractice) {
        g.doPractice(target.getAttribute('data-practice-id'));
      }
    } else if (action === 'mission-mentor') {
      const g = game();
      if (g && g.talkTo) {
        g.talkTo(target.getAttribute('data-npc-id'));
      }
    }
  }

  // The threshold opens in a dialog above the game, like the rights
  // register; nothing about it is a quiz, so no answer is marked wrong.
  function openTrial(gateId) {
    if (!ui.ctx) {
      return;
    }
    ui.trialGate = gateId;
    ui.trialReply = null;
    let dialog = document.getElementById('ludus-trial');
    if (!dialog) {
      dialog = document.createElement('dialog');
      dialog.id = 'ludus-trial';
      dialog.className = 'ludus-trial';
      dialog.setAttribute('aria-labelledby', 'ludus-trial-h');
      dialog.addEventListener('click', onTrialClick);
      dialog.addEventListener('cancel', (event) => {
        event.preventDefault();
        closeTrial();
      });
      document.body.append(dialog);
    }
    renderTrial();
    if (!dialog.open) {
      dialog.showModal();
    }
  }

  function closeTrial() {
    const dialog = document.getElementById('ludus-trial');
    if (dialog) {
      dialog.close();
      dialog.remove();
    }
    ui.trialGate = null;
    render();
  }

  function renderTrial() {
    const dialog = document.getElementById('ludus-trial');
    const tv = trialView(ui.ctx, ui.state, ui.trialGate, form(), actions());
    if (!dialog || !tv) {
      return;
    }
    const t = tv.trial;
    let body = `<p class="ludus-trial-scene">${esc(t.scene_ru)}</p>`
      + sourceLine(t.source);
    if (ui.trialReply) {
      body += '<div class="ludus-mission-scene" aria-live="polite">'
        + `<p class="ludus-mission-chosen">— ${esc(ui.trialReply.choice)}</p>`
        + `<p class="ludus-mission-reply">${esc(ui.trialReply.text)}</p>`
        + sourceLine(ui.trialReply.source) + '</div>';
    } else if (tv.passed) {
      body += '<p class="ludus-mission-reply">Этот порог уже позади.</p>';
    } else if (!tv.open) {
      body += '<p>Порог ещё не виден. Сначала:</p><ul>'
        + tv.missing.map((m) => `<li>${esc(m)}</li>`).join('') + '</ul>';
    } else {
      if (tv.waiting) {
        body += '<p class="ludus-mission-reason">Сперва поговори: '
          + `${esc(tv.mentorRu)}.</p>`;
      }
      body += '<div class="ludus-mission-actions">'
        + tv.options.map((o) => choiceButton(o, 'trial-choice')).join('')
        + '</div>';
    }
    dialog.innerHTML = `<h3 id="ludus-trial-h">${esc(t.title_ru)}</h3>`
      + body
      + '<div class="ludus-mission-actions"><button type="button"'
      + ' class="ludus-mission-next" data-action="trial-close">'
      + 'Отойти от порога</button></div>';
  }

  function onTrialClick(event) {
    const target = event.target instanceof Element
      ? event.target.closest('[data-action]') : null;
    if (!target || target.disabled) {
      return;
    }
    const action = target.getAttribute('data-action');
    if (action === 'trial-close') {
      closeTrial();
      return;
    }
    if (action !== 'trial-choice') {
      return;
    }
    const res = chooseTrial(ui.ctx, ui.state, ui.trialGate,
      target.getAttribute('data-choice-id'), form(), actions());
    if (!res.outcome) {
      return;
    }
    ui.state = res.state;
    save();
    ui.trialReply = { choice: target.textContent, text: res.reply,
      source: res.source };
    if (res.outcome === 'fall') {
      emit('ludus:fall', { passion: res.passion });
    }
    emit('ludus:gate-trial', { gateId: ui.trialGate,
      outcome: res.outcome });
    renderTrial();
    render();
    const g = game();
    if (g && g.refreshGates) {
      g.refreshGates();
    }
  }

  async function refresh(detail) {
    const id = detail && detail.playerId;
    if (id !== undefined && id !== ui.playerId) {
      ui.playerId = id;
      load();
    }
    try {
      await loadData();
    } catch (error) {
      const box = document.getElementById('ludus-missions');
      if (box) {
        box.innerHTML = '<p class="ludus-empty">Дорогу сейчас не '
          + 'прочесть. Обнови страницу.</p>';
      }
      console.warn('[Ludus] Missions data unavailable:', error.message);
      return;
    }
    checkLift();
    render();
  }

  document.addEventListener('ludus:player-changed', (e) => {
    refresh(e.detail);
  });
  document.addEventListener('ludus:action', () => {
    checkLift();
    render();
  });
  document.addEventListener('ludus:gate-selected', async (e) => {
    const gateId = resolveGate(e.detail);
    if (!gateId) {
      return;
    }
    await refresh();
    openTrial(gateId);
  });
  document.addEventListener('click', (event) => {
    const box = document.getElementById('ludus-missions');
    if (box && event.target instanceof Node && box.contains(event.target)) {
      onClick(event);
    }
  });

  root.LudusMissionsUI = {
    hasPassed: (gateId) => Boolean(ui.state.trials[gateId]),
    isFallen: () => Boolean(ui.state.fall),
    openTrial,
    render,
  };
})(typeof window !== 'undefined' ? window : null);
