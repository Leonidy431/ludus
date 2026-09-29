/**
 * Ludus NPC Dialogue UI Component
 *
 * Renders dialogue interface with NPC name, dialogue text, and branching choices.
 * Integrates with Dialogue Manager and Audio Manager.
 */

'use strict';

window.LudusDialogueUI = (function () {
  let currentNpcId = null;
  let currentDialogueTree = null;
  let playerAttributes = null;
  let onChoice = null; // Callback when player makes choice

  /**
   * Render dialogue modal
   */
  function renderDialogueModal(node, npcId, attributes) {
    if (!node) {
      console.error('[Ludus Dialogue UI] No node to render');
      return '';
    }

    const npcProfile = window.LudusDialogueManager.getNpcProfile(npcId);
    const formattedNode = window.LudusDialogueManager.formatNodeForUI(node, attributes);

    if (!formattedNode) return '';

    const html = `
      <div class="ludus-dialogue-modal" data-npc="${npcId}">
        <!-- NPC Header -->
        <div class="dialogue-header">
          <h3 class="dialogue-npc-name">${formattedNode.npcName}</h3>
          <p class="dialogue-npc-role">${npcProfile?.role || 'NPC'}</p>
          <span class="dialogue-theology">${npcProfile?.theology || ''}</span>
        </div>

        <!-- Dialogue Text (NPC Speaking) -->
        <div class="dialogue-text-box">
          <p class="dialogue-text">${escapeHtml(formattedNode.text)}</p>
        </div>

        <!-- Branches (Player Choices) -->
        <div class="dialogue-branches">
          ${formattedNode.branches.map((branch, idx) => renderBranch(branch, idx)).join('')}
        </div>

        <!-- Attribute Bonuses Preview -->
        ${renderBonusesPreview(formattedNode.branches)}

        <!-- Close Button -->
        <button class="dialogue-close-btn" aria-label="Close dialogue">×</button>
      </div>
    `;

    return html;
  }

  /**
   * Render single dialogue branch (player choice)
   */
  function renderBranch(branch, index) {
    const locked = branch.locked;
    const missingAttrs = Object.entries(branch.requiredAttributes || {})
      .filter(([attr, req]) => (playerAttributes[attr] || 0) < req)
      .map(([attr, req]) => `${attr} ${req}`)
      .join(', ');

    const lockHint = locked ? `<span class="lock-hint">Requires: ${missingAttrs}</span>` : '';

    return `
      <button
        class="dialogue-choice ${locked ? 'locked' : ''}"
        data-branch-index="${index}"
        ${locked ? 'disabled' : ''}
        aria-label="${branch.text}${locked ? ` (requires ${missingAttrs})` : ''}"
      >
        <span class="choice-text">${escapeHtml(branch.text)}</span>
        ${branch.bonuses && Object.keys(branch.bonuses).length > 0 ?
          `<span class="choice-bonuses">+${JSON.stringify(branch.bonuses)}</span>`
          : ''}
        ${lockHint}
      </button>
    `;
  }

  /**
   * Render attribute bonuses preview for this dialogue
   */
  function renderBonusesPreview(branches) {
    const allBonuses = {};

    branches.forEach(branch => {
      Object.entries(branch.bonuses || {}).forEach(([attr, bonus]) => {
        allBonuses[attr] = (allBonuses[attr] || 0) + bonus;
      });
    });

    if (Object.keys(allBonuses).length === 0) return '';

    return `
      <div class="dialogue-bonuses-preview">
        <p class="preview-label">Possible gains from this dialogue:</p>
        <div class="bonuses-grid">
          ${Object.entries(allBonuses).map(([attr, bonus]) => `
            <span class="bonus-item" data-attr="${attr}">
              ${attr}: +${bonus}
            </span>
          `).join('')}
        </div>
      </div>
    `;
  }

  /**
   * Mount dialogue modal to DOM
   */
  function mount(containerId) {
    const container = document.getElementById(containerId);
    if (!container) {
      console.error(`[Ludus Dialogue UI] Container not found: ${containerId}`);
      return;
    }

    const modal = document.querySelector('.ludus-dialogue-modal');
    if (modal) {
      modal.remove();
    }

    container.innerHTML = renderDialogueModal(
      window.LudusDialogueManager.getCurrentNode(currentDialogueTree),
      currentNpcId,
      playerAttributes
    );

    // Attach event listeners
    attachEventListeners(container);
  }

  /**
   * Attach event listeners to dialogue choices
   */
  function attachEventListeners(container) {
    const choiceButtons = container.querySelectorAll('.dialogue-choice:not([disabled])');
    choiceButtons.forEach(btn => {
      btn.addEventListener('click', async (e) => {
        const branchIndex = parseInt(btn.dataset.branchIndex);
        await handleChoice(branchIndex);
      });
    });

    const closeBtn = container.querySelector('.dialogue-close-btn');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        closeDialogue();
      });
    }
  }

  /**
   * Handle player choice
   */
  async function handleChoice(branchIndex) {
    try {
      // Disable all choices during processing
      document.querySelectorAll('.dialogue-choice').forEach(btn => {
        btn.disabled = true;
      });

      // Process choice in dialogue manager
      const result = await window.LudusDialogueManager.processChoice(
        branchIndex,
        playerAttributes
      );

      // Play SFX for choice
      if (result.attributeBonuses && Object.keys(result.attributeBonuses).length > 0) {
        await window.LudusAudioManager.playSfx('ui_positive');
      }

      // Invoke callback
      if (onChoice) {
        onChoice(result);
      }

      if (result.complete) {
        // Dialogue complete
        showDialogueComplete(result);
      } else {
        // Move to next node
        const nextNode = currentDialogueTree.nodes.find(
          n => n.id === result.nextNodeId
        );

        // Play NPC voice if available
        const npcProfile = window.LudusDialogueManager.getNpcProfile(currentNpcId);
        if (npcProfile?.voiceProfile) {
          // TODO: Play voice recording from Cloud Storage
          // await window.LudusAudioManager.playDialogue(currentNpcId, result.nextNodeId);
        }

        // Re-render with next node
        currentDialogueTree.nodes = currentDialogueTree.nodes || [];
        mount('ludus-dialogue-container');
      }
    } catch (err) {
      console.error('[Ludus Dialogue UI] Failed to process choice:', err);
      await window.LudusAudioManager.playSfx('ui_negative');
      document.querySelectorAll('.dialogue-choice').forEach(btn => {
        btn.disabled = false;
      });
    }
  }

  /**
   * Show dialogue completion screen
   */
  function showDialogueComplete(result) {
    const container = document.getElementById('ludus-dialogue-container');
    const bonusesHtml = result.attributeBonuses && Object.keys(result.attributeBonuses).length > 0
      ? `<div class="completion-bonuses">
          <p>You gained:</p>
          ${Object.entries(result.attributeBonuses).map(([attr, bonus]) => `
            <span class="gain-item">+${bonus} ${attr}</span>
          `).join('')}
        </div>`
      : '';

    container.innerHTML = `
      <div class="ludus-dialogue-complete">
        <h3>Dialogue Complete</h3>
        ${result.narrativeEffect ? `<p>${escapeHtml(result.narrativeEffect)}</p>` : ''}
        ${bonusesHtml}
        <button class="btn-primary" onclick="document.getElementById('ludus-dialogue-container').innerHTML = ''">
          Continue
        </button>
      </div>
    `;
  }

  /**
   * Close dialogue
   */
  function closeDialogue() {
    const container = document.getElementById('ludus-dialogue-container');
    if (container) {
      container.innerHTML = '';
    }
  }

  /**
   * Initialize dialogue UI
   */
  function init(npcId, dialogueTree, attributes, choiceCallback) {
    currentNpcId = npcId;
    currentDialogueTree = dialogueTree;
    playerAttributes = attributes;
    onChoice = choiceCallback;

    console.log('[Ludus Dialogue UI] Initialized for NPC:', npcId);
  }

  /**
   * Helper: Escape HTML
   */
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // ── Public API ──────────────────────────────────────────────────────────
  return {
    init,
    mount,
    closeDialogue,
    renderDialogueModal,
  };
})();

console.log('[Ludus] Dialogue UI loaded');
