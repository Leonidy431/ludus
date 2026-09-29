/**
 * vr.js — сюжетная панель VR-сцены «Двор Герата» (Путь дьякона).
 * Вынесен из инлайна vr.html (реестр п.78: файл превысил 20KB) — проход №45.
 * Кэшируется отдельно от HTML; логика без изменений.
 */
(function () {
  'use strict';
  var statusEl = document.getElementById('vr-status');
  var fallback = document.getElementById('vr-fallback');
  var fallbackMsg = document.getElementById('vr-fallback-msg');

  // Реестр п.39: локализация панели/сцены — та же дисциплина, что GAME_STRINGS/
  // gt() в game.js (панель игры), сюда портирован тот же паттерн под отдельным
  // именем (vr.js — независимый скрипт, своя область видимости). Ключ языка —
  // тот же localStorage 'wt2GameLang', что и весь остальной чехол игры (единый
  // выбор языка на сайте, без второго переключателя внутри VR). Блок-метки
  // (VR_BLOCK_I18N) — дословно те же переводы, что BLOCK_LABELS_I18N в game.js,
  // чтобы термины совпадали, а не расходились по двум файлам.
  var VR_LANG_KEY = 'wt2GameLang';
  var VR_UI_LANGS = ['ru', 'en', 'cu', 'el', 'fr', 'zh', 'sw'];
  var _vrLang = 'ru';
  try {
    var _storedVrLang = localStorage.getItem(VR_LANG_KEY);
    if (_storedVrLang && VR_UI_LANGS.indexOf(_storedVrLang) !== -1) _vrLang = _storedVrLang;
  } catch (e) {}

  var VR_STRINGS = {
    sceneUnavailable: { ru: 'VR-сцена недоступна — текстовый путь открыт', en: 'VR scene unavailable — the text path is open', cu: 'Позо́рище недоступно — пꙋ́ть кни́жный ѿве́рстъ', el: 'Η σκηνή VR δεν είναι διαθέσιμη — το κείμενο παραμένει ανοιχτό', fr: 'Scène VR indisponible — le chemin textuel reste ouvert', zh: 'VR场景不可用 — 文字路径仍然开放', sw: 'Eneo la VR halipatikani — njia ya maandishi iko wazi' },
    engineFailed: { ru: 'Движок VR не загрузился. Сюжет полностью доступен в текстовой игре.', en: 'The VR engine failed to load. The story is fully available in the text game.', cu: 'Дви́гатель позо́рища не возгорѣ́сѧ. Пови́сть всѧ̀ до́ступна въ кни́жнѣй и҆грѣ̀.', el: 'Ο κινητήρας VR δεν φορτώθηκε. Η ιστορία είναι πλήρως διαθέσιμη στο κειμενικό παιχνίδι.', fr: "Le moteur VR n'a pas pu se charger. L'histoire reste entièrement disponible dans le jeu textuel.", zh: 'VR引擎加载失败。故事在文字游戏中完全可用。', sw: 'Injini ya VR haikupakia. Hadithi inapatikana kikamilifu katika mchezo wa maandishi.' },
    noWebgl: { ru: 'Браузер не смог создать 3D-контекст. Откройте страницу в браузере шлема Quest.', en: 'The browser could not create a 3D context. Open the page in the Quest headset browser.', cu: 'Прогля́датель не возможѐ сотвори́ти три́мѣрный ѡ҆бра́зъ. Ѿве́рзи страни́цꙋ въ прогля́дателѣ шле́ма Quest.', el: 'Ο περιηγητής δεν μπόρεσε να δημιουργήσει τρισδιάστατο περιβάλλον. Ανοίξτε τη σελίδα στο πρόγραμμα περιήγησης του Quest.', fr: "Le navigateur n'a pas pu créer de contexte 3D. Ouvrez la page dans le navigateur du casque Quest.", zh: '浏览器无法创建3D环境。请在Quest头显浏览器中打开此页面。', sw: 'Kivinjari hakikuweza kuunda mazingira ya 3D. Fungua ukurasa kwenye kivinjari cha kifaa cha Quest.' },
    contextLost: { ru: '3D-контекст потерян (устройство перегружено). Перезагрузите страницу — сюжет доступен в текстовой игре.', en: '3D context lost (device overloaded). Reload the page — the story remains available in the text game.', cu: 'Три́мѣрный ѡ҆бра́зъ поги́бе (ѻ҆рꙋ́дїе ѡ҆тѧготи́сѧ). Возобновѝ страни́цꙋ — пови́сть до́ступна въ кни́жнѣй и҆грѣ̀.', el: 'Απώλεια τρισδιάστατου περιβάλλοντος (η συσκευή υπερφορτώθηκε). Επαναφορτώστε τη σελίδα — η ιστορία παραμένει διαθέσιμη στο κειμενικό παιχνίδι.', fr: "Contexte 3D perdu (appareil surchargé). Rechargez la page — l'histoire reste disponible dans le jeu textuel.", zh: '3D环境丢失（设备过载）。请重新加载页面 — 故事在文字游戏中仍可用。', sw: 'Mazingira ya 3D yamepotea (kifaa kimezidiwa). Pakia upya ukurasa — hadithi bado inapatikana katika mchezo wa maandishi.' },
    contextRestored: { ru: '3D-контекст восстановлен — двор оживает…', en: '3D context restored — the court comes alive…', cu: 'Три́мѣрный ѡ҆бра́зъ возста́ви сѧ — дво́ръ ѡ҆живае́тъ…', el: 'Το τρισδιάστατο περιβάλλον αποκαταστάθηκε — η αυλή ζωντανεύει…', fr: 'Contexte 3D restauré — la cour reprend vie…', zh: '3D环境已恢复 — 庭院正在苏醒…', sw: 'Mazingira ya 3D yamerejeshwa — ua unahuisha…' },
    offline: { ru: 'Нет сети — сцена работает, свиток обновится при возврате связи', en: 'No connection — the scene still works, the scroll will refresh once the link returns', cu: 'Нѣ́сть сꙋ́пряги — позо́рище дѣ́йствꙋетъ, сви́токъ возновится по возвраще́нїи сꙋ́вѧзи', el: 'Χωρίς σύνδεση — η σκηνή λειτουργεί, ο κύλινδρος θα ανανεωθεί όταν επανέλθει η σύνδεση', fr: "Pas de connexion — la scène fonctionne, le rouleau se mettra à jour au retour du réseau", zh: '无网络连接 — 场景仍可运行，网络恢复后卷轴将自动更新', sw: 'Hakuna mtandao — eneo bado linafanya kazi, hati itasasishwa mtandao ukirudi' },
    online: { ru: 'Связь вернулась • нажмите VR в правом нижнем углу', en: 'Connection restored • tap VR in the bottom-right corner', cu: 'Сꙋ́вѧзь возврати́сѧ • при́коснисѧ VR въ дне́снѣмъ ни́жнѣмъ ᲂу҆глѣ̀', el: 'Η σύνδεση επανήλθε • πατήστε VR κάτω δεξιά', fr: 'Connexion rétablie • appuyez sur VR en bas à droite', zh: '网络已恢复 • 点击右下角的VR按钮', sw: 'Mtandao umerudi • gusa VR kwenye kona ya chini kulia' },
    ready: { ru: 'Двор Герата • нажмите VR в правом нижнем углу (в шлеме Quest)', en: 'The Court of Herat • tap VR in the bottom-right corner (in the Quest headset)', cu: 'Дво́ръ Гера́тскїй • при́коснисѧ VR въ дне́снѣмъ ни́жнѣмъ ᲂу҆глѣ̀ (въ шле́мѣ Quest)', el: 'Η Αυλή του Ηράτ • πατήστε VR κάτω δεξιά (στο ακουστικό Quest)', fr: 'La Cour de Hérat • appuyez sur VR en bas à droite (dans le casque Quest)', zh: '赫拉特宫廷 • 点击右下角的VR按钮（在Quest头显中）', sw: 'Uwanja wa Herat • gusa VR kwenye kona ya chini kulia (kwenye kifaa cha Quest)' },
    loading: { ru: 'Двор Герата грузится… ', en: 'The Court of Herat is loading… ', cu: 'Дво́ръ Гера́тскїй гото́витсѧ… ', el: 'Η Αυλή του Ηράτ φορτώνεται… ', fr: 'La Cour de Hérat se charge… ', zh: '赫拉特宫廷加载中… ', sw: 'Uwanja wa Herat unapakia… ' },
    loadingSlow: { ru: ' (первый заход дольше — движок уходит в кэш)', en: ' (the first visit is slower — the engine is caching)', cu: ' (пе́рвый вни́дъ дли́ннѣйшїй — дви́гатель полага́етсѧ въ храни́лище)', el: ' (η πρώτη επίσκεψη είναι πιο αργή — ο κινητήρας αποθηκεύεται σε cache)', fr: " (la première visite est plus lente — le moteur se met en cache)", zh: '（首次进入较慢 — 引擎正在缓存）', sw: ' (ziara ya kwanza ni polepole — injini inahifadhiwa)' },
    missionPrefix: { ru: 'Миссия #', en: 'Mission #', cu: 'По́сланїе №', el: 'Αποστολή #', fr: 'Mission n° ', zh: '任务 #', sw: 'Utume #' },
    caravanReady: { ru: 'Караван готов — слушай двор.', en: 'The caravan is ready — listen to the court.', cu: 'Карава́нъ гото́въ — послꙋ́шай дво́ръ.', el: 'Το καραβάνι είναι έτοιμο — ακούστε την αυλή.', fr: 'La caravane est prête — écoutez la cour.', zh: '商队已准备好 — 聆听庭院。', sw: 'Msafara uko tayari — sikiliza ua.' },
    khanName: { ru: 'Хан', en: 'Khan', cu: 'Ха́нъ', el: 'Χάνος', fr: 'Khan', zh: '可汗', sw: 'Khan' },
    npcLineAria: { ru: 'Реплика: ', en: 'Line: ', cu: 'Ре́чь: ', el: 'Ατάκα: ', fr: 'Réplique : ', zh: '台词：', sw: 'Msemo: ' },
    dailyClaimBtn: { ru: '⚡ Задание дня: +', en: '⚡ Daily task: +', cu: '⚡ Дне́вное дѣ́ло: +', el: '⚡ Καθημερινό καθήκον: +', fr: '⚡ Tâche du jour : +', zh: '⚡ 每日任务：+', sw: '⚡ Kazi ya siku: +' },
    dailyClaimSuffix: { ru: ' Ⰾ — получить', en: ' Ⰾ — claim', cu: ' Ⰾ — прїѧ́ти', el: ' Ⰾ — λάβετε', fr: ' Ⰾ — recevoir', zh: ' Ⰾ — 领取', sw: ' Ⰾ — pokea' },
    dailyClaimedPrefix: { ru: '✓ Получено: +', en: '✓ Claimed: +', cu: '✓ Прїѧ́то: +', el: '✓ Ελήφθη: +', fr: '✓ Reçu : +', zh: '✓ 已领取：+', sw: '✓ Imepokelewa: +' },
    dailyClaimedSuffix: { ru: ' Ⰾ', en: ' Ⰾ', cu: ' Ⰾ', el: ' Ⰾ', fr: ' Ⰾ', zh: ' Ⰾ', sw: ' Ⰾ' },
    dailyUnavailable: { ru: 'Задание дня недоступно', en: 'Daily task unavailable', cu: 'Дне́вное дѣ́ло недосѧжи́мо', el: 'Το καθημερινό καθήκον δεν είναι διαθέσιμο', fr: 'Tâche du jour indisponible', zh: '每日任务不可用', sw: 'Kazi ya siku haipatikani' },
    refreshUpdating: { ru: '⌛ Обновляется…', en: '⌛ Updating…', cu: '⌛ Возновлѧ́етсѧ…', el: '⌛ Ενημερώνεται…', fr: '⌛ Mise à jour…', zh: '⌛ 更新中…', sw: '⌛ Inasasishwa…' },
    voiceListening: { ru: '🔴 Слушаю…', en: '🔴 Listening…', cu: '🔴 Слꙋ́шаю…', el: '🔴 Ακούω…', fr: '🔴 Écoute…', zh: '🔴 聆听中…', sw: '🔴 Ninasikiliza…' },
    // ── Заставка (проход №58, «сделай заставку игры красиво»).
    splashTitle: { ru: 'Путь дьякона', en: 'The Deacon’s Path', cu: 'Пꙋ́ть дїа́кона', el: 'Η Οδός του Διακόνου', fr: 'La Voie du diacre', zh: '辅祭之路', sw: 'Njia ya Shemasi' },
    splashSub: { ru: 'Двор Герата · Шёлковый путь', en: 'The Court of Herat · The Silk Road', cu: 'Дво́ръ Гера́тскїй · Пꙋ́ть Ше́лковый', el: 'Η Αυλή του Ηράτ · Ο Δρόμος του Μεταξιού', fr: 'La Cour de Hérat · La Route de la soie', zh: '赫拉特宫廷 · 丝绸之路', sw: 'Uwanja wa Herat · Njia ya Hariri' },
    splashEnter: { ru: '✠ Войти во двор', en: '✠ Enter the court', cu: '✠ Вни́ти во дво́ръ', el: '✠ Είσοδος στην αυλή', fr: '✠ Entrer dans la cour', zh: '✠ 进入庭院', sw: '✠ Ingia uani' },
    // ── Диалог героев (проход №58, «npc диалоги персонажей и героев главнее»).
    dlgAskPath: { ru: '🧭 Спросить о пути', en: '🧭 Ask about the road', cu: '🧭 Вопроси́ти ѡ҆ пꙋтѝ', el: '🧭 Ρώτησε για τον δρόμο', fr: '🧭 Demander la route', zh: '🧭 询问路途', sw: '🧭 Uliza kuhusu njia' },
    dlgAskCity: { ru: '🏰 Спросить о Герате', en: '🏰 Ask about Herat', cu: '🏰 Вопроси́ти ѡ҆ Гера́тѣ', el: '🏰 Ρώτησε για το Ηράτ', fr: '🏰 Demander Hérat', zh: '🏰 询问赫拉特', sw: '🏰 Uliza kuhusu Herat' },
    dlgBow: { ru: '🙏 Поклониться и отойти', en: '🙏 Bow and step away', cu: '🙏 Поклони́тисѧ и҆ ѿитѝ', el: '🙏 Υποκλίσου και αποχώρησε', fr: '🙏 Saluer et se retirer', zh: '🙏 行礼告退', sw: '🙏 Inama na uondoke' },
    dlgThinking: { ru: '…собирается с мыслями…', en: '…gathering their thoughts…', cu: '…собира́етъ помышлє́нїѧ…', el: '…συγκεντρώνει τις σκέψεις του…', fr: '…rassemble ses pensées…', zh: '…正在沉思…', sw: '…anakusanya mawazo…' },
    dlgCloseAria: { ru: 'Закрыть диалог', en: 'Close dialogue', cu: 'Затвори́ти бесѣ́дꙋ', el: 'Κλείσιμο διαλόγου', fr: 'Fermer le dialogue', zh: '关闭对话', sw: 'Funga mazungumzo' },
    roleKhan: { ru: 'повелитель степи', en: 'lord of the steppe', cu: 'влады́ка сте́пи', el: 'κύριος της στέπας', fr: 'seigneur de la steppe', zh: '草原之主', sw: 'bwana wa nyika' },
    // Проход №59 (марафон до 99): зоны 24/30/38/40/47/50.
    splashContinue: { ru: '✠ Продолжить путь', en: '✠ Continue the path', cu: '✠ Продолжи́ти пꙋ́ть', el: '✠ Συνέχισε την πορεία', fr: '✠ Poursuivre la route', zh: '✠ 继续旅程', sw: '✠ Endelea na njia' },
    splashLegend: { ru: 'Говорят, звезда пути зажигается для тех, кто идёт не за золотом.', en: 'They say the star of the path lights up for those who walk not after gold.', cu: 'Глаго́лютъ, ꙗ҆́кѡ ѕвѣзда̀ пꙋтѝ возжига́етсѧ и҆дꙋ́щымъ не зла́та ра́ди.', el: 'Λένε πως το άστρο του δρόμου ανάβει για όσους δεν βαδίζουν για το χρυσάφι.', fr: 'On dit que l’étoile du chemin s’allume pour ceux qui ne marchent pas vers l’or.', zh: '据说，路途之星只为不逐金而行的人点亮。', sw: 'Wanasema nyota ya njia huwaka kwa wale wasiofuata dhahabu.' },
    dlgFarewell: { ru: 'Мир твоему пути.', en: 'Peace to your road.', cu: 'Ми́ръ пꙋтѝ твоемꙋ̀.', el: 'Ειρήνη στον δρόμο σου.', fr: 'Paix sur ta route.', zh: '愿你一路平安。', sw: 'Amani njiani mwako.' },
    dlgLive: { ru: 'живое слово двора', en: 'a living word of the court', cu: 'живо́е сло́во двора̀', el: 'ζωντανός λόγος της αυλής', fr: 'parole vivante de la cour', zh: '庭院的活言', sw: 'neno hai la ua' },
    dlgLore: { ru: 'предание двора', en: 'lore of the court', cu: 'преда́нїе двора̀', el: 'παράδοση της αυλής', fr: 'tradition de la cour', zh: '庭院的传闻', sw: 'mapokeo ya ua' },
    dlgBowsAll: { ru: 'Двор запомнил твою учтивость: каждому здесь ты поклонился.', en: 'The court remembers your courtesy: you have bowed to everyone here.', cu: 'Дво́ръ помѧнꙋ̀ ᲂу҆чти́вость твою̀: комꙋ́ждо здѣ̀ поклони́лсѧ є҆сѝ.', el: 'Η αυλή θυμάται την ευγένειά σου: υποκλίθηκες σε όλους εδώ.', fr: 'La cour se souvient de ta courtoisie : tu as salué chacun ici.', zh: '庭院记住了你的谦恭：你已向这里的每个人行礼。', sw: 'Ua umekumbuka adabu yako: umeinamia kila mmoja hapa.' },
    heraldName: { ru: 'Глашатай', en: 'Herald', cu: 'Проповѣ́дникъ', el: 'Κήρυκας', fr: 'Héraut', zh: '传令官', sw: 'Mtangazaji' },
    roleHerald: { ru: 'вестник двора', en: 'crier of the court', cu: 'вѣ́стникъ двора̀', el: 'αγγελιοφόρος της αυλής', fr: 'messager de la cour', zh: '庭院信使', sw: 'mjumbe wa ua' },
    ttsAria: { ru: 'Озвучить реплику', en: 'Speak the line aloud', cu: 'Возгласи́ти ре́чь', el: 'Εκφώνησε την ατάκα', fr: 'Lire la réplique', zh: '朗读台词', sw: 'Soma msemo kwa sauti' },
  };
  // Зона 12: ролевой вопрос per герой — ярлык (7 языков) + повод серверу (RU,
  // модель повествует по-русски; ярлык — язык панели).
  var VR_NPC_ROLEQ = {
    khan: { label: { ru: '🐎 О степи', en: '🐎 On the steppe', cu: '🐎 Ѡ҆ сте́пи', el: '🐎 Για τη στέπα', fr: '🐎 La steppe', zh: '🐎 谈草原', sw: '🐎 Kuhusu nyika' }, ctx: 'игрок спрашивает хана о степи и её законах' },
    sargis: { label: { ru: '🐫 О караване', en: '🐫 The caravan', cu: '🐫 Ѡ҆ карава́нѣ', el: '🐫 Για το καραβάνι', fr: '🐫 La caravane', zh: '🐫 谈商队', sw: '🐫 Kuhusu msafara' }, ctx: 'игрок спрашивает караван-баши о караване и дороге' },
    vardan: { label: { ru: '📖 О книгах', en: '📖 On books', cu: '📖 Ѡ҆ кни́гахъ', el: '📖 Για τα βιβλία', fr: '📖 Les livres', zh: '📖 谈书卷', sw: '📖 Kuhusu vitabu' }, ctx: 'игрок спрашивает переписчика о книгах и письме' },
    melik: { label: { ru: '⚖️ О податях', en: '⚖️ On taxes', cu: '⚖️ Ѡ҆ да́нехъ', el: '⚖️ Για τους φόρους', fr: '⚖️ Les impôts', zh: '⚖️ 谈赋税', sw: '⚖️ Kuhusu kodi' }, ctx: 'игрок спрашивает наместника о податях и заботах квартала' },
    tabib: { label: { ru: '🌿 О травах', en: '🌿 On herbs', cu: '🌿 Ѡ҆ бы́лїихъ', el: '🌿 Για τα βότανα', fr: '🌿 Les herbes', zh: '🌿 谈草药', sw: '🌿 Kuhusu mitishamba' }, ctx: 'игрок спрашивает лекаря о травах и врачевании' },
    strazhnik: { label: { ru: '🛡 О воротах', en: '🛡 The gates', cu: '🛡 Ѡ҆ вратѣ́хъ', el: '🛡 Για τις πύλες', fr: '🛡 Les portes', zh: '🛡 谈城门', sw: '🛡 Kuhusu malango' }, ctx: 'игрок спрашивает стражника о воротах и порядке в городе' },
    anahit: { label: { ru: '🏠 О доме', en: '🏠 The house', cu: '🏠 Ѡ҆ до́мѣ', el: '🏠 Για το σπίτι', fr: '🏠 La maison', zh: '🏠 谈家宅', sw: '🏠 Kuhusu nyumba' }, ctx: 'игрок спрашивает хозяйку караван-сарая о доме и постояльцах' },
    herald: { label: { ru: '📯 Что нового?', en: '📯 What news?', cu: '📯 Что̀ но́ваго;', el: '📯 Τι νέα;', fr: '📯 Quelles nouvelles ?', zh: '📯 有何消息？', sw: '📯 Habari gani?' }, ctx: 'глашатай объявляет новости двора и дорог' },
  };

  // ── Статические реплики героев на 7 языках (проход №58): первый запуск
  // работает даже без бэкенда — клик по герою всегда даёт голос в характере.
  // Персонажи и характеры — канон llamaNarrator.ts (HERAT_NPCS), не выдумка.
  var VR_NPC_FALLBACK = {
    khan: { ru: 'Говори. Степь длинна, а слово должно быть коротким.', en: 'Speak. The steppe is long; a word must be short.', cu: 'Глаго́ли. Сте́пь до́лга, сло́во же да бꙋ́детъ кра́тко.', el: 'Μίλα. Η στέπα είναι μακριά· ο λόγος πρέπει να είναι σύντομος.', fr: 'Parle. La steppe est longue, la parole doit être brève.', zh: '说吧。草原漫长，话语当短。', sw: 'Sema. Nyika ni ndefu; neno liwe fupi.' },
    sargis: { ru: 'Дорога до Иссык-Куля — сорок узелков на моём шнуре. Считай сам.', en: 'The road to Issyk-Kul is forty knots on my cord. Count them yourself.', cu: 'Пꙋ́ть до І҆ссы́къ-Кꙋ́лѧ — четы́редесѧть ᲂу҆зло́въ на ве́рвїи мое́мъ.', el: 'Ο δρόμος για το Ισίκ-Κουλ είναι σαράντα κόμποι στο σχοινί μου.', fr: 'La route d’Issyk-Koul, c’est quarante nœuds sur ma corde.', zh: '到伊塞克湖的路，是我绳上的四十个结。', sw: 'Njia ya Issyk-Kul ni mafundo arobaini kwenye kamba yangu.' },
    vardan: { ru: 'Утром переписывал псалом о путях — и вот путь сам входит в двери.', en: 'This morning I copied a psalm about roads — and now the road walks through my door.', cu: 'Оу҆́тромъ преписа́хъ ѱало́мъ ѡ҆ пꙋте́хъ — и҆ сѐ пꙋ́ть са́мъ вхо́дитъ въ две̑ри.', el: 'Το πρωί αντέγραφα ψαλμό για δρόμους — και να, ο δρόμος μπαίνει στην πόρτα μου.', fr: 'Ce matin je copiais un psaume sur les chemins — et voici que le chemin entre chez moi.', zh: '清晨我抄写关于道路的诗篇——如今道路自己走进了门。', sw: 'Asubuhi nilinakili zaburi ya njia — na sasa njia yenyewe inaingia mlangoni.' },
    melik: { ru: 'Квартал спокоен, подати уплачены. Чего ещё желать наместнику?', en: 'The quarter is quiet, the taxes are paid. What more could a governor wish for?', cu: 'Живꙋ́щїи въ ми́рѣ, да̑ни ѿда́ны. Чесо̀ є҆щѐ жела́ти намѣ́стникꙋ;', el: 'Η συνοικία είναι ήσυχη, οι φόροι πληρωμένοι. Τι άλλο να ευχηθεί ένας διοικητής;', fr: 'Le quartier est calme, les impôts payés. Que souhaiter de plus ?', zh: '街区安宁，赋税已缴。总督还能求什么呢？', sw: 'Mtaa uko shwari, kodi zimelipwa. Mtawala atake nini zaidi?' },
    tabib: { ru: 'Сядь, путник. Сначала — вода и тень, потом — разговоры.', en: 'Sit down, traveller. First water and shade, then talk.', cu: 'Сѧ́ди, пꙋ́тниче. Пре́жде — вода̀ и҆ сѣ́нь, та́же — бесѣ̑ды.', el: 'Κάθισε, οδοιπόρε. Πρώτα νερό και σκιά, ύστερα κουβέντες.', fr: 'Assieds-toi, voyageur. D’abord l’eau et l’ombre, ensuite les paroles.', zh: '坐下吧，旅人。先饮水乘凉，再谈话。', sw: 'Keti, msafiri. Kwanza maji na kivuli, kisha mazungumzo.' },
    // Зоны 19/20/30: стражник, хозяйка караван-сарая, глашатай (событие дня).
    strazhnik: { ru: 'Ворота открыты до третьей стражи. После — только со словом хана.', en: 'The gates stay open till the third watch. After that — only with the Khan’s word.', cu: 'Врата̀ ѿвє́рста до тре́тїѧ стра́жи. По се́мъ — то́чїю со сло́вомъ ха́новымъ.', el: 'Οι πύλες μένουν ανοιχτές ως την τρίτη βάρδια. Μετά — μόνο με τον λόγο του Χάνου.', fr: 'Les portes restent ouvertes jusqu’à la troisième veille. Ensuite — seulement sur parole du Khan.', zh: '城门开到三更。之后——须有可汗之令。', sw: 'Malango yako wazi hadi zamu ya tatu. Baada ya hapo — kwa neno la Khan tu.' },
    anahit: { ru: 'Очаг тёплый, вода свежая. Расскажи, что видел на дороге, путник.', en: 'The hearth is warm, the water fresh. Tell me what you saw on the road, traveller.', cu: 'Ѻ҆гни́ще те́пло, вода̀ свѣжа̀. Повѣ́ждь, что̀ ви́дѣлъ є҆сѝ на пꙋтѝ, пꙋ́тниче.', el: 'Η εστία είναι ζεστή, το νερό φρέσκο. Πες μου τι είδες στον δρόμο, οδοιπόρε.', fr: 'Le foyer est chaud, l’eau est fraîche. Dis-moi ce que tu as vu en chemin, voyageur.', zh: '炉火正暖，清水正凉。旅人，说说你路上的见闻吧。', sw: 'Meko ni moto, maji ni safi. Niambie uliyoyaona njiani, msafiri.' },
    herald: { ru: 'Слушайте! Караваны с юга прошли перевал — базар ждёт вестей и товара.', en: 'Hear ye! The caravans from the south have crossed the pass — the bazaar awaits news and goods.', cu: 'Слы́шите! Карава́ни ѿ ю҆́га преидо́ша прева́лъ — то́ржище жде́тъ вѣсте́й и҆ това́ра.', el: 'Ακούστε! Τα καραβάνια από τον νότο πέρασαν το ορεινό πέρασμα — το παζάρι περιμένει νέα και εμπορεύματα.', fr: 'Oyez ! Les caravanes du sud ont franchi le col — le bazar attend nouvelles et marchandises.', zh: '听着！南方的商队已过山口——集市正等待消息与货物。', sw: 'Sikilizeni! Misafara kutoka kusini imevuka mlima — soko linasubiri habari na bidhaa.' },
  };
  // Зона 36: второй голос пула — при повторном обращении герой не повторяется
  // слово в слово (ротация случайная между основной и запасной репликой).
  var VR_NPC_FALLBACK2 = {
    khan: { ru: 'Садись. Чай остынет быстрее, чем степь простит болтуна.', en: 'Sit. The tea will cool faster than the steppe forgives a chatterer.' },
    sargis: { ru: 'Верблюд не спорит с дорогой. Учись у верблюда.', en: 'The camel does not argue with the road. Learn from the camel.' },
    vardan: { ru: 'Чернила дороже вина: вино веселит вечер, чернила — века.', en: 'Ink is dearer than wine: wine cheers an evening, ink — the centuries.' },
    melik: { ru: 'Тихий квартал — заслуга не стражи, а соседей, что здороваются.', en: 'A quiet quarter is not the guard’s doing, but of neighbours who greet one another.' },
    tabib: { ru: 'Дорога лечит одних и ломает других. Пей воду и держись первых.', en: 'The road heals some and breaks others. Drink water and keep with the first.' },
    strazhnik: { ru: 'Смотрю не на лица — на руки. Руки говорят раньше слов.', en: 'I watch not faces but hands. Hands speak before words.' },
    anahit: { ru: 'Постоялец, что хвалит хлеб, получает и мёд.', en: 'A guest who praises the bread receives honey as well.' },
    herald: { ru: 'Слушайте! На колодцах северной дороги вновь есть вода.', en: 'Hear ye! The wells of the northern road hold water again.' },
  };
  // Локальный канон-ростер для офлайн-режима (имена/роли — те же, что отдаёт
  // GET /narrator/npcs; хан добавляется всегда первым, как в loadNpcRow).
  // Зона 32 (решение хора-32, зафиксировано): имена собственные героев НЕ
  // переводятся — русская канон-форма во всех языках панели; роли локализуются
  // на бэкенд-этапе позже (словарь: docs/ru/СЛОВАРЬ_ГЕРОЕВ_ИГРЫ.md).
  var VR_NPC_STATIC = [
    { id: 'sargis', name: 'Саргис', role: 'караван-баши' },
    { id: 'vardan', name: 'Вардан', role: 'переписчик' },
    { id: 'melik', name: 'мелик Ашот', role: 'наместник квартала' },
    { id: 'tabib', name: 'Мар-Ава', role: 'лекарь-несторианин' },
    { id: 'strazhnik', name: 'Тагай', role: 'стражник ворот' },
    { id: 'anahit', name: 'Анаит', role: 'хозяйка караван-сарая' },
  ];
  // VR_BLOCK_I18N — дословно BLOCK_LABELS_I18N из game.js (та же таблица,
  // не переизобретена, чтобы термины совпадали на дашборде и в VR-панели).
  var VR_BLOCK_I18N = {
    trade:      { ru: '🐫 Торговля и миссия', en: '🐫 Trade & Mission', cu: '🐫 Кꙋ́пля и҆ по́сланїе', el: '🐫 Εμπόριο και Αποστολή', fr: '🐫 Commerce et Mission', zh: '🐫 贸易与使命', sw: '🐫 Biashara na Utume' },
    spiritual:  { ru: '✝️ Духовно-символическое', en: '✝️ Spiritual & Symbolic', cu: '✝️ Дꙋхо́вное и҆ зна́менное', el: '✝️ Πνευματικό και Συμβολικό', fr: '✝️ Spirituel et symbolique', zh: '✝️ 灵性与象征', sw: '✝️ Kiroho na Ishara' },
    hydrology:  { ru: '🌊 Вода и климат', en: '🌊 Water & Climate', cu: '🌊 Вода̀ и҆ воздꙋ́хъ', el: '🌊 Νερό και Κλίμα', fr: '🌊 Eau et climat', zh: '🌊 水与气候', sw: '🌊 Maji na Hali ya Hewa' },
    diplomacy:  { ru: '🤝 Политика и дипломатия', en: '🤝 Politics & Diplomacy', cu: '🤝 Гра́жданство и҆ посо́льство', el: '🤝 Πολιτική και Διπλωματία', fr: '🤝 Politique et diplomatie', zh: '🤝 政治与外交', sw: '🤝 Siasa na Diplomasia' },
    craft:      { ru: '🔨 Ремёсла и технологии', en: '🔨 Crafts & Technology', cu: '🔨 Хꙋдо́жества и҆ хи́трости', el: '🔨 Τέχνες και Τεχνολογία', fr: '🔨 Artisanat et technologie', zh: '🔨 工艺与技术', sw: '🔨 Ufundi na Teknolojia' },
    narrative:  { ru: '📜 Память и наследие', en: '📜 Memory & Legacy', cu: '📜 Па́мѧть и҆ наслѣ́дїе', el: '📜 Μνήμη και Κληρονομιά', fr: '📜 Mémoire et héritage', zh: '📜 记忆与传承', sw: '📜 Kumbukumbu na Urithi' },
  };
  function vgt(key) {
    var row = VR_STRINGS[key];
    if (!row) return key;
    return row[_vrLang] || row.ru;
  }
  function vBlockLabel(b) {
    var row = VR_BLOCK_I18N[b];
    return row ? (row[_vrLang] || row.ru) : b;
  }
  // Реестр п.39: локализация статических подписей vr.html (заголовок панели,
  // кнопки, чекбокс, HUD-метки, требования) — один проход по фиксированному
  // списку id/атрибутов при первой загрузке. Fail-open: отсутствующий элемент
  // просто пропускается (querySelector вернёт null, чтения .textContent нет).
  var VR_STATIC_STRINGS = {
    ru: { statusInit: 'Двор Герата загружается…', backToText: '← вернуться в текстовую игру', questHint: 'Для объёма: Meta Quest Browser (Quest 2/3/3S), страница по HTTPS. В обычном браузере сцена видна плоско, VR-кнопка не появится.', panelShow: '📜 Свиток', panelTitle: 'Свиток пути', heightAria: 'Переключить высоту панели (сидя/стоя)', fontDecAria: 'Уменьшить шрифт панели', fontIncAria: 'Увеличить шрифт панели', hideAria: 'Скрыть панель (полное погружение)', hudRep: '🕊 репутация', hudPath: '🧭 путь', narrLabel: 'живые реплики двора', refreshBtn: '⟳ Обновить свиток', backLink: '← в текстовую игру', voiceAria: 'Голосовой ввод: скажите «обновить»', voiceWord: 'обновить' },
    en: { statusInit: 'The Court of Herat is loading…', backToText: '← back to the text game', questHint: 'For immersion: Meta Quest Browser (Quest 2/3/3S), page over HTTPS. In a regular browser the scene is shown flat, no VR button appears.', panelShow: '📜 Scroll', panelTitle: 'Scroll of the Path', heightAria: 'Toggle panel height (seated/standing)', fontDecAria: 'Decrease panel font size', fontIncAria: 'Increase panel font size', hideAria: 'Hide panel (full immersion)', hudRep: '🕊 reputation', hudPath: '🧭 path', narrLabel: 'live court remarks', refreshBtn: '⟳ Refresh scroll', backLink: '← back to the text game', voiceAria: 'Voice input: say "refresh"', voiceWord: 'refresh' },
    cu: { statusInit: 'Дво́ръ Гера́тскїй гото́витсѧ…', backToText: '← возврати́тисѧ въ кни́жнꙋю и҆грꙋ̀', questHint: 'Ра́ди погрꙋже́нїѧ: Meta Quest Browser (Quest 2/3/3S), страни́ца по HTTPS. Во ѻ҆бы́чнѣмъ прогля́дателѣ позо́рище пло́ско, кно́пка VR не ꙗ҆ви́тсѧ.', panelShow: '📜 Сви́токъ', panelTitle: 'Сви́токъ пꙋти̑', heightAria: 'Премѣни́ти высотꙋ̀ панели (сѣдѧ́щи/стоѧ́щи)', fontDecAria: 'Оу҆ма́лити пи́сьмо панели', fontIncAria: 'Возвели́чити пи́сьмо панели', hideAria: 'Скры́ти панель (по́лное погруже́нїе)', hudRep: '🕊 сла́ва', hudPath: '🧭 пꙋ́ть', narrLabel: 'живы̑ рѣ́чи двора̀', refreshBtn: '⟳ Возновѝ сви́токъ', backLink: '← въ кни́жнꙋю и҆грꙋ̀', voiceAria: 'Гла́съ вхо́дный: рцы̀ «возновѝ»', voiceWord: 'возновѝ' },
    el: { statusInit: 'Η Αυλή του Ηράτ φορτώνεται…', backToText: '← επιστροφή στο κειμενικό παιχνίδι', questHint: 'Για εμβάπτιση: Meta Quest Browser (Quest 2/3/3S), σελίδα μέσω HTTPS. Σε κανονικό πρόγραμμα περιήγησης η σκηνή εμφανίζεται επίπεδη, δεν εμφανίζεται κουμπί VR.', panelShow: '📜 Κύλινδρος', panelTitle: 'Κύλινδρος της Πορείας', heightAria: 'Εναλλαγή ύψους πάνελ (καθιστός/όρθιος)', fontDecAria: 'Μείωση μεγέθους γραμματοσειράς πάνελ', fontIncAria: 'Αύξηση μεγέθους γραμματοσειράς πάνελ', hideAria: 'Απόκρυψη πάνελ (πλήρης εμβάπτιση)', hudRep: '🕊 φήμη', hudPath: '🧭 πορεία', narrLabel: 'ζωντανές ατάκες της αυλής', refreshBtn: '⟳ Ανανέωση κυλίνδρου', backLink: '← στο κειμενικό παιχνίδι', voiceAria: 'Φωνητική είσοδος: πείτε «ανανέωση»', voiceWord: 'ανανέωση' },
    fr: { statusInit: 'La Cour de Hérat se charge…', backToText: '← retour au jeu textuel', questHint: "Pour l'immersion : Meta Quest Browser (Quest 2/3/3S), page en HTTPS. Dans un navigateur classique, la scène s'affiche à plat, aucun bouton VR n'apparaît.", panelShow: '📜 Rouleau', panelTitle: 'Rouleau du chemin', heightAria: 'Basculer la hauteur du panneau (assis/debout)', fontDecAria: 'Réduire la taille de police du panneau', fontIncAria: 'Augmenter la taille de police du panneau', hideAria: 'Masquer le panneau (immersion totale)', hudRep: '🕊 réputation', hudPath: '🧭 chemin', narrLabel: 'répliques vivantes de la cour', refreshBtn: '⟳ Actualiser le rouleau', backLink: '← retour au jeu textuel', voiceAria: 'Saisie vocale : dites « actualiser »', voiceWord: 'actualiser' },
    zh: { statusInit: '赫拉特宫廷加载中…', backToText: '← 返回文字游戏', questHint: '沉浸提示：Meta Quest浏览器（Quest 2/3/3S），页面需通过HTTPS。在普通浏览器中场景将以平面显示，不会出现VR按钮。', panelShow: '📜 卷轴', panelTitle: '道路卷轴', heightAria: '切换面板高度（坐姿/站姿）', fontDecAria: '缩小面板字号', fontIncAria: '放大面板字号', hideAria: '隐藏面板（完全沉浸）', hudRep: '🕊 声望', hudPath: '🧭 路程', narrLabel: '庭院实时台词', refreshBtn: '⟳ 刷新卷轴', backLink: '← 返回文字游戏', voiceAria: '语音输入：说"刷新"', voiceWord: '刷新' },
    sw: { statusInit: 'Uwanja wa Herat unapakia…', backToText: '← rudi kwenye mchezo wa maandishi', questHint: 'Kwa uzoefu kamili: Meta Quest Browser (Quest 2/3/3S), ukurasa kupitia HTTPS. Kwenye kivinjari cha kawaida eneo linaonekana bapa, kitufe cha VR hakitaonekana.', panelShow: '📜 Hati', panelTitle: 'Hati ya Njia', heightAria: 'Badilisha urefu wa jopo (kukaa/kusimama)', fontDecAria: 'Punguza ukubwa wa fonti ya jopo', fontIncAria: 'Ongeza ukubwa wa fonti ya jopo', hideAria: 'Ficha jopo (uzamiaji kamili)', hudRep: '🕊 sifa', hudPath: '🧭 njia', narrLabel: 'misemo hai ya ua', refreshBtn: '⟳ Sasisha hati', backLink: '← rudi kwenye mchezo wa maandishi', voiceAria: 'Ingizo la sauti: sema "sasisha"', voiceWord: 'sasisha' },
  };
  function vStatic(key) {
    var row = VR_STATIC_STRINGS[_vrLang] || VR_STATIC_STRINGS.ru;
    return row[key] != null ? row[key] : VR_STATIC_STRINGS.ru[key];
  }
  function localizeStaticVr() {
    var setText = function (id, key) { var el = document.getElementById(id); if (el) el.textContent = vStatic(key); };
    var setAria = function (id, key) { var el = document.getElementById(id); if (el) el.setAttribute('aria-label', vStatic(key)); };
    setText('vr-status', 'statusInit');
    setText('vr-fallback-back', 'backToText');
    setText('vr-quest-hint-text', 'questHint');
    setText('vr-panel-show', 'panelShow');
    var titleSpan = document.getElementById('vr-panel-title-text');
    if (titleSpan) titleSpan.textContent = vStatic('panelTitle');
    setAria('vr-panel-height', 'heightAria');
    setAria('vr-font-dec', 'fontDecAria');
    setAria('vr-font-inc', 'fontIncAria');
    setAria('vr-panel-hide', 'hideAria');
    setText('vr-hud-rep-label', 'hudRep');
    setText('vr-hud-path-label', 'hudPath');
    setText('vr-narr-auto-label', 'narrLabel');
    setText('vr-refresh', 'refreshBtn');
    setText('vr-back-link', 'backLink');
    setAria('vr-voice', 'voiceAria');
    // Проход №58: заставка + диалог героев — те же VR_STRINGS/vgt.
    var setVgt = function (id, key) { var el = document.getElementById(id); if (el) el.textContent = vgt(key); };
    setVgt('vr-splash-title', 'splashTitle');
    setVgt('vr-splash-sub', 'splashSub');
    setVgt('vr-splash-enter', 'splashEnter');
    setVgt('vr-dlg-ask-path', 'dlgAskPath');
    setVgt('vr-dlg-ask-city', 'dlgAskCity');
    setVgt('vr-dlg-bow', 'dlgBow');
    var dlgClose = document.getElementById('vr-dialog-close');
    if (dlgClose) dlgClose.setAttribute('aria-label', vgt('dlgCloseAria'));
    var ttsBtn = document.getElementById('vr-dialog-tts');
    if (ttsBtn) ttsBtn.setAttribute('aria-label', vgt('ttsAria'));
    // Зона 79: селект отражает текущий язык панели.
    var langSel = document.getElementById('vr-lang-select');
    if (langSel) langSel.value = _vrLang;
    // Зона 47: возвращающемуся игроку — «Продолжить путь» (кэш миссии есть).
    try {
      if (localStorage.getItem('vrLastMission')) {
        var ent = document.getElementById('vr-splash-enter');
        if (ent) ent.textContent = vgt('splashContinue');
      }
    } catch (e) {}
  }
  try { document.addEventListener('DOMContentLoaded', localizeStaticVr); } catch (e) {}

  // ── Заставка (проход №58): титульный лист, вход по явному жесту игрока
  // (user gesture — заодно снимает браузерные ограничения WebXR/аудио).
  // Сцена, движок и данные грузятся ПОД заставкой параллельно — кнопка
  // активна сразу, вход мгновенный. Fail-open: нет элементов — нет заставки.
  (function initSplash() {
    var splash = document.getElementById('vr-splash');
    var enter = document.getElementById('vr-splash-enter');
    if (!splash || !enter) return;
    var hidden = false;
    // Зона 48: тихая строка прогресса движка прямо на заставке — зеркалит
    // #vr-status, пока заставка видна (без своего механизма загрузки).
    var mirrorT = setInterval(function () {
      var st = document.getElementById('vr-status');
      var out = document.getElementById('vr-splash-status');
      if (st && out) out.textContent = st.textContent;
    }, 700);
    function hideSplash() {
      if (hidden) return;
      hidden = true;
      hapticPulse();
      if (mirrorT) { clearInterval(mirrorT); mirrorT = null; }
      startAmbient(); // зона 46: жест получен — эмбиент двора разрешён
      splash.classList.add('splash-hide'); // плавное растворение (CSS .9s)
      setTimeout(function () { splash.hidden = true; }, 950);
    }
    enter.addEventListener('click', hideSplash);
    splash.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' || e.key === 'Enter') hideSplash();
    });
    // Зона 50: пасхалка — удержание эмблемы 3с открывает байку двора.
    var emblem = splash.querySelector('.splash-emblem');
    if (emblem) {
      var holdT = null;
      var holdStart = function () {
        holdT = setTimeout(function () {
          var out = document.getElementById('vr-splash-status');
          if (out) out.textContent = vgt('splashLegend');
        }, 3000);
      };
      var holdEnd = function () { if (holdT) { clearTimeout(holdT); holdT = null; } };
      emblem.addEventListener('pointerdown', holdStart);
      emblem.addEventListener('pointerup', holdEnd);
      emblem.addEventListener('pointerleave', holdEnd);
    }
    try { enter.focus(); } catch (e) {}
  })();

  // ── Зоны 46/58: процедурный эмбиент двора (WebAudio, без файлов) — тихий
  // степной ветер (фильтрованный шум) + редкий дальний колокольчик. Запуск
  // ТОЛЬКО после жеста игрока (кнопка заставки); mute — кнопка 🔈, помнится.
  var _ambient = null;
  var _muted = false;
  try { _muted = localStorage.getItem('vrMuted') === '1'; } catch (e) {}
  function startAmbient() {
    if (_ambient || _muted) return;
    try {
      var Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      var ctx = new Ctx();
      var master = ctx.createGain();
      master.gain.value = 0.05; // очень тихо — фон, не музыка
      master.connect(ctx.destination);
      // Ветер: зацикленный буфер шума через низкочастотный фильтр.
      var len = ctx.sampleRate * 4;
      var buf = ctx.createBuffer(1, len, ctx.sampleRate);
      var d = buf.getChannelData(0);
      for (var i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * 0.6;
      var src = ctx.createBufferSource();
      src.buffer = buf; src.loop = true;
      var filt = ctx.createBiquadFilter();
      filt.type = 'lowpass'; filt.frequency.value = 320; filt.Q.value = 0.6;
      src.connect(filt); filt.connect(master); src.start();
      // Колокольчик: раз в ~25-45с короткий затухающий тон.
      var bellT = setInterval(function () {
        if (Math.random() > 0.55) return;
        try {
          var o = ctx.createOscillator();
          var g = ctx.createGain();
          o.type = 'sine'; o.frequency.value = 620 + Math.random() * 240;
          g.gain.setValueAtTime(0.10, ctx.currentTime);
          g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 2.4);
          o.connect(g); g.connect(master);
          o.start(); o.stop(ctx.currentTime + 2.5);
        } catch (e) {}
      }, 30000);
      _ambient = { ctx: ctx, bellT: bellT };
    } catch (e) { /* fail-open: без звука сцена живёт как раньше */ }
  }
  function stopAmbient() {
    if (!_ambient) return;
    try { clearInterval(_ambient.bellT); _ambient.ctx.close(); } catch (e) {}
    _ambient = null;
  }
  (function wireMute() {
    var btn = document.getElementById('vr-mute');
    if (!btn) return;
    function paint() {
      btn.textContent = _muted ? '🔇' : '🔈';
      btn.setAttribute('aria-pressed', _muted ? 'true' : 'false');
    }
    paint();
    btn.addEventListener('click', function () {
      _muted = !_muted;
      try { localStorage.setItem('vrMuted', _muted ? '1' : '0'); } catch (e) {}
      if (_muted) stopAmbient(); else startAmbient();
      paint();
      hapticPulse();
    });
  })();
  // Зоны 79/82: язык панели из VR (перезагрузка — честный полный переклад)
  // и режим лёгкого чтения (класс на панели, помнится).
  (function wireLangAndDys() {
    var sel = document.getElementById('vr-lang-select');
    if (sel) sel.addEventListener('change', function () {
      try { localStorage.setItem(VR_LANG_KEY, sel.value); } catch (e) {}
      location.reload();
    });
    var dys = document.getElementById('vr-dys');
    var panel = document.getElementById('vr-panel');
    if (dys && panel) {
      var on = false;
      try { on = localStorage.getItem('vrDys') === '1'; } catch (e) {}
      if (on) panel.classList.add('vr-dys');
      dys.setAttribute('aria-pressed', on ? 'true' : 'false');
      dys.addEventListener('click', function () {
        on = !on;
        panel.classList.toggle('vr-dys', on);
        dys.setAttribute('aria-pressed', on ? 'true' : 'false');
        try { localStorage.setItem('vrDys', on ? '1' : '0'); } catch (e) {}
      });
    }
  })();

  function degrade(msg) {
    // Fail-open: любой отказ — внятная сцена, не белый экран.
    fallbackMsg.textContent = msg;
    fallback.style.display = 'block';
    statusEl.textContent = vgt('sceneUnavailable');
    console.error('[VR] ' + msg);
  }

  // 1) Движок Needle — SELF-HOSTED (гуру-проход №34): CSP сайта
  //    (`script-src 'self' …`, firebase.json) блокирует внешние CDN, и это
  //    правильно — поэтому стабильный @needle-tools/engine@5.1.12 (dist
  //    *.min.js + LICENSE.md) вендорен в /vr/vendor/needle/. Никакой
  //    внешней загрузки; лицензионный гейт перед продом (ТЗ §6.4) не
  //    меняется — vendoring лишь способ доставки того же кода.
  // Глобал, который min-сборка Needle ожидает от их бандлера; при
  // self-hosting задаём пустым (некоммерческий tier, водяной знак).
  window.NEEDLE_PUBLIC_KEY = '';
  var s = document.createElement('script');
  s.type = 'module';
  s.src = '/vr/vendor/needle/needle-engine.min.js';
  s.onerror = function () {
    degrade(vgt('engineFailed'));
  };
  document.head.appendChild(s);

  window.addEventListener('error', function (e) {
    if (String(e.message || '').indexOf('WebGL') !== -1) {
      degrade(vgt('noWebgl'));
    }
  });
  // Реестр 99, п.23 (проход №40): потеря GL-контекста (перегрев/фон шлема)
  // ловится напрямую на canvas сцены, не только по тексту ошибки.
  document.addEventListener('webglcontextlost', function () {
    degrade(vgt('contextLost'));
  }, true);
  // Реестр п.29 (проход №52): восстановление после потери контекста.
  // Честная граница: пересоздание движка — зона Needle (three.js сам
  // восстанавливает ресурсы по webglcontextrestored); наш вклад — убрать
  // деградацию-виньетку и вернуть статус, чтобы игрок видел, что сцена
  // ожила, а не остался на «перезагрузите страницу» при живом рендере.
  document.addEventListener('webglcontextrestored', function () {
    fallback.style.display = 'none';
    statusEl.textContent = vgt('contextRestored');
    console.log('[VR] webglcontextrestored — деградация снята');
  }, true);
  // Реестр 99, п.43: честный статус при пропаже/возврате сети.
  window.addEventListener('offline', function () {
    statusEl.textContent = vgt('offline');
  });
  window.addEventListener('online', function () {
    if (engineReady) statusEl.textContent = vgt('online');
  });

  // Реестр п.8 (проход №47): ?from=<tab> — все ссылки «← в текстовую игру»
  // возвращают на ту вкладку, с которой пришли (game.js читает ?tab=).
  try {
    var _fromTab = new URLSearchParams(location.search).get('from');
    if (['campaign', 'market', 'gifts', 'workshop', 'khan', 'pvp'].indexOf(_fromTab) !== -1) {
      document.addEventListener('DOMContentLoaded', function () {
        var links = document.querySelectorAll('a[href="/"]');
        for (var i = 0; i < links.length; i++) links[i].href = '/?tab=' + _fromTab;
      });
    }
  } catch (e) {}

  // Реестр п.94 (проход №50): ночной режим по локальному времени игрока —
  // 21:00–06:00 приглушаем сцену/фоллбэк (CSS-класс, стили в vr.html).
  // Чисто косметика, fail-open; prefers-contrast:more отменяет фильтр.
  try {
    var _hr = new Date().getHours();
    if (_hr >= 21 || _hr < 6) document.documentElement.classList.add('vr-night');
  } catch (e) {}

  var engineReady = false;
  function markReady() {
    engineReady = true;
    if (_loadTicker) { clearInterval(_loadTicker); _loadTicker = null; } // п.25
    statusEl.textContent = vgt('ready');
    reportVrAchievement('vr-visited'); // п.98, проход №58
    loadCharacterProps(); // проход №62: 3D-пропы ПОСЛЕ готовности сцены (C1)
    loadNatureProps(); // проход №61 (ТЗ_МИР_ПРИРОДА): деревья + звёздное небо
  }
  // Имя события зависит от версии движка: v5 шлёт 'loadfinished' на самом
  // элементе, старые сборки — 'needle-engine-loaded' на document. Слушаем
  // оба + страховочный опрос shadow-canvas (движок реально поднялся, даже
  // если ни одно событие не долетело) — fail-open косметика статуса.
  document.addEventListener('needle-engine-loaded', markReady);
  document.addEventListener('DOMContentLoaded', function () {
    var el = document.querySelector('needle-engine');
    if (el) { el.addEventListener('loadfinished', markReady); el.addEventListener('needle-engine-loaded', markReady); }
  });
  var canvasPoll = setInterval(function () {
    var el = document.querySelector('needle-engine');
    if (el && el.shadowRoot && el.shadowRoot.querySelector('canvas')) { clearInterval(canvasPoll); markReady(); }
  }, 1500);
  setTimeout(function () { clearInterval(canvasPoll); }, 60000);
  // Реестр п.25 (проход №52): индикатор загрузки — ЧЕСТНЫЙ секундомер
  // (реально прошедшие секунды), не выдуманный процент: события прогресса
  // Needle не документированы, а фейковый прогресс-бар запрещён духом
  // «never simulate». Обновление раз в 2с с 4-й секунды до готовности;
  // гасится в markReady() и на pagehide.
  // Проход №62 (C1, спринт-манифест 2026-08-20): догрузка 3D-пропов
  // персонажей (vr-assets/props/character-items-01.glb — весы Саргиса,
  // чернильница Вардана, ступка Табиба; узлы ObjVesy/ObjChernilnitsa/
  // ObjStupka) СТРОГО ПОСЛЕ markReady() — первый кадр основной сцены
  // (gerat.glb) не ждёт этот файл. Механика: динамический import того же
  // самого вендоренного ES-модуля Needle (браузер вернёт уже загруженный
  // модуль из кэша — второй сетевой загрузки движка нет), затем
  // Context.Current → getLoader().loadSync(ctx, url) → ctx.scene.add().
  // Fail-open ПОЛНОСТЬЮ: пропы — аддитивная косметика; любой сбой здесь
  // (не тот API-шейп у минифицированной сборки, отсутствие контекста,
  // битый glb) — только console.warn, НИКОГДА не degrade(): основная
  // сцена уже работает, и ломать её статус из-за декора нельзя.
  var _propsLoadStarted = false;
  function loadCharacterProps() {
    if (_propsLoadStarted) return; // one-shot: markReady() многоканален
    _propsLoadStarted = true;
    // Небольшая пауза после готовности — не конкурировать с первыми
    // кадрами/инициализацией XR за главный поток.
    setTimeout(function () {
      try {
        import('/vr/vendor/needle/needle-engine.min.js').then(function (mod) {
          var tries = 0;
          var poll = setInterval(function () {
            tries++;
            var ctx = null;
            try { ctx = mod.Context && mod.Context.Current; } catch (e) {}
            if (!ctx || !ctx.scene) {
              if (tries > 15) { clearInterval(poll); console.warn('[VR] props: Context.Current не появился — пропы пропущены (fail-open)'); }
              return;
            }
            clearInterval(poll);
            _addPropsToScene(mod, ctx);
          }, 2000);
        }).catch(function (e) {
          console.warn('[VR] props: import модуля Needle не удался — пропы пропущены', e);
        });
      } catch (e) {
        console.warn('[VR] props: динамический import недоступен — пропы пропущены', e);
      }
    }, 2000);
  }
  function _addPropsToScene(mod, ctx) {
    try {
      var url = 'vr-assets/props/character-items-01.glb';
      var loader = null;
      try { loader = mod.getLoader && mod.getLoader(); } catch (e) {}
      var p = null;
      if (loader && typeof loader.loadSync === 'function') {
        p = loader.loadSync(ctx, url);
      } else if (typeof mod.loadAsset === 'function') {
        // Запасной путь: публичный loadAsset (сигнатура может отличаться
        // между сборками — потому в try/catch и с проверкой результата).
        p = mod.loadAsset(url, { context: ctx });
      }
      if (!p || typeof p.then !== 'function') {
        console.warn('[VR] props: у сборки Needle нет ожидаемого loader-API — пропы пропущены (fail-open)');
        return;
      }
      p.then(function (res) {
        try {
          var obj = res && (res.scene || res);
          if (!obj || typeof obj.traverse !== 'function' || !obj.position) {
            console.warn('[VR] props: результат загрузки не похож на Object3D — пропы пропущены');
            return;
          }
          // Узлы в glb авторски стоят в (0,0,0) — расставляем во дворе
          // тройкой перед точкой обзора (умбра-двор gerat.glb, y=0 земля).
          var spots = {
            ObjVesy: [-1.2, 0, -2.2],
            ObjChernilnitsa: [0, 0, -2.6],
            ObjStupka: [1.2, 0, -2.2]
          };
          obj.traverse(function (n) {
            var s = n && n.name && spots[n.name];
            if (s && n.position) n.position.set(s[0], s[1], s[2]);
          });
          ctx.scene.add(obj);
          console.log('[VR] props: 3 предмета персонажей добавлены в сцену (character-items-01.glb)');
        } catch (e) {
          console.warn('[VR] props: вставка в сцену не удалась — пропущено', e);
        }
      }).catch(function (e) {
        console.warn('[VR] props: загрузка glb не удалась — пропущено', e);
      });
    } catch (e) {
      console.warn('[VR] props: неожиданная ошибка — пропущено', e);
    }
  }

  // Проход №61 (ТЗ_МИР_ПРИРОДА_ХОДЬБА_ГЕРАТ, разделы I «Небо и свет» +
  // II «Деревья и растительность»): наполняем пустой двор процедурной
  // природой БЕЗ новых .glb-файлов — все примитивы строятся прямо из
  // вендоренного three-core.min.js (Cone/Cylinder/Points — реальные
  // классы three.js, экспортированы под настоящими именами через `as`,
  // проверено статически перед правкой). Тот же самый уже загруженный
  // ES-модуль движка, второй сетевой загрузки нет.
  // Fail-open ПОЛНОСТЬЮ, как и character-props: любой сбой — console.warn,
  // НИКОГДА не degrade() — это чистая аддитивная косметика поверх уже
  // рабочей сцены (gerat.glb), не критический путь.
  var _natureLoadStarted = false;
  function loadNatureProps() {
    if (_natureLoadStarted) return; // one-shot
    _natureLoadStarted = true;
    setTimeout(function () {
      try {
        Promise.all([
          import('/vr/vendor/needle/needle-engine.min.js'),
          import('/vr/vendor/needle/three-core.min.js'),
        ]).then(function (mods) {
          var needleMod = mods[0];
          var THREE = mods[1];
          var tries = 0;
          var poll = setInterval(function () {
            tries++;
            var ctx = null;
            try { ctx = needleMod.Context && needleMod.Context.Current; } catch (e) {}
            if (!ctx || !ctx.scene) {
              if (tries > 15) { clearInterval(poll); console.warn('[VR] nature: Context.Current не появился — природа пропущена (fail-open)'); }
              return;
            }
            clearInterval(poll);
            _addNatureToScene(THREE, ctx);
          }, 2000);
        }).catch(function (e) {
          console.warn('[VR] nature: import модулей не удался — природа пропущена', e);
        });
      } catch (e) {
        console.warn('[VR] nature: динамический import недоступен — природа пропущена', e);
      }
    }, 2500); // чуть позже character-props (2000мс) — не конкурировать за главный поток
  }

  function _addNatureToScene(THREE, ctx) {
    // II. Деревья — стилизованные кипарисы (конус кроны + цилиндр ствола),
    // умбра+золото канон (docs/ru/АРТ_ПРОМПТЫ_КАРТЫ_И_КОСТИ_2026-08-17.md §9.0):
    // тёмная охра ствола, приглушённый зелёно-золотой конуса кроны, чтобы не
    // спорить с золотом стен. Позиции — по периметру двора, за пределами уже
    // занятой character-props зоны (z от -2.2 до -2.6) и точки обзора игрока.
    try {
      if (!THREE.ConeGeometry || !THREE.CylinderGeometry || !THREE.MeshStandardMaterial || !THREE.Mesh || !THREE.Group) {
        console.warn('[VR] nature: у three-core.min.js нет ожидаемых классов геометрии — деревья пропущены');
      } else {
        var trunkMat = new THREE.MeshStandardMaterial({ color: 0x3a2410, roughness: 0.95, metalness: 0 });
        var crownMat = new THREE.MeshStandardMaterial({ color: 0x4a5a2e, roughness: 0.85, metalness: 0 });
        var treeSpots = [
          [-3.4, 0, -4.2, 1.0],
          [3.6, 0, -3.8, 0.85],
          [-4.0, 0, -1.0, 0.9],
          [4.2, 0, -1.4, 1.05],
        ];
        for (var i = 0; i < treeSpots.length; i++) {
          var sp = treeSpots[i];
          var scale = sp[3];
          var tree = new THREE.Group();
          var trunkH = 1.4 * scale;
          var trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.08 * scale, 0.11 * scale, trunkH, 6), trunkMat);
          trunk.position.set(0, trunkH / 2, 0);
          tree.add(trunk);
          var crownH = 2.2 * scale;
          var crown = new THREE.Mesh(new THREE.ConeGeometry(0.55 * scale, crownH, 8), crownMat);
          crown.position.set(0, trunkH + crownH / 2 - 0.1, 0);
          tree.add(crown);
          tree.position.set(sp[0], sp[1], sp[2]);
          ctx.scene.add(tree);
        }
        console.log('[VR] nature: 4 стилизованных кипариса добавлены во двор');
      }
    } catch (e) {
      console.warn('[VR] nature: деревья не удалось построить — пропущено', e);
    }

    // I. Небо и свет — звёздное небо: показываем ТОЛЬКО ночью (тот же
    // локальный час 21:00–06:00, что уже используют CSS-класс vr-night и
    // ночной режим фоллбэка выше) — днём звёзды над двором были бы
    // нефизичны, честная деградация распространяется и на украшения.
    try {
      var hr = new Date().getHours();
      var isNight = hr >= 21 || hr < 6;
      if (!isNight) {
        console.log('[VR] nature: день — звёздное небо не показываем (честная деградация)');
      } else if (!THREE.BufferGeometry || !THREE.Float32BufferAttribute || !THREE.PointsMaterial || !THREE.Points) {
        console.warn('[VR] nature: у three-core.min.js нет ожидаемых классов для звёзд — небо пропущено');
      } else {
        var starCount = 220;
        var positions = new Float32Array(starCount * 3);
        for (var j = 0; j < starCount; j++) {
          // Случайная точка на верхней полусфере радиуса ~28 над двором —
          // Box-Muller не нужен, равномерность по куполу тут чисто декоративна.
          var theta = Math.random() * Math.PI * 2;
          var phi = Math.random() * Math.PI * 0.42; // только верхний купол
          var r = 26 + Math.random() * 6;
          positions[j * 3] = r * Math.sin(phi) * Math.cos(theta);
          positions[j * 3 + 1] = r * Math.cos(phi) + 2;
          positions[j * 3 + 2] = r * Math.sin(phi) * Math.sin(theta);
        }
        var starGeo = new THREE.BufferGeometry();
        starGeo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
        var starMat = new THREE.PointsMaterial({
          color: 0xf0daa8, // золото канона, не холодный белый
          size: 0.09,
          sizeAttenuation: true,
          transparent: true,
          opacity: 0.85,
        });
        var stars = new THREE.Points(starGeo, starMat);
        ctx.scene.add(stars);
        console.log('[VR] nature: звёздное небо (' + starCount + ' звёзд) добавлено — ночной режим');
      }
    } catch (e) {
      console.warn('[VR] nature: звёздное небо не удалось построить — пропущено', e);
    }
  }

  var _loadT0 = Date.now();
  var _loadTicker = setInterval(function () {
    if (engineReady || fallback.style.display === 'block') {
      clearInterval(_loadTicker); _loadTicker = null; return;
    }
    var sec = Math.round((Date.now() - _loadT0) / 1000);
    if (sec >= 4) {
      statusEl.textContent = vgt('loading') + sec + 'с' +
        (sec >= 12 ? vgt('loadingSlow') : '');
    }
  }, 2000);

  // 2) Текст сюжета из СУЩЕСТВУЮЩЕГО gameApi — тем же путём, что вся
  //    игра: window.FIREBASE_CONFIG (публичный web-конфиг, идентичен
  //    public/index.html) + общий /auth.js (window.__auth.ensureSignedIn
  //    → getIdToken) — один Firebase-app на сайт, ноль новых механизмов.
  window.FIREBASE_CONFIG = {
    apiKey: 'AIzaSyBNHmoQHW8B-AygtmpJvSr5vfOVQGKz6FE',
    authDomain: 'studio-8655717756-3e0c1.firebaseapp.com',
    projectId: 'studio-8655717756-3e0c1',
    storageBucket: 'studio-8655717756-3e0c1.firebasestorage.app',
    messagingSenderId: '821778957491',
    appId: '1:821778957491:web:e6f719f8d0f0c96489dcc6',
  };

  // Реестр VR п.46: кэш последней миссии — мгновенный показ до сети,
  // фоновое обновление перезапишет. Fail-open: любая ошибка storage молчит.
  function cacheMission(m) {
    try { localStorage.setItem('vrLastMission', JSON.stringify(m)); } catch (e) {}
  }
  function showCachedMission() {
    try {
      var m = JSON.parse(localStorage.getItem('vrLastMission'));
      if (m && m.title) showMission(m, true);
    } catch (e) {}
  }

  // Реестр п.40 (проход №50): тематический блок миссии в заголовке свитка.
  // Реестр п.40 (проход №50), локализовано гуру-проходом п.39: тематический
  // блок текущей миссии — VR_BLOCK_I18N (см. верх файла) вместо жёсткого ru.

  function showMission(m, fromCache) {
    if (!fromCache) cacheMission(m);
    var bl = document.getElementById('vr-block-label');
    var blockLbl = m.block ? vBlockLabel(m.block) : '';
    if (bl) bl.textContent = blockLbl ? ' · ' + blockLbl : '';
    document.getElementById('vr-mission-title').textContent = m.title || (vgt('missionPrefix') + m.id);
    document.getElementById('vr-mission-text').textContent =
      m.narrative || m.description || vgt('caravanReady');
    document.getElementById('vr-panel').hidden = false;
  }

  // Реестр 99 слепых зон VR, п.50 (проход №56, 2026-08-20): падение в шлеме
  // раньше было полностью невидимо оператору — ни консоли (никто не подключит
  // devtools к Quest), ни строки в system_errors. window.onerror/
  // unhandledrejection ловятся здесь и уходят на существующий бэкенд-роут
  // POST /api/game/vr/error-report (severity 'warning' на сервере — тихий
  // Batch-Monitor sink, не будит Telegram/MAX/почту оператора по каждому
  // мелкому клиентскому сбою). Fail-open во всех направлениях: нет auth.js
  // ещё (ошибка до его загрузки) — отчёт просто теряется, не копится в
  // очереди; сам fetch падает — try/catch глушит; троттлинг (максимум 5 за
  // сессию) — один шумный баг не бомбардирует бэкенд из живого шлема.
  var _vrErrReportCount = 0;
  function reportVrError(message, stack, context) {
    try {
      if (_vrErrReportCount >= 5) return;
      if (!window.__auth || typeof window.__auth.getIdToken !== 'function') return;
      _vrErrReportCount++;
      window.__auth.getIdToken().then(function (token) {
        return fetch('/api/game/vr/error-report', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
          body: JSON.stringify({ message: String(message || '').slice(0, 500), stack: stack, context: context || {} }),
        });
      }).catch(function () {});
    } catch (e) {}
  }
  window.addEventListener('error', function (e) {
    reportVrError(e.message, e.error && e.error.stack, { filename: e.filename, lineno: e.lineno });
  });
  window.addEventListener('unhandledrejection', function (e) {
    var reason = e.reason;
    reportVrError(
      'unhandledrejection: ' + (reason && reason.message ? reason.message : String(reason)),
      reason && reason.stack,
    );
  });

  // Реестр п.98 (проход №58): достижение «vr-visited» — игрок реально
  // увидел двор в шлеме (engine loaded + canvas отрисован, тот же момент,
  // что markReady() уже отмечает). Идемпотентно на сервере
  // (markAchievementEarned dedup по (userId, achievementId) в транзакции),
  // здесь — просто once-флаг, чтобы не слать лишний запрос при повторных
  // markReady()-триггерах (needle-engine-loaded + loadfinished + canvasPoll
  // могут сработать все три). Fail-open: нет auth.js — тихо не отправляем.
  var _vrAchievementSent = false;
  function reportVrAchievement(achievementId) {
    try {
      if (_vrAchievementSent) return;
      if (!window.__auth || typeof window.__auth.getIdToken !== 'function') return;
      _vrAchievementSent = true;
      window.__auth.getIdToken().then(function (token) {
        return fetch('/api/game/vr/achievement', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
          body: JSON.stringify({ achievementId: achievementId }),
        });
      }).catch(function () {});
    } catch (e) {}
  }

  // ── Сюжетная панель, переиспользуемые загрузчики (проход №39, VR-1/2/4).
  // Всё fail-open: любой отказ оставляет прежнее содержимое, сцена не страдает.
  var _currentMission = null;
  var _missionsAll = []; // п.18 (проход №51): весь список для свайп-листания

  function apiGetVr(path) {
    // Реестр VR п.47: таймаут 15с — подвисший запрос в шлеме не держит панель вечно.
    var ctl = ('AbortController' in window) ? new AbortController() : null;
    var t = ctl ? setTimeout(function () { ctl.abort(); }, 15000) : null;
    return window.__auth.getIdToken().then(function (token) {
      return fetch('/api/game' + path, {
        headers: { Authorization: 'Bearer ' + token },
        signal: ctl ? ctl.signal : undefined,
      });
    }).then(function (r) {
      if (t) clearTimeout(t);
      return r.ok ? r.json() : null;
    }, function (e) {
      if (t) clearTimeout(t);
      throw e;
    });
  }

  // VR-2: HUD казна/репутация — те же источники, что stats strip дашборда.
  // Реестр п.76 (проход №46): HUD — не критический путь; откладываем его
  // запросы в idle-окно, чтобы не конкурировать с загрузкой сцены/миссии.
  function loadHud() {
    var work = function () {
      apiGetVr('/wallet').then(function (w) {
        if (w && w.wallet) document.getElementById('vr-hud-balance').textContent = w.wallet.balance;
      }).catch(function () {});
      apiGetVr('/pvp/reputation').then(function (rep) {
        if (rep && rep.reputation) document.getElementById('vr-hud-rep').textContent = rep.reputation.score;
      }).catch(function () {});
    };
    if ('requestIdleCallback' in window) requestIdleCallback(work, { timeout: 4000 });
    else setTimeout(work, 250);
  }

  // VR-4: живая реплика; счётчик отказов гасит интервал после 3 подряд —
  // не долбим мёртвый бэкенд из шлема вечно.
  var _narrFails = 0;
  var _narrTimer = null;
  var _narrHistory = []; // VR-9 (п.38)
  function loadNarration() {
    return window.__auth.getIdToken().then(function (token) {
      return fetch('/api/game/narrator', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
        body: JSON.stringify({ kind: 'khan', context: _currentMission ? _currentMission.title : undefined }),
      });
    }).then(function (r) { return r.ok ? r.json() : null; })
      .then(function (n) {
        var text = n && n.narration && n.narration.text;
        if (!text) throw new Error('empty');
        _narrFails = 0;
        var p = document.getElementById('vr-narration');
        // VR-9 (п.38): прежняя реплика уходит в приглушённую историю (до 3).
        var prev = p.textContent;
        if (prev && prev !== '« ' + text + ' »') {
          _narrHistory.unshift(prev);
          if (_narrHistory.length > 3) _narrHistory.length = 3;
          var h = document.getElementById('vr-narr-history');
          h.textContent = _narrHistory.join(' · ');
          h.hidden = false;
        }
        p.textContent = '« ' + text + ' »';
        p.hidden = false;
      })
      .catch(function () {
        _narrFails += 1;
        if (_narrFails >= 3 && _narrTimer) { clearInterval(_narrTimer); _narrTimer = null; }
      });
  }

  // Реестр п.36/37 + проход №58 («npc диалоги персонажей и героев главнее»):
  // клик по аватару героя открывает ДИАЛОГОВУЮ КАРТОЧКУ (портрет, имя, роль,
  // реплика, варианты продолжения), а не только строку в #vr-narration.
  // Fail-open на каждом шаге: без бэкенда/авторизации реплики берутся из
  // VR_NPC_FALLBACK (7 языков) — первый запуск в шлеме работает офлайн.
  var _dlgNpc = null;
  var _dlgHist = {};   // зона 10: память прошлых слов per герой (до 2)
  var _npcRoster = []; // зона 35: текущий состав для листания
  var _lastNarrAt = 0; // зона 22: клиентский кулдаун обращений к рассказчику
  // Зона 29: счётчик визитов — герой знает, впервые ли игрок здесь.
  var _visitCtx = 'игрок здесь впервые';
  try {
    var _v = (parseInt(localStorage.getItem('vrVisits'), 10) || 0) + 1;
    localStorage.setItem('vrVisits', String(_v));
    if (_v > 1) _visitCtx = 'игрок бывал во дворе уже ' + _v + ' раз';
  } catch (e) {}
  // Зоны 11/13/14/27/28/29: сборка живого контекста сцены для рассказчика.
  // Всё — только описание сцены; исходы решает сервер, не контекст.
  function sceneContext(extra) {
    var parts = [];
    if (extra) parts.push(extra);
    var h = new Date().getHours();
    parts.push(h < 5 ? 'глубокая ночь' : h < 11 ? 'утро' : h < 17 ? 'день' : h < 22 ? 'вечер' : 'ночь');
    if (document.body.classList.contains('vr-night')) parts.push('двор в ночном сумраке');
    if (_currentMission && _currentMission.title) parts.push('дело игрока: ' + _currentMission.title);
    var pathEl = document.getElementById('vr-hud-path');
    if (pathEl && /\d+\/\d+/.test(pathEl.textContent)) parts.push('пройдено миссий: ' + pathEl.textContent);
    var repEl = document.getElementById('vr-hud-rep');
    if (repEl && /^\d+$/.test(repEl.textContent.trim())) parts.push('репутация игрока при дворе: ' + repEl.textContent.trim());
    parts.push(_visitCtx);
    return parts.join('; ').slice(0, 380); // сервер режет на 400 — идём с запасом
  }
  function fetchNpcLine(kind, npcId, context) {
    if (!window.__auth || !window.__auth.getIdToken) return Promise.resolve(null);
    return window.__auth.getIdToken().then(function (token) {
      var body = { kind: kind };
      if (npcId) body.npcId = npcId;
      if (context) body.context = context;
      return fetch('/api/game/narrator', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
        body: JSON.stringify(body),
      });
    }).then(function (r) { return r.ok ? r.json() : null; })
      .then(function (n) {
        if (!n || !n.narration || !n.narration.text) return null;
        return { text: n.narration.text, source: n.narration.source || 'static' };
      })
      .catch(function () { return null; });
  }
  function npcFallbackLine(id) {
    // Зона 23: офлайн предпочитает запомненную ЖИВУЮ реплику прошлого визита.
    try {
      var cached = localStorage.getItem('vrNpcLine:' + id);
      if (cached && Math.random() < 0.6) return cached;
    } catch (e) {}
    // Зона 36: пул — основная либо запасная реплика, чтобы герой не заедал.
    var extra = VR_NPC_FALLBACK2[id];
    if (extra && Math.random() < 0.45) {
      var alt = extra[_vrLang] || extra.ru;
      if (alt) return alt;
    }
    var row = VR_NPC_FALLBACK[id] || VR_NPC_FALLBACK.khan;
    return row[_vrLang] || row.ru;
  }
  // Зона 17: реплика «пишется свитком» — посимвольное появление; уважает
  // prefers-reduced-motion (тогда сразу целиком). Один активный таймер.
  var _typeT = null;
  function typeText(el, text) {
    if (_typeT) { clearInterval(_typeT); _typeT = null; }
    var reduce = false;
    try { reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches; } catch (e) {}
    if (reduce || text.length < 24) { el.textContent = text; return; }
    var i = 0;
    el.textContent = '';
    _typeT = setInterval(function () {
      i += 2;
      el.textContent = text.slice(0, i);
      if (i >= text.length) { clearInterval(_typeT); _typeT = null; }
    }, 18);
  }
  // Зоны 15/16: голос героя — speechSynthesis с индивидуальным тембром.
  var TTS_LOCALE = { ru: 'ru-RU', en: 'en-US', cu: 'ru-RU', el: 'el-GR', fr: 'fr-FR', zh: 'zh-CN', sw: 'sw-KE' };
  var TTS_VOICE = {
    khan: { pitch: 0.7, rate: 0.85 }, sargis: { pitch: 0.8, rate: 0.9 },
    vardan: { pitch: 1.15, rate: 1.0 }, melik: { pitch: 0.95, rate: 0.9 },
    tabib: { pitch: 0.85, rate: 0.85 }, strazhnik: { pitch: 0.75, rate: 0.95 },
    anahit: { pitch: 1.25, rate: 0.95 }, herald: { pitch: 1.05, rate: 1.1 },
  };
  function speakLine(npcId, text) {
    try {
      if (!window.speechSynthesis || _muted) return;
      speechSynthesis.cancel();
      var u = new SpeechSynthesisUtterance(text);
      u.lang = TTS_LOCALE[_vrLang] || 'ru-RU';
      var v = TTS_VOICE[npcId] || {};
      if (v.pitch) u.pitch = v.pitch;
      if (v.rate) u.rate = v.rate;
      speechSynthesis.speak(u);
    } catch (e) {}
  }
  // Зона 59: шлем снят/вкладка скрыта — голос замолкает немедленно.
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) { try { speechSynthesis.cancel(); } catch (e) {} }
  });
  var _dlgPrevLine = null; // зона 10: {id, text} реплики до «…думает…»
  var _dlgShownId = null;  // чья реплика сейчас на экране (для честной памяти)
  function dlgShowLine(npc, text, source) {
    var p = document.getElementById('vr-dialog-text');
    if (!p) return;
    // Зона 10: прежнее слово героя уходит в его приглушённую память
    // (сохранено в dlgRequest ДО строки «собирается с мыслями», иначе
    // thinking-заглушка перетирала реплику раньше, чем мы её запомним;
    // id-сверка — чтобы слово старого собеседника не попало в память нового).
    var prev = (_dlgPrevLine && _dlgPrevLine.id === npc.id) ? _dlgPrevLine.text : '';
    _dlgPrevLine = null;
    if (prev && prev.indexOf('«') === 0 && prev !== '« ' + text + ' »') {
      var hist = _dlgHist[npc.id] = _dlgHist[npc.id] || [];
      hist.unshift(prev);
      if (hist.length > 2) hist.length = 2;
    }
    typeText(p, '« ' + text + ' »');
    _dlgShownId = npc.id;
    var hDiv = document.getElementById('vr-dialog-history');
    if (hDiv) {
      var hh = _dlgHist[npc.id] || [];
      hDiv.textContent = hh.join(' · ');
      hDiv.hidden = !hh.length;
    }
    // Зона 24: деликатная пометка источника слова.
    var srcEl = document.getElementById('vr-dialog-src');
    if (srcEl) {
      srcEl.textContent = '⋯ ' + vgt(source === 'llama' ? 'dlgLive' : 'dlgLore');
      srcEl.hidden = false;
    }
    // Зона 57: слово хана — весомее, двойной сильный отклик контроллеров.
    hapticPulse(npc.id === 'khan' ? 0.85 : 0.4);
    // Зона 15: кнопка озвучки активна, если синтез речи есть.
    var tts = document.getElementById('vr-dialog-tts');
    if (tts) {
      tts.hidden = !window.speechSynthesis;
      tts.onclick = function () { speakLine(npc.id, text); };
    }
  }
  function dlgRequest(context) {
    if (!_dlgNpc) return;
    // Зона 22: не чаще одного обращения в 2с — луч в шлеме дребезжит.
    var now = Date.now();
    if (now - _lastNarrAt < 2000) return;
    _lastNarrAt = now;
    var npc = _dlgNpc;
    var p = document.getElementById('vr-dialog-text');
    if (p) {
      if (_typeT) { clearInterval(_typeT); _typeT = null; }
      // зона 10: текст на экране принадлежит _dlgShownId — им и помечаем.
      if (p.textContent.indexOf('«') === 0 && _dlgShownId) {
        _dlgPrevLine = { id: _dlgShownId, text: p.textContent };
      }
      p.textContent = vgt('dlgThinking');
    }
    var ctx = sceneContext(context);
    // Зона 31: хан перед дипломатической миссией говорит как дипломат.
    if (npc.id === 'khan' && _currentMission && _currentMission.block === 'diplomacy') {
      ctx = ('игрок готовится к дипломатическому делу; ' + ctx).slice(0, 380);
    }
    fetchNpcLine(npc.kind, npc.kind === 'npc' ? npc.id : null, ctx).then(function (res) {
      // Ответ мог прийти после закрытия/смены собеседника — не перетираем.
      if (_dlgNpc !== npc) return;
      if (res && res.text) {
        // Зона 23: живое слово запоминается на следующий офлайн-визит.
        if (res.source === 'llama') {
          try { localStorage.setItem('vrNpcLine:' + npc.id, res.text); } catch (e) {}
        }
        dlgShowLine(npc, res.text, res.source);
      } else {
        dlgShowLine(npc, npcFallbackLine(npc.id), 'static');
      }
    });
  }
  function closeDialog() {
    _dlgNpc = null;
    if (_typeT) { clearInterval(_typeT); _typeT = null; }
    try { speechSynthesis.cancel(); } catch (e) {}
    var d = document.getElementById('vr-dialog');
    if (d) d.hidden = true;
  }
  function openDialog(n) {
    var d = document.getElementById('vr-dialog');
    if (!d) return;
    _dlgNpc = n;
    var art = document.getElementById('vr-dialog-art');
    if (art) {
      art.src = n.art; art.style.visibility = '';
      art.alt = n.name + (n.role ? ', ' + n.role : ''); // зона 76
    }
    var nameEl = document.getElementById('vr-dialog-name');
    if (nameEl) nameEl.textContent = n.name;
    var roleEl = document.getElementById('vr-dialog-role');
    if (roleEl) roleEl.textContent = n.role || '';
    // Зона 12: ролевой вопрос — своя тема у каждого героя.
    var roleBtn = document.getElementById('vr-dlg-ask-role');
    var rq = VR_NPC_ROLEQ[n.id];
    if (roleBtn) {
      if (rq) {
        roleBtn.textContent = rq.label[_vrLang] || rq.label.ru;
        roleBtn.hidden = false;
      } else roleBtn.hidden = true;
    }
    var hDiv = document.getElementById('vr-dialog-history');
    if (hDiv) {
      var hh = _dlgHist[n.id] || [];
      hDiv.textContent = hh.join(' · ');
      hDiv.hidden = !hh.length;
    }
    d.hidden = false;
    // Зона 33: фокус — на первый вариант ответа, разговор ведётся с клавиатуры/луча.
    var firstOpt = document.getElementById('vr-dlg-ask-path');
    if (firstOpt) { try { firstOpt.focus(); } catch (e) {} }
    hapticPulse();
    _lastNarrAt = 0; // приветствие не душится кулдауном предыдущего героя
    dlgRequest(null); // приветственная реплика в характере героя
  }
  // Зона 40: «поклон каждому герою» — двор помнит учтивость (localStorage;
  // при полном наборе — строка признания + fail-open попытка достижения).
  function recordBow(id) {
    try {
      var bows = JSON.parse(localStorage.getItem('vrBows') || '[]');
      if (bows.indexOf(id) === -1) bows.push(id);
      localStorage.setItem('vrBows', JSON.stringify(bows));
      var need = _npcRoster.map(function (n) { return n.id; });
      var all = need.length > 1 && need.every(function (x) { return bows.indexOf(x) !== -1; });
      if (all && !localStorage.getItem('vrBowsAllShown')) {
        localStorage.setItem('vrBowsAllShown', '1');
        var narr = document.getElementById('vr-narration');
        if (narr) { narr.textContent = '« ' + vgt('dlgBowsAll') + ' »'; narr.hidden = false; }
        if (window.__auth && window.__auth.getIdToken) {
          window.__auth.getIdToken().then(function (token) {
            return fetch('/api/game/achievements/unlock', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
              body: JSON.stringify({ achievementId: 'court-bows' }),
            });
          }).catch(function () {});
        }
      }
    } catch (e) {}
  }
  // Кнопки диалога — постоянные элементы разметки, вешаем обработчики раз.
  (function wireDialog() {
    var d = document.getElementById('vr-dialog');
    var closeBtn = document.getElementById('vr-dialog-close');
    if (closeBtn) closeBtn.addEventListener('click', closeDialog);
    var askPath = document.getElementById('vr-dlg-ask-path');
    if (askPath) askPath.addEventListener('click', function () {
      hapticPulse(); dlgRequest('игрок спрашивает о дороге и предстоящем пути');
    });
    var askCity = document.getElementById('vr-dlg-ask-city');
    if (askCity) askCity.addEventListener('click', function () {
      hapticPulse(); dlgRequest('игрок спрашивает о Герате и новостях двора');
    });
    var askRole = document.getElementById('vr-dlg-ask-role');
    if (askRole) askRole.addEventListener('click', function () {
      var rq = _dlgNpc && VR_NPC_ROLEQ[_dlgNpc.id];
      hapticPulse();
      if (rq) dlgRequest(rq.ctx);
    });
    var bow = document.getElementById('vr-dlg-bow');
    if (bow) bow.addEventListener('click', function () {
      hapticPulse();
      // Зона 38: герой отвечает на поклон — короткое прощание перед уходом.
      var npc = _dlgNpc;
      var p = document.getElementById('vr-dialog-text');
      if (npc && p) {
        if (_typeT) { clearInterval(_typeT); _typeT = null; }
        p.textContent = '« ' + vgt('dlgFarewell') + ' »';
        recordBow(npc.id);
        setTimeout(closeDialog, 1100);
      } else closeDialog();
    });
    if (d) {
      // Зона 34: Escape закрывает разговор.
      d.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') { e.stopPropagation(); closeDialog(); }
      });
      // Зона 35: свайп по карточке — следующий/предыдущий герой двора.
      var sx = null, sy = null;
      d.addEventListener('touchstart', function (e) {
        if (e.touches && e.touches.length === 1) { sx = e.touches[0].clientX; sy = e.touches[0].clientY; }
      }, { passive: true });
      d.addEventListener('touchend', function (e) {
        if (sx === null || !e.changedTouches || !e.changedTouches.length) return;
        var dx = e.changedTouches[0].clientX - sx;
        var dy = e.changedTouches[0].clientY - sy;
        sx = sy = null;
        if (Math.abs(dx) < 60 || Math.abs(dy) > 40 || !_dlgNpc || _npcRoster.length < 2) return;
        var i = -1;
        for (var k = 0; k < _npcRoster.length; k++) {
          if (_npcRoster[k].id === _dlgNpc.id) { i = k; break; }
        }
        if (i < 0) return;
        var j = (i + (dx < 0 ? 1 : _npcRoster.length - 1)) % _npcRoster.length;
        openDialog(_npcRoster[j]);
      }, { passive: true });
    }
  })();
  function renderNpcRow(npcs) {
    var row = document.getElementById('vr-npc-row');
    if (!row) return;
    var all = [{ id: 'khan', name: vgt('khanName'), kind: 'khan', role: vgt('roleKhan'), art: '/vr/art/npc-khan.svg' }]
      .concat(npcs.map(function (n) {
        return { id: n.id, name: n.name, kind: 'npc', role: n.role || '', art: '/vr/art/npc-' + n.id + '.svg' };
      }))
      // Зона 30: глашатай — голос событий дня (kind 'event', рог вместо лица).
      .concat([{ id: 'herald', name: vgt('heraldName'), kind: 'event', role: vgt('roleHerald'), art: '/vr/art/obj-rog-glashataya.svg' }]);
    _npcRoster = all; // зона 35: листание свайпом идёт по этому составу
    row.textContent = '';
    all.forEach(function (n) {
      var b = document.createElement('button');
      b.type = 'button';
      b.setAttribute('aria-label', vgt('npcLineAria') + n.name);
      b.title = n.name;
      b.style.cssText = 'background:none;border:1px solid #8a6a3466;border-radius:6px;padding:.15rem;cursor:pointer;line-height:0';
      var img = document.createElement('img');
      img.src = n.art; img.alt = ''; img.width = 24; img.height = 34;
      img.onerror = function () { b.remove(); };
      b.appendChild(img);
      b.addEventListener('click', function () { openDialog(n); });
      // Зона 25: луч/курсор задержался на герое 1.5с — он сам начинает разговор.
      var hoverT = null;
      b.addEventListener('pointerenter', function () {
        hoverT = setTimeout(function () {
          if (!_dlgNpc || _dlgNpc.id !== n.id) openDialog(n);
        }, 1500);
      });
      b.addEventListener('pointerleave', function () {
        if (hoverT) { clearTimeout(hoverT); hoverT = null; }
      });
      row.appendChild(b);
    });
    if (all.length) row.hidden = false;
  }
  function loadNpcRow() {
    apiGetVr('/narrator/npcs').then(function (r) {
      var npcs = (r && r.npcs) || [];
      renderNpcRow(npcs.length ? npcs : VR_NPC_STATIC);
    }).catch(function () { renderNpcRow(VR_NPC_STATIC); });
  }

  // Реестр п.35 (проход №48): задание дня прямо из VR — тот же
  // /daily/status + /daily/claim, что у карточки дашборда (game.js).
  // Fail-open: любой отказ просто оставляет кнопку скрытой.
  function loadDaily() {
    var btn = document.getElementById('vr-daily-btn');
    if (!btn) return;
    apiGetVr('/daily/status').then(function (d) {
      var daily = d && d.daily;
      if (!daily || daily.claimed) return;
      btn.textContent = vgt('dailyClaimBtn') + (daily.reward || '?') + vgt('dailyClaimSuffix');
      btn.hidden = false;
      btn.onclick = function () {
        btn.disabled = true;
        hapticPulse();
        window.__auth.getIdToken().then(function (token) {
          return fetch('/api/game/daily/claim', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
            body: '{}',
          });
        }).then(function (r) { return r.ok ? r.json() : null; })
          .then(function (res) {
            if (res && res.reward != null) {
              btn.textContent = vgt('dailyClaimedPrefix') + res.reward + vgt('dailyClaimedSuffix');
              loadHud(); // баланс в HUD обновится тем же путём
            } else {
              btn.textContent = vgt('dailyUnavailable');
            }
          })
          .catch(function () { btn.disabled = false; });
      };
    }).catch(function () {});
  }

  // Реестр п.16 (проход №48): haptic-отклик контроллера на нажатие.
  // Gamepad API: у Quest-контроллеров actuator виден как vibrationActuator
  // (Chrome) или hapticActuators[0] (WebXR-профиль). Fail-open: нет
  // геймпада/актуатора/поддержки — тихо ничего.
  // Зона 57: сила отклика настраиваема — слово хана бьёт весомее обычного
  // нажатия; цикл и так проходит ОБА контроллера (все pads).
  function hapticPulse(mag) {
    var m = (typeof mag === 'number' && mag > 0) ? Math.min(mag, 1) : 0.4;
    try {
      if (!navigator.getGamepads) return;
      var pads = navigator.getGamepads();
      for (var i = 0; i < pads.length; i++) {
        var gp = pads[i];
        if (!gp) continue;
        var act = gp.vibrationActuator ||
          (gp.hapticActuators && gp.hapticActuators[0]);
        if (act && act.playEffect) {
          act.playEffect('dual-rumble', { duration: m > 0.6 ? 140 : 60, strongMagnitude: m, weakMagnitude: m / 2 });
        } else if (act && act.pulse) {
          act.pulse(m, m > 0.6 ? 140 : 60);
        }
      }
    } catch (e) {}
  }

  // Реестр п.45 (проход №44): один повтор кампании с бэкоффом 5с —
  // холодный старт бэкенда/сети в шлеме не оставляет свиток пустым.
  function fetchCampaignWithRetry() {
    return apiGetVr('/campaign?lang=ru').then(function (data) {
      if (data) return data;
      return new Promise(function (res) { setTimeout(res, 5000); })
        .then(function () { return apiGetVr('/campaign?lang=ru'); });
    });
  }

  function loadStory() {
    return window.__auth.ensureSignedIn()
      .then(function () { return fetchCampaignWithRetry(); })
      .then(function (data) {
        var missions = (data && data.missions) || [];
        _missionsAll = missions; // п.18: свайп-листание по свитку
        // Реестр п.7 (проход №44): deep-link ?mission=N — открыть конкретную миссию.
        var want = new URLSearchParams(location.search).get('mission');
        var linked = want ? missions.find(function (m) { return String(m.id) === want; }) : null;
        _currentMission = linked ||
          missions.find(function (m) { return !m.completed; }) || missions[0] || null;
        if (_currentMission) showMission(_currentMission);
        // Реестр VR п.34: прогресс пути X/N в HUD — из уже загруженной кампании.
        if (missions.length) {
          var done = missions.filter(function (m) { return m.completed; }).length;
          document.getElementById('vr-hud-path').textContent = done + '/' + missions.length;
        }
        loadHud();
        loadNpcRow(); // п.36/37 — голоса двора, fail-open
        loadDaily(); // п.35 — задание дня из VR, fail-open
        return loadNarration();
      })
      .catch(function (e) { console.error('[VR] панель сюжета: ' + (e.message || e)); });
  }

  // Реестр п.73 (проход №57, 2026-08-20): раньше /auth.js (полный Firebase
  // Auth SDK) грузился безусловно, даже если игровой бэкенд лежит — в шлеме
  // на плохой сети это лишний трафик ради обречённых запросов (loadHud/
  // loadNarration/loadDaily всё равно fail-open один за другим отвалятся по
  // своим 15с таймаутам). Теперь сначала дешёвый /api/game/health (без SDK,
  // без токена — уже существующий незащищённый роут per gameApiApp.ts), и
  // только при живом ответе грузим auth.js и весь сюжетный путь.
  function loadAuthAndStory() {
  var authScript = document.createElement('script');
  authScript.src = '/auth.js';
  authScript.onload = function () {
    showCachedMission(); // п.46: свиток виден мгновенно, сеть догонит
    loadStory().then(function () {
      // VR-4: «двор живёт» — раз в 90с новая реплика (temperature 0.8 на
      // сервере даёт вариативность), пока канал отвечает.
      if (!_narrTimer) _narrTimer = setInterval(loadNarration, 90000);
    });
    // Реестр 99, п.44 (проход №40): вкладка скрыта (шлем снят/другое
    // приложение) — пауза автообновления, не жжём батарею и запросы;
    // возврат видимости — свежая реплика сразу + возобновление цикла.
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) {
        if (_narrTimer) { clearInterval(_narrTimer); _narrTimer = null; }
      } else if (!_narrTimer && _narrFails < 3 && (!narrAuto || narrAuto.checked)) {
        loadNarration();
        _narrTimer = setInterval(loadNarration, 90000);
      }
    });
    // VR-1: кнопка «Обновить свиток» — полный пере-fetch миссии/HUD/реплики.
    var btn = document.getElementById('vr-refresh');
    // п.48: видимый индикатор «обновляется…» поверх disabled-состояния.
    function doRefresh() {
      if (!btn || btn.disabled) return;
      btn.disabled = true;
      hapticPulse(); // п.16: тактильное подтверждение нажатия в контроллере
      var was = btn.textContent;
      btn.textContent = vgt('refreshUpdating');
      loadStory().then(function () { btn.disabled = false; btn.textContent = was; });
    }
    if (btn) btn.addEventListener('click', doRefresh);

    // Реестр п.14 (проход №54): голосовой ввод — фраза «обновить» перезагружает
    // свиток, как кнопка VR-1. Опционально (кнопка-микрофон включает/выключает
    // прослушивание — НЕ автостарт без согласия), continuous+interimResults для
    // распознавания на лету. Fail-open: конструктор SpeechRecognition отсутствует
    // (десктоп-браузер без поддержки, Quest Browser без флага) — кнопка не рисуется.
    var SpeechRecognitionCtor = window.SpeechRecognition || window.webkitSpeechRecognition;
    var voiceBtn = document.getElementById('vr-voice');
    if (SpeechRecognitionCtor && voiceBtn) {
      voiceBtn.hidden = false;
      var recognition = null;
      var listening = false;
      function stopListening() {
        listening = false;
        if (recognition) { try { recognition.stop(); } catch (e) {} }
        voiceBtn.textContent = '🎙️';
        voiceBtn.setAttribute('aria-pressed', 'false');
      }
      // Гуру-проход (п.39, локализация): распознавание речи следует за языком
      // панели, не только его метка. cu не имеет реального BCP-47-локейла в
      // браузерах — честно остаётся на ru-RU/слове «обновить» как ближайшем
      // рабочем варианте (задокументировано здесь, не тихая заглушка).
      var VOICE_LOCALE = { ru: 'ru-RU', en: 'en-US', cu: 'ru-RU', el: 'el-GR', fr: 'fr-FR', zh: 'zh-CN', sw: 'sw-KE' };
      function startListening() {
        recognition = new SpeechRecognitionCtor();
        recognition.lang = VOICE_LOCALE[_vrLang] || 'ru-RU';
        recognition.continuous = true;
        recognition.interimResults = false;
        recognition.onresult = function (e) {
          var word = vStatic('voiceWord').toLowerCase();
          for (var i = e.resultIndex; i < e.results.length; i++) {
            var transcript = (e.results[i][0] && e.results[i][0].transcript) || '';
            if (transcript.toLowerCase().indexOf(word) !== -1) doRefresh();
          }
        };
        // Браузер сам обрывает continuous-сессию по таймауту тишины —
        // честный автоперезапуск, пока пользователь не выключил вручную.
        recognition.onend = function () { if (listening) { try { recognition.start(); } catch (e) {} } };
        recognition.onerror = function () { stopListening(); };
        try {
          recognition.start();
          listening = true;
          voiceBtn.textContent = vgt('voiceListening');
          voiceBtn.setAttribute('aria-pressed', 'true');
        } catch (e) { stopListening(); }
      }
      voiceBtn.addEventListener('click', function () {
        hapticPulse();
        if (listening) stopListening(); else startListening();
      });
      window.addEventListener('pagehide', stopListening);
      document.addEventListener('visibilitychange', function () {
        if (document.hidden && listening) stopListening();
      });
    }

    // VR-6 (п.19): полное погружение — скрыть/показать панель.
    var panel = document.getElementById('vr-panel');
    var showBtn = document.getElementById('vr-panel-show');
    var hideBtn = document.getElementById('vr-panel-hide');

    // Реестр п.54 (проход №45): масштаб шрифта панели — A−/A+, сохраняется
    // в localStorage между визитами. Диапазон 0.8–1.4 rem, шаг 0.1.
    // Fail-open: любая ошибка storage молчит, панель остаётся с дефолтом.
    function applyFontScale(scale) {
      if (panel) panel.style.fontSize = scale.toFixed(1) + 'rem';
    }
    function readFontScale() {
      try {
        var v = parseFloat(localStorage.getItem('vrFontScale'));
        if (v >= 0.8 && v <= 1.4) return v;
      } catch (e) {}
      return 1.0;
    }
    var _fontScale = readFontScale();
    if (_fontScale !== 1.0) applyFontScale(_fontScale);
    function bumpFontScale(delta) {
      _fontScale = Math.min(1.4, Math.max(0.8, Math.round((_fontScale + delta) * 10) / 10));
      applyFontScale(_fontScale);
      try { localStorage.setItem('vrFontScale', String(_fontScale)); } catch (e) {}
    }
    // Реестр п.20 (проход №49): высота панели — сидя (низко, дефолт) или
    // стоя (выше, чтобы не наклонять голову в шлеме). Двигаем и панель, и
    // плавающую кнопку «📜 Свиток» синхронно. Fail-open: ошибка storage молчит.
    var HEIGHT_LOW = '4.5rem';
    var HEIGHT_HIGH = '11rem';
    function applyPanelHeight(high) {
      var b = high ? HEIGHT_HIGH : HEIGHT_LOW;
      if (panel) panel.style.bottom = b;
      if (showBtn) showBtn.style.bottom = b;
    }
    var _panelHigh = false;
    try { _panelHigh = localStorage.getItem('vrPanelHigh') === '1'; } catch (e) {}
    if (_panelHigh) applyPanelHeight(true);
    var heightBtn = document.getElementById('vr-panel-height');
    if (heightBtn) heightBtn.addEventListener('click', function () {
      _panelHigh = !_panelHigh;
      applyPanelHeight(_panelHigh);
      try { localStorage.setItem('vrPanelHigh', _panelHigh ? '1' : '0'); } catch (e) {}
      hapticPulse();
    });

    var fontDec = document.getElementById('vr-font-dec');
    var fontInc = document.getElementById('vr-font-inc');
    if (fontDec) fontDec.addEventListener('click', function () { bumpFontScale(-0.1); });
    if (fontInc) fontInc.addEventListener('click', function () { bumpFontScale(0.1); });
    if (hideBtn) hideBtn.addEventListener('click', function () {
      panel.hidden = true; showBtn.hidden = false; showBtn.focus();
    });
    if (showBtn) showBtn.addEventListener('click', function () {
      showBtn.hidden = true; panel.hidden = false;
    });

    // Реестр п.18 (проход №51): свайп по свитку — листание миссий.
    // Влево = следующая, вправо = предыдущая; порог 60px по X и не более
    // 40px по Y (не путать с вертикальным скроллом текста). Fail-open:
    // без загруженной кампании (<2 миссий) жест молча игнорируется.
    // Показ через showMission(m, true) — кэш последней РЕАЛЬНОЙ текущей
    // миссии (vrLastMission) листанием не перезаписывается.
    var _swipeX = null, _swipeY = null;
    function swipeMission(delta) {
      if (!_missionsAll || _missionsAll.length < 2 || !_currentMission) return;
      var i = -1;
      for (var k = 0; k < _missionsAll.length; k++) {
        if (String(_missionsAll[k].id) === String(_currentMission.id)) { i = k; break; }
      }
      if (i < 0) return;
      var j = Math.max(0, Math.min(_missionsAll.length - 1, i + delta));
      if (j === i) return;
      _currentMission = _missionsAll[j];
      showMission(_currentMission, true);
      hapticPulse();
    }
    if (panel) {
      panel.addEventListener('touchstart', function (e) {
        if (e.touches && e.touches.length === 1) {
          _swipeX = e.touches[0].clientX; _swipeY = e.touches[0].clientY;
        }
      }, { passive: true });
      panel.addEventListener('touchend', function (e) {
        if (_swipeX === null || !e.changedTouches || !e.changedTouches.length) return;
        var dx = e.changedTouches[0].clientX - _swipeX;
        var dy = e.changedTouches[0].clientY - _swipeY;
        _swipeX = _swipeY = null;
        if (Math.abs(dx) >= 60 && Math.abs(dy) <= 40) swipeMission(dx < 0 ? 1 : -1);
      }, { passive: true });
    }

    // Реестр п.15 (проход №53): жест «посмотреть вниз 2с» = показать/скрыть
    // панель. deviceorientation.beta (наклон вперёд): ≥55° непрерывно 2с —
    // переключение, гистерезис (сброс только при возврате <40°) + кулдаун
    // через _lookFired, чтобы удержанный взгляд не дребезжал toggle'ом.
    // Fail-open: нет события/датчика (десктоп без гироскопа) — ничего не
    // происходит; проверка elapsed на каждом событии, без своего таймера.
    var _lookT0 = null, _lookFired = false;
    window.addEventListener('deviceorientation', function (e) {
      var beta = (e && typeof e.beta === 'number') ? e.beta : null;
      if (beta === null || !panel || !showBtn) return;
      if (beta >= 55) {
        if (_lookT0 === null) { _lookT0 = Date.now(); return; }
        if (!_lookFired && Date.now() - _lookT0 >= 2000) {
          _lookFired = true;
          if (panel.hidden) { showBtn.hidden = true; panel.hidden = false; }
          else { panel.hidden = true; showBtn.hidden = false; }
          hapticPulse();
        }
      } else if (beta < 40) {
        _lookT0 = null; _lookFired = false;
      }
    });

    // VR-10 (п.13): кнопка A контроллера (Gamepad button 0) = обновить свиток.
    // Зона 53: кнопка B (button 1) = открыть диалог хана / закрыть открытый.
    // Зона 61: скрытая вкладка — тик пропускается, батарея шлема не жжётся.
    // Poll 500мс, дебаунс по отпусканию; работает и с обычным геймпадом в браузере.
    var _padWasPressed = false;
    var _padBWasPressed = false;
    var _padTimer = setInterval(function () {
      if (document.hidden || !navigator.getGamepads) return;
      var pads = navigator.getGamepads();
      var pressed = false, pressedB = false;
      for (var i = 0; i < pads.length; i++) {
        var gp = pads[i];
        if (!gp || !gp.buttons) continue;
        if (gp.buttons[0] && gp.buttons[0].pressed) pressed = true;
        if (gp.buttons[1] && gp.buttons[1].pressed) pressedB = true;
      }
      if (pressed && !_padWasPressed && btn && !btn.disabled && !panel.hidden) btn.click();
      if (pressedB && !_padBWasPressed && !panel.hidden) {
        if (_dlgNpc) closeDialog();
        else if (_npcRoster.length) openDialog(_npcRoster[0]); // хан всегда первый
      }
      _padWasPressed = pressed;
      _padBWasPressed = pressedB;
    }, 500);

    // п.60: чекбокс «живые реплики двора» — off глушит цикл, on возобновляет.
    var narrAuto = document.getElementById('vr-narr-auto');
    if (narrAuto) narrAuto.addEventListener('change', function () {
      if (!narrAuto.checked) {
        if (_narrTimer) { clearInterval(_narrTimer); _narrTimer = null; }
      } else if (!_narrTimer) {
        _narrFails = 0;
        loadNarration();
        _narrTimer = setInterval(loadNarration, 90000);
      }
    });

    // VR-10 (п.77): pagehide — глушим ВСЕ таймеры (уход со страницы в шлеме).
    window.addEventListener('pagehide', function () {
      if (_narrTimer) { clearInterval(_narrTimer); _narrTimer = null; }
      if (_padTimer) { clearInterval(_padTimer); _padTimer = null; }
      if (_loadTicker) { clearInterval(_loadTicker); _loadTicker = null; } // п.25
    });
  };
  authScript.onerror = function () { console.error('[VR] панель сюжета: /auth.js не загрузился'); };
  document.head.appendChild(authScript);
  } // конец loadAuthAndStory()

  (function healthGatedAuthLoad() {
    // The gameApi backend is not part of ludus; probing it here would
    // only produce a 404 on every load. The <meta name="ludus-vr-backend">
    // switch decides whether the story path may talk to /api/game/* at
    // all, and "off" goes straight to the offline mode used below.
    var gate = document.querySelector('meta[name="ludus-vr-backend"]');
    if (!gate || gate.getAttribute('content') !== 'on') {
      showCachedMission();
      renderNpcRow(VR_NPC_STATIC);
      console.info('[VR] backend off (ludus-vr-backend) — offline story mode');
      return;
    }
    var ctl =('AbortController' in window) ? new AbortController() : null;
    var t = ctl ? setTimeout(function () { ctl.abort(); }, 5000) : null;
    fetch('/api/game/health', { signal: ctl ? ctl.signal : undefined }).then(function (r) {
      if (t) clearTimeout(t);
      if (r && r.ok) { loadAuthAndStory(); }
      else {
        showCachedMission();
        renderNpcRow(VR_NPC_STATIC); // проход №58: герои живут и офлайн
        console.error('[VR] бэкенд нездоров (health не ok) — сюжетный путь пропущен, показан кэш');
      }
    }, function () {
      if (t) clearTimeout(t);
      // Сеть/таймаут/AbortError — бэкенд недостижим; показываем кэш вместо
      // цепочки обречённых запросов, panel остаётся полностью пригодной для
      // fail-open сценариев (сцена/движок не зависят от этого пути вообще).
      showCachedMission();
      renderNpcRow(VR_NPC_STATIC); // проход №58: диалоги героев из fallback-реплик
      console.error('[VR] health-проверка бэкенда не удалась — сюжетный путь пропущен, показан кэш');
    });
  })();
})();
