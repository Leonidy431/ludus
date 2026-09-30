<template>
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium mb-1">Temperature (°C)</label>
      <input
        type="number"
        :value="params.temperature"
        @input="updateParam('temperature', $event)"
        class="w-full px-3 py-2 bg-primary border border-border rounded text-text-primary"
        min="0"
        max="35"
        step="0.1"
      />
      <div class="text-xs text-text-secondary mt-1">Current: {{ params.temperature }}°C</div>
    </div>

    <div>
      <label class="block text-sm font-medium mb-1">Salinity (PSU)</label>
      <input
        type="number"
        :value="params.salinity"
        @input="updateParam('salinity', $event)"
        class="w-full px-3 py-2 bg-primary border border-border rounded text-text-primary"
        min="0"
        max="40"
        step="0.1"
      />
      <div class="text-xs text-text-secondary mt-1">Current: {{ params.salinity }} PSU</div>
    </div>

    <div>
      <label class="block text-sm font-medium mb-1">Depth (m)</label>
      <input
        type="number"
        :value="params.depth"
        @input="updateParam('depth', $event)"
        class="w-full px-3 py-2 bg-primary border border-border rounded text-text-primary"
        min="0"
        max="1000"
        step="0.1"
      />
      <div class="text-xs text-text-secondary mt-1">Current: {{ params.depth }}m</div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-sm font-medium mb-2">Sound Velocity (Medwin)</div>
      <div class="text-lg font-mono font-bold text-blue-500">{{ soundVelocity.toFixed(1) }} m/s</div>
      <div class="text-xs text-text-secondary mt-1">
        Formula: v = 1449 + 4.6T - 0.055T² + 0.016D + (1.3-0.1T)(S-35)
      </div>
    </div>

    <button
      @click="calibrate"
      class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 rounded transition"
    >
      ✓ Calibrate
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { calibrateEnvironment } from '../services/api'

interface EnvironmentalParams {
  temperature: number
  salinity: number
  depth: number
}

const props = defineProps<{
  params: EnvironmentalParams
}>()

const emit = defineEmits<{
  updateParams: [params: EnvironmentalParams]
}>()

const soundVelocity = computed(() => {
  const T = props.params.temperature
  const S = props.params.salinity
  const D = props.params.depth

  // Medwin formula
  const v = 1449 + 4.6*T - 0.055*T*T + 0.016*D + (1.3 - 0.1*T)*(S - 35)
  return v
})

const updateParam = (key: keyof EnvironmentalParams, event: Event) => {
  const value = parseFloat((event.target as HTMLInputElement).value)
  emit('updateParams', {
    ...props.params,
    [key]: value
  })
}

const calibrate = async () => {
  try {
    const response = await calibrateEnvironment({
      temperature_c: props.params.temperature,
      salinity_psu: props.params.salinity,
      depth_m: props.params.depth
    })
    console.log('Calibration response:', response)
  } catch (err) {
    console.error('Calibration failed:', err)
  }
}
</script>
