<template>
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium mb-1">Fixed Threshold (0.5-0.85)</label>
      <input
        type="range"
        :value="config.fixed_threshold"
        @input="updateConfig('fixed_threshold', parseFloat(($event.target as HTMLInputElement).value))"
        min="0.5"
        max="0.85"
        step="0.01"
        class="w-full"
      />
      <div class="flex justify-between text-xs text-text-secondary mt-1">
        <span>Min: 0.50</span>
        <span class="font-bold">{{ config.fixed_threshold.toFixed(2) }}</span>
        <span>Max: 0.85</span>
      </div>
    </div>

    <div>
      <label class="block text-sm font-medium mb-1">Whale Rejection Threshold (0.5-1.0)</label>
      <input
        type="range"
        :value="config.whale_rejection_threshold"
        @input="updateConfig('whale_rejection_threshold', parseFloat(($event.target as HTMLInputElement).value))"
        min="0.5"
        max="1.0"
        step="0.01"
        class="w-full"
      />
      <div class="flex justify-between text-xs text-text-secondary mt-1">
        <span>Min: 0.50</span>
        <span class="font-bold">{{ config.whale_rejection_threshold.toFixed(2) }}</span>
        <span>Max: 1.00</span>
      </div>
    </div>

    <div>
      <label class="block text-sm font-medium mb-1">Confidence Minimum (0.3-0.9)</label>
      <input
        type="range"
        :value="config.confidence_min"
        @input="updateConfig('confidence_min', parseFloat(($event.target as HTMLInputElement).value))"
        min="0.3"
        max="0.9"
        step="0.01"
        class="w-full"
      />
      <div class="flex justify-between text-xs text-text-secondary mt-1">
        <span>Min: 0.30</span>
        <span class="font-bold">{{ config.confidence_min.toFixed(2) }}</span>
        <span>Max: 0.90</span>
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <label class="flex items-center gap-2 cursor-pointer">
        <input
          type="checkbox"
          :checked="config.adaptive_enabled"
          @change="updateConfig('adaptive_enabled', !config.adaptive_enabled)"
          class="w-4 h-4 rounded"
        />
        <span class="text-sm font-medium">Enable Adaptive Threshold</span>
      </label>
      <div class="text-xs text-text-secondary mt-2">Bay-specific calibration based on environmental conditions</div>
    </div>

    <button
      @click="save"
      :disabled="isSaving"
      class="w-full bg-green-600 hover:bg-green-700 disabled:bg-gray-400 text-white font-bold py-2 rounded transition"
    >
      {{ isSaving ? '⏳ Saving...' : '💾 Save Configuration' }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getConfigThreshold, setConfigThreshold } from '../services/api'

interface ThresholdConfig {
  fixed_threshold: number
  adaptive_enabled: boolean
  whale_rejection_threshold: number
  confidence_min: number
}

const config = ref<ThresholdConfig>({
  fixed_threshold: 0.70,
  adaptive_enabled: true,
  whale_rejection_threshold: 0.75,
  confidence_min: 0.50
})

const isSaving = ref(false)

const updateConfig = (key: keyof ThresholdConfig, value: any) => {
  (config.value as any)[key] = value
}

const save = async () => {
  isSaving.value = true
  try {
    await setConfigThreshold(config.value)
    console.log('Configuration saved:', config.value)
  } catch (err) {
    console.error('Failed to save configuration:', err)
  } finally {
    isSaving.value = false
  }
}

onMounted(async () => {
  try {
    const response = await getConfigThreshold()
    if (response) {
      config.value = response
    }
  } catch (err) {
    console.error('Failed to load configuration:', err)
  }
})
</script>
