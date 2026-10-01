/**
 * Ludus NPC Dialogue UI Component
 *
 * Renders the dialogue modal: NPC name, the NPC's words and the
 * player's choices.  Integrates with the Dialogue Manager (tree state,
 * FORM checks) and the Audio Manager (meaningful feedback sounds).
 *
 * All tree data is written with textContent, never innerHTML, because
 * dialogue trees are editable through an admin endpoint and must not
 * be able to run script in the player's browser.
 */

'use strict';

window.LudusDialogueUI = (function () {
  const DEFAULT_CONTAINER_ID = 'ludus-dialogue-container';

  // Human-readable labels for the seven attributes of the constitution.
  const ATTRIBUTE_LABELS = {
    wisdom: 'Wisdom',
    faith: 'Faith',
    dexterity: 'Dexterity',
    constitution: 'Constitution',
    charisma: 'Charisma',
    cunning: 'Cunning',
    erudition: 'Erudition',
  };

  // Each sound carries a meaning (docs/SOUND_DESIGN_SYSTEM.md, 4.3):
  // a soft wooden tap confirms a choice, two gusli plucks rising a
  // step mark attribute gain (a folk string, never a bell or a voice
  // as a reward ding), a blessing closes a teaching, a muted knock
  // says a path is closed to the player's current FORM.
  const SOUNDS = {
    choice: 'ui_neutral',
    gain: 'ui_positive',
    teachingComplete: 'blessing_sound',
    locked: 'ui_negative',
    error: 'ui_negative',
  };

  let currentNpcId = null;
  let currentDialogueTree = null;
  let playerAttributes = {};
  let onChoice = null;
  let containerId = DEFAULT_CONTAINER_ID;

  // Focus and background state that must survive re-renders of the
  // modal between nodes, and be undone when it closes.
  let returnFocusTo = null;
  let inertedSiblings = [];
  let themeSource = null;
  let busy = false;

  // ── Small DOM helpers ───────────────────────────────────────────────────
  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) {
      node.className = className;
    }
    if (text != null) {
      node.textContent = String(text);
    }
    return node;
  }

  function labelFor(attr) {
    return ATTRIBUTE_LABELS[attr] || attr;
  }

  function describeBonuses(bonuses) {
    return Object.entries(bonuses || {})
      .map(([attr, bonus]) => `+${bonus} ${labelFor(attr)}`)
      .join(', ');
  }

  function describeMissing(missing) {
    return (missing || [])
      .map((m) => `${labelFor(m.attribute)} ${m.required} ` +
        `(you have ${m.current})`)
      .join(', ');
  }

  function emit(type, detail) {
    window.dispatchEvent(new CustomEvent('ludus:dialogue-' + type, {
      detail: Object.assign({ npcId: currentNpcId }, detail || {}),
    }));
  }

  // ── Audio wiring ────────────────────────────────────────────────────────
  // Sounds are fire-and-forget: a missing file or a suspended audio
  // context must never block a choice or surface as an app error.
  function audio() {
    return window.LudusAudioManager || null;
  }

  function playSound(key) {
    const manager = audio();
    if (!manager || typeof manager.playSfx !== 'function') {
      return;
    }
    try {
      Promise.resolve(manager.playSfx(key)).catch(() => {});
    } catch (err) {
      // The audio manager may throw synchronously for unknown keys.
    }
  }

  function startNpcTheme(npcId) {
    const manager = audio();
    if (!manager || typeof manager.playMusic !== 'function' ||
        !manager.MUSIC_CATALOG || !manager.MUSIC_CATALOG[npcId + '_theme']) {
      return;
    }
    try {
      Promise.resolve(manager.playMusic(npcId + '_theme'))
        .then((source) => {
          themeSource = source || null;
        })
        .catch(() => {});
    } catch (err) {
      // Music is an enhancement; the conversation works without it.
    }
  }

  function stopNpcTheme() {
    if (themeSource && typeof themeSource.stop === 'function') {
      try {
        themeSource.stop();
      } catch (err) {
        // Already stopped.
      }
    }
    themeSource = null;
  }

  function setDucking(active) {
    const manager = audio();
    if (!manager || typeof manager.updateLayerDucking !== 'function' ||
        !manager.getAudioContext || !manager.getAudioContext()) {
      return;
    }
    try {
      manager.updateLayerDucking(active ? ['dialogue'] : []);
    } catch (err) {
      // Ducking needs initialised layers; skip it until they exist.
    }
  }

  // ── Rendering ───────────────────────────────────────────────────────────
  function buildBranch(branch) {
    const button = el('button', 'dialogue-choice');
    button.type = 'button';
    button.dataset.branchIndex = String(branch.index);

    const number = el('span', 'choice-number', `${branch.index + 1}`);
    number.setAttribute('aria-hidden', 'true');
    button.appendChild(number);

    const body = el('span', 'choice-body');
    body.appendChild(el('span', 'choice-text', branch.text));

    const gains = describeBonuses(branch.bonuses);
    if (gains) {
      body.appendChild(el('span', 'choice-bonuses', gains));
    }

    if (branch.locked) {
      // Locked paths stay visible and focusable (aria-disabled rather
      // than disabled) so the player learns what their FORM lacks.
      button.classList.add('locked');
      button.setAttribute('aria-disabled', 'true');
      body.appendChild(el('span', 'lock-hint',
        `Requires ${describeMissing(branch.missing)}`));
    }
    button.appendChild(body);
    return button;
  }

  function buildModalShell(npcId) {
    const profile = window.LudusDialogueManager.getNpcProfile(npcId);
    const tree = currentDialogueTree || {};
    const name = (profile && profile.name) || tree.npcName || 'NPC';
    const theology = (profile && profile.theology) || tree.theology || '';

    const modal = el('div', 'ludus-dialogue-modal');
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-labelledby', 'ludus-dialogue-name');
    modal.setAttribute('aria-describedby', 'ludus-dialogue-text');
    modal.dataset.npc = npcId || '';

    const header = el('div', 'dialogue-header');
    const title = el('h2', 'dialogue-npc-name', name);
    title.id = 'ludus-dialogue-name';
    header.appendChild(title);
    if (profile && profile.role) {
      header.appendChild(el('p', 'dialogue-npc-role', profile.role));
    }
    if (theology) {
      header.appendChild(el('span', 'dialogue-theology', theology));
    }
    modal.appendChild(header);

    // The live region persists across nodes, so screen readers announce
    // each new NPC line instead of a freshly inserted, silent element.
    const textBox = el('div', 'dialogue-text-box');
    const text = el('p', 'dialogue-text');
    text.id = 'ludus-dialogue-text';
    text.setAttribute('aria-live', 'polite');
    textBox.appendChild(text);
    modal.appendChild(textBox);

    const status = el('p', 'dialogue-status');
    status.setAttribute('role', 'status');
    modal.appendChild(status);

    const branches = el('div', 'dialogue-branches');
    branches.setAttribute('role', 'group');
    branches.setAttribute('aria-label', 'Your answer');
    modal.appendChild(branches);

    const close = el('button', 'dialogue-close-btn', '×');
    close.type = 'button';
    close.setAttribute('aria-label', 'Close dialogue');
    modal.appendChild(close);

    modal.addEventListener('click', onModalClick);
    modal.addEventListener('keydown', onModalKeydown);
    return modal;
  }

  function setStatus(modal, message) {
    const status = modal.querySelector('.dialogue-status');
    if (status) {
      status.textContent = message || '';
      status.hidden = !message;
    }
  }

  function offlineMessage() {
    const manager = window.LudusDialogueManager;
    return manager.isOffline && manager.isOffline() ?
      'Offline: your progress will sync when the headset reconnects.' :
      '';
  }

  function renderNode(modal, node) {
    const formatted = window.LudusDialogueManager.formatNodeForUI(
      node, playerAttributes);
    const text = modal.querySelector('.dialogue-text');
    const branches = modal.querySelector('.dialogue-branches');
    branches.textContent = '';

    if (!formatted) {
      text.textContent = 'This conversation cannot continue.';
      return;
    }
    text.textContent = formatted.text;
    formatted.branches.forEach((branch) => {
      branches.appendChild(buildBranch(branch));
    });
    setStatus(modal, offlineMessage());
  }

  /**
   * Render dialogue modal and return its HTML.
   *
   * Kept for compatibility; mount() builds live DOM instead.  The
   * returned markup is safe because every value is set as text.
   */
  function renderDialogueModal(node, npcId, attributes) {
    if (!node) {
      console.error('[Ludus Dialogue UI] No node to render');
      return '';
    }
    const saved = playerAttributes;
    playerAttributes = attributes || playerAttributes;
    const modal = buildModalShell(npcId);
    renderNode(modal, node);
    playerAttributes = saved;
    return modal.outerHTML;
  }

  function getContainer() {
    return document.getElementById(containerId);
  }

  function getModal() {
    const container = getContainer();
    return container ? container.querySelector('.ludus-dialogue-modal') :
      null;
  }

  // While the modal is open everything beside it is made inert, so
  // controller pointers and Tab cannot reach the game behind it.
  function setBackgroundInert(container, inert) {
    if (inert) {
      const parent = container.parentElement;
      if (!parent || inertedSiblings.length > 0) {
        return;
      }
      Array.from(parent.children).forEach((child) => {
        if (child !== container && !child.hasAttribute('inert')) {
          child.setAttribute('inert', '');
          inertedSiblings.push(child);
        }
      });
    } else {
      inertedSiblings.forEach((child) => child.removeAttribute('inert'));
      inertedSiblings = [];
    }
  }

  function focusFirstChoice(modal) {
    const target = modal.querySelector(
      '.dialogue-choice:not(.locked), .dialogue-choice, ' +
      '.dialogue-continue-btn, .dialogue-close-btn');
    if (target) {
      target.focus();
    }
  }

  /**
   * Mount the dialogue modal for the current node into the container.
   */
  function mount(targetId) {
    containerId = targetId || containerId || DEFAULT_CONTAINER_ID;
    const container = getContainer();
    if (!container) {
      console.error(
        `[Ludus Dialogue UI] Container not found: ${containerId}`);
      return;
    }

    let modal = getModal();
    if (!modal) {
      // Remember what had focus before the first node only, so closing
      // returns the player to the element that opened the dialogue.
      if (!returnFocusTo) {
        returnFocusTo = document.activeElement;
      }
      container.textContent = '';
      modal = buildModalShell(currentNpcId);
      container.appendChild(modal);
      container.classList.add('ludus-dialogue-container', 'is-open');
      setBackgroundInert(container, true);
    }

    renderNode(modal,
      window.LudusDialogueManager.getCurrentNode(currentDialogueTree));
    focusFirstChoice(modal);
  }

  // ── Interaction ─────────────────────────────────────────────────────────
  function onModalClick(event) {
    const target = event.target.closest('button');
    if (!target || !event.currentTarget.contains(target)) {
      return;
    }
    if (target.classList.contains('dialogue-close-btn') ||
        target.classList.contains('dialogue-continue-btn')) {
      closeDialogue();
      return;
    }
    if (target.classList.contains('dialogue-choice')) {
      handleChoice(Number(target.dataset.branchIndex));
    }
  }

  function focusableIn(modal) {
    return Array.from(modal.querySelectorAll('button'))
      .filter((b) => !b.disabled && b.offsetParent !== null);
  }

  function onModalKeydown(event) {
    const modal = event.currentTarget;

    if (event.key === 'Escape') {
      event.preventDefault();
      closeDialogue();
      return;
    }

    // Tab and Shift+Tab wrap inside the modal (focus trap).
    if (event.key === 'Tab') {
      const items = focusableIn(modal);
      if (items.length === 0) {
        return;
      }
      const first = items[0];
      const last = items[items.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
      return;
    }

    // Arrow keys move between choices, matching a thumbstick on Quest.
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      const choices = Array.from(modal.querySelectorAll('.dialogue-choice'));
      if (choices.length === 0) {
        return;
      }
      event.preventDefault();
      const pos = choices.indexOf(document.activeElement);
      const step = event.key === 'ArrowDown' ? 1 : -1;
      const next = (pos + step + choices.length) % choices.length;
      choices[pos === -1 ? 0 : next].focus();
      return;
    }

    // Number keys pick the numbered choice directly.
    if (/^[1-9]$/.test(event.key) && !event.ctrlKey && !event.metaKey &&
        !event.altKey) {
      const choice = modal.querySelector(
        `.dialogue-choice[data-branch-index="${Number(event.key) - 1}"]`);
      if (choice) {
        event.preventDefault();
        choice.focus();
        handleChoice(Number(event.key) - 1);
      }
    }
  }

  function applyBonuses(bonuses) {
    // The UI keeps its own copy of the attributes so that a gain earned
    // in this conversation can open a gated branch later in it.
    const next = Object.assign({}, playerAttributes);
    Object.entries(bonuses || {}).forEach(([attr, bonus]) => {
      next[attr] = (Number(next[attr]) || 0) + bonus;
    });
    playerAttributes = next;
  }

  /**
   * Handle player choice by branch index (index in node.branches).
   */
  async function handleChoice(branchIndex) {
    const modal = getModal();
    if (!modal || busy) {
      return;
    }
    const button = modal.querySelector(
      `.dialogue-choice[data-branch-index="${branchIndex}"]`);
    if (button && button.classList.contains('locked')) {
      playSound(SOUNDS.locked);
      setStatus(modal, button.querySelector('.lock-hint') ?
        button.querySelector('.lock-hint').textContent : '');
      return;
    }

    busy = true;
    modal.setAttribute('aria-busy', 'true');
    modal.querySelectorAll('.dialogue-choice').forEach((b) => {
      b.disabled = true;
    });

    try {
      const result = await window.LudusDialogueManager.processChoice(
        branchIndex, playerAttributes);
      const gained = Object.keys(result.attributeBonuses).length > 0;
      applyBonuses(result.attributeBonuses);

      if (result.complete) {
        playSound(gained ? SOUNDS.teachingComplete : SOUNDS.choice);
      } else {
        playSound(gained ? SOUNDS.gain : SOUNDS.choice);
      }

      if (typeof onChoice === 'function') {
        try {
          onChoice(result);
        } catch (err) {
          console.error('[Ludus Dialogue UI] onChoice callback failed:',
            err);
        }
      }
      emit('choice', { branchIndex: branchIndex, result: result });

      // NPC voice lines are wired here once recordings exist
      // (voice casting runs Oct 2 to Nov 15); until then the call
      // would only request files that are not there.

      if (result.complete) {
        showDialogueComplete(result);
      } else {
        mount(containerId);
      }
    } catch (err) {
      console.error('[Ludus Dialogue UI] Failed to process choice:', err);
      playSound(SOUNDS.error);
      modal.querySelectorAll('.dialogue-choice').forEach((b) => {
        b.disabled = false;
      });
      setStatus(modal, 'That choice could not be taken. Please try again.');
    } finally {
      busy = false;
      modal.removeAttribute('aria-busy');
    }
  }

  /**
   * Show dialogue completion inside the same dialog.
   */
  function showDialogueComplete(result) {
    const modal = getModal();
    if (!modal) {
      return;
    }
    modal.classList.add('ludus-dialogue-complete');

    const text = modal.querySelector('.dialogue-text');
    const gains = describeBonuses(result.attributeBonuses);
    const parts = ['Dialogue complete.'];
    if (result.narrativeEffect) {
      parts.push(result.narrativeEffect);
    }
    if (gains) {
      parts.push(`You gained ${gains}.`);
    }
    text.textContent = parts.join(' ');

    const branches = modal.querySelector('.dialogue-branches');
    branches.textContent = '';
    if (gains) {
      const list = el('div', 'completion-bonuses');
      Object.entries(result.attributeBonuses).forEach(([attr, bonus]) => {
        list.appendChild(el('span', 'gain-item',
          `+${bonus} ${labelFor(attr)}`));
      });
      branches.appendChild(list);
    }
    const next = el('button', 'dialogue-continue-btn btn-primary',
      'Continue');
    next.type = 'button';
    branches.appendChild(next);
    setStatus(modal, offlineMessage());
    next.focus();

    emit('complete', { result: result });
  }

  /**
   * Close dialogue and give focus back to where it came from.
   */
  function closeDialogue() {
    const container = getContainer();
    const wasOpen = Boolean(getModal());
    if (container) {
      container.textContent = '';
      container.classList.remove('is-open');
      setBackgroundInert(container, false);
    }
    stopNpcTheme();
    setDucking(false);

    const target = returnFocusTo;
    returnFocusTo = null;
    if (target && typeof target.focus === 'function' &&
        document.contains(target)) {
      target.focus();
    }
    if (wasOpen) {
      emit('close');
    }
  }

  function showLoadError(npcId, err) {
    const container = getContainer();
    if (!container) {
      return;
    }
    currentNpcId = npcId;
    if (!returnFocusTo) {
      returnFocusTo = document.activeElement;
    }
    container.textContent = '';
    const modal = buildModalShell(npcId);
    modal.querySelector('.dialogue-text').textContent = err && err.offline ?
      'This teacher cannot be reached while offline. Return when the ' +
      'headset is connected.' :
      'This conversation could not be loaded. Please try again later.';
    container.appendChild(modal);
    container.classList.add('ludus-dialogue-container', 'is-open');
    setBackgroundInert(container, true);
    modal.querySelector('.dialogue-close-btn').focus();
  }

  /**
   * Initialize dialogue UI.
   *
   * ``attributes`` is copied: bonuses earned during the dialogue are
   * applied to the copy and reported through ``choiceCallback``, which
   * is where the game updates its own record of the player's FORM.
   */
  function init(npcId, dialogueTree, attributes, choiceCallback) {
    currentNpcId = npcId;
    currentDialogueTree = dialogueTree;
    playerAttributes = Object.assign({}, attributes || {});
    onChoice = choiceCallback || null;
    console.log('[Ludus Dialogue UI] Initialized for NPC:', npcId);
  }

  /**
   * Load an NPC's tree and open the dialogue in one call.
   *
   * Resolves to true when the dialogue opened, false when it could not
   * be loaded (an explanatory dialog is shown instead).
   */
  async function open(npcId, attributes, choiceCallback, targetId) {
    containerId = targetId || DEFAULT_CONTAINER_ID;
    try {
      const tree = await window.LudusDialogueManager.loadDialogueTree(npcId);
      init(npcId, tree, attributes, choiceCallback);
      mount(containerId);
      startNpcTheme(npcId);
      setDucking(true);
      emit('open');
      return true;
    } catch (err) {
      showLoadError(npcId, err);
      playSound(SOUNDS.error);
      return false;
    }
  }

  /**
   * Helper: escape HTML for callers that still build markup.
   */
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text == null ? '' : String(text);
    return div.innerHTML.replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  // ── Public API ──────────────────────────────────────────────────────────
  return {
    init,
    open,
    mount,
    closeDialogue,
    renderDialogueModal,
    handleChoice,
    escapeHtml,
  };
})();

console.log('[Ludus] Dialogue UI loaded');
