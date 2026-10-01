<template>
  <div class="space-y-4">
    <div class="grid grid-cols-2 gap-3">
      <div class="bg-primary p-3 rounded border border-border">
        <div class="text-xs text-text-secondary mb-1">Mission State</div>
        <div class="text-lg font-bold" data-testid="mission-state">{{ status?.state ?? 'UNKNOWN' }}</div>
      </div>
      <div class="bg-primary p-3 rounded border border-border">
        <div class="text-xs text-text-secondary mb-1">Last Trigger</div>
        <div class="text-sm font-mono">{{ status?.last_trigger_reason ?? 'none' }}</div>
      </div>
    </div>

    <div v-if="status?.vitals" class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Diver Vitals</div>
      <div class="space-y-1 text-sm">
        <div class="flex justify-between">
          <span>Heart rate:</span>
          <span class="font-bold">{{ status.vitals.heart_rate_bpm }} bpm</span>
        </div>
        <div class="flex justify-between">
          <span>Depth:</span>
          <span class="font-bold">{{ status.vitals.depth_m }} m</span>
        </div>
        <div class="flex justify-between">
          <span>Breathing rate:</span>
          <span class="font-bold">{{ status.vitals.breathing_rate_bpm }} bpm</span>
        </div>
      </div>
    </div>

    <div v-if="status?.diver_fix" class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Diver Fix</div>
      <div class="space-y-1 text-sm">
        <div class="flex justify-between">
          <span>Forward:</span>
          <span class="font-bold">{{ status.diver_fix.forward_m }} m</span>
        </div>
        <div class="flex justify-between">
          <span>Lateral:</span>
          <span class="font-bold">{{ status.diver_fix.lateral_m }} m</span>
        </div>
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Gesture Command</div>
      <div class="grid grid-cols-3 gap-2">
        <button
          v-for="gesture in gestures"
          :key="gesture"
          :data-testid="`gesture-${gesture}`"
          :disabled="isSending"
          @click="sendGesture(gesture)"
          class="text-white font-bold py-2 rounded transition text-sm disabled:bg-gray-400"
          :class="gestureButtonClass(gesture)"
        >
          {{ gesture }}
        </button>
      </div>
      <div v-if="errorMessage" class="text-xs text-threat-critical mt-2" data-testid="gesture-error">
        {{ errorMessage }}
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import {
  fetchDiveBuddyStatus,
  sendDiveBuddyGesture,
  type DiveBuddyStatus,
  type DiveBuddyGesture,
} from '../services/gatewayApi'

const gestures: DiveBuddyGesture[] = ['EMERGENCY', 'HOLD', 'RESUME']

const status = ref<DiveBuddyStatus | null>(null)
const isSending = ref(false)
const errorMessage = ref('')
let statusInterval: ReturnType<typeof setInterval> | null = null

const gestureButtonClass = (gesture: DiveBuddyGesture) => {
  if (gesture === 'EMERGENCY') return 'bg-red-600 hover:bg-red-700'
  if (gesture === 'HOLD') return 'bg-yellow-600 hover:bg-yellow-700'
  return 'bg-green-600 hover:bg-green-700'
}

const loadStatus = async () => {
  try {
    status.value = await fetchDiveBuddyStatus()
  } catch (err) {
    console.error('Failed to fetch dive-buddy status:', err)
  }
}

const sendGesture = async (gesture: DiveBuddyGesture) => {
  isSending.value = true
  errorMessage.value = ''
  try {
    status.value = await sendDiveBuddyGesture(gesture)
  } catch (err: any) {
    errorMessage.value = err?.response?.data?.detail ?? 'Failed to send gesture'
    console.error('Failed to send dive-buddy gesture:', err)
  } finally {
    isSending.value = false
  }
}

onMounted(() => {
  loadStatus()
  statusInterval = setInterval(loadStatus, 3000)
})

onUnmounted(() => {
  if (statusInterval) clearInterval(statusInterval)
})

defineExpose({ loadStatus, sendGesture })
</script>
