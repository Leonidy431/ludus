<template>
  <div class="space-y-4">
    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Subsystem Status</div>
      <div class="text-sm font-mono" data-testid="gaz2410-status">
        {{ status ? 'online' : 'unavailable' }}
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Laser Power (W)</div>
      <div class="flex gap-2">
        <input
          v-model.number="laserPowerW"
          type="number"
          min="0"
          step="0.1"
          data-testid="laser-power-input"
          class="w-full bg-secondary border border-border rounded px-2 py-1 text-sm"
        />
        <button
          data-testid="laser-power-set"
          :disabled="isBusy"
          @click="setLaserPower"
          class="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-bold py-1 px-3 rounded transition text-sm whitespace-nowrap"
        >
          Set
        </button>
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Bubble Generator</div>
      <div class="grid grid-cols-2 gap-2">
        <button
          data-testid="bubbles-start"
          :disabled="isBusy"
          @click="startBubbles"
          class="bg-green-600 hover:bg-green-700 disabled:bg-gray-400 text-white font-bold py-2 rounded transition text-sm"
        >
          ▶ Start
        </button>
        <button
          data-testid="bubbles-stop"
          :disabled="isBusy"
          @click="stopBubbles"
          class="bg-red-600 hover:bg-red-700 disabled:bg-gray-400 text-white font-bold py-2 rounded transition text-sm"
        >
          ■ Stop
        </button>
      </div>
      <div v-if="errorMessage" class="text-xs text-threat-critical mt-2" data-testid="gaz2410-error">
        {{ errorMessage }}
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import {
  fetchGaz2410Status,
  setGaz2410LaserPower,
  startGaz2410Bubbles,
  stopGaz2410Bubbles,
  type Gaz2410Status,
} from '../services/gatewayApi'

const status = ref<Gaz2410Status | null>(null)
const laserPowerW = ref(1.0)
const isBusy = ref(false)
const errorMessage = ref('')
let statusInterval: ReturnType<typeof setInterval> | null = null

const loadStatus = async () => {
  try {
    status.value = await fetchGaz2410Status()
  } catch (err) {
    console.error('Failed to fetch gaz2410 status:', err)
  }
}

const setLaserPower = async () => {
  isBusy.value = true
  errorMessage.value = ''
  try {
    await setGaz2410LaserPower(laserPowerW.value)
  } catch (err) {
    errorMessage.value = 'Failed to set laser power'
    console.error(err)
  } finally {
    isBusy.value = false
  }
}

const startBubbles = async () => {
  isBusy.value = true
  errorMessage.value = ''
  try {
    await startGaz2410Bubbles(40000, 0.5)
  } catch (err) {
    errorMessage.value = 'Failed to start bubbles'
    console.error(err)
  } finally {
    isBusy.value = false
  }
}

const stopBubbles = async () => {
  isBusy.value = true
  errorMessage.value = ''
  try {
    await stopGaz2410Bubbles()
  } catch (err) {
    errorMessage.value = 'Failed to stop bubbles'
    console.error(err)
  } finally {
    isBusy.value = false
  }
}

onMounted(() => {
  loadStatus()
  statusInterval = setInterval(loadStatus, 5000)
})

onUnmounted(() => {
  if (statusInterval) clearInterval(statusInterval)
})

defineExpose({ loadStatus, setLaserPower, startBubbles, stopBubbles })
</script>
