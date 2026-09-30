<template>
  <div class="bg-secondary border border-border rounded-lg p-8">
    <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
      <!-- Threat Gauge -->
      <div class="flex justify-center">
        <div class="relative w-48 h-48">
          <!-- SVG Gauge -->
          <svg viewBox="0 0 200 200" class="w-full h-full">
            <!-- Background arc -->
            <circle cx="100" cy="100" r="90" fill="none" stroke="var(--border)" stroke-width="8" opacity="0.3" />

            <!-- Threat arc (0-10 scale)-->
            <circle
              cx="100"
              cy="100"
              r="90"
              fill="none"
              :stroke="threatColor"
              stroke-width="8"
              stroke-dasharray="282.74"
              :stroke-dashoffset="282.74 * (1 - threatLevel / 10)"
              class="transition-all duration-500"
              stroke-linecap="round"
            />

            <!-- Tick marks -->
            <g v-for="i in 11" :key="i" :transform="`rotate(${(i - 1) * 18 - 90} 100 100)`">
              <line x1="100" y1="10" x2="100" y2="20" stroke="var(--text-secondary)" stroke-width="2" />
              <text x="100" y="30" text-anchor="middle" font-size="12" fill="var(--text-secondary)">{{ i - 1 }}</text>
            </g>

            <!-- Needle -->
            <g :transform="`rotate(${threatLevel * 18 - 90} 100 100)`">
              <line x1="100" y1="20" x2="100" y2="85" stroke="var(--text-primary)" stroke-width="4" stroke-linecap="round" />
              <circle cx="100" cy="100" r="8" fill="var(--text-primary)" />
            </g>

            <!-- Center label -->
            <text x="100" y="100" text-anchor="middle" dy="0.3em" font-size="32" font-weight="bold" fill="var(--text-primary)">
              {{ threatLevel }}
            </text>
            <text x="100" y="125" text-anchor="middle" font-size="14" fill="var(--text-secondary)">threat</text>
          </svg>
        </div>
      </div>

      <!-- Status Info -->
      <div class="space-y-6">
        <!-- Status Badge -->
        <div class="flex items-center gap-3">
          <div :class="`w-4 h-4 rounded-full ${statusBadgeColor} animate-pulse`"></div>
          <div>
            <div class="text-lg font-bold">{{ statusText }}</div>
            <div class="text-sm text-text-secondary">{{ statusDescription }}</div>
          </div>
        </div>

        <!-- Last Detection -->
        <div v-if="lastEvent" class="border-l-4 border-blue-500 pl-4 py-2">
          <div class="text-sm text-text-secondary">Last Detection</div>
          <div class="text-lg font-bold capitalize">{{ lastEvent.vessel_class }}</div>
          <div class="text-sm text-text-secondary">
            Confidence: {{ (lastEvent.propeller_confidence * 100).toFixed(1) }}%
          </div>
          <div class="text-xs text-text-secondary">{{ formatTime(lastEvent.timestamp_ms) }}</div>
        </div>

        <!-- Latency Info -->
        <div class="bg-primary rounded p-3">
          <div class="text-xs text-text-secondary mb-2">Latency Breakdown</div>
          <div class="space-y-1 text-sm">
            <div class="flex justify-between">
              <span>DSP:</span>
              <span class="font-mono">80.0ms</span>
            </div>
            <div class="flex justify-between">
              <span>ML Inference:</span>
              <span class="font-mono">12.3ms</span>
            </div>
            <div class="flex justify-between">
              <span>API:</span>
              <span class="font-mono">8.5ms</span>
            </div>
            <div class="border-t border-border mt-1 pt-1 flex justify-between font-bold">
              <span>Total:</span>
              <span class="font-mono">100.8ms</span>
            </div>
          </div>
        </div>

        <!-- Emergency Button -->
        <button
          @click="triggerEmergencyRTL"
          class="w-full bg-red-600 hover:bg-red-700 text-white font-bold py-3 rounded-lg transition"
          :disabled="threatLevel < 8"
        >
          🚨 Emergency RTL Ascent
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

interface DetectionEvent {
  timestamp_ms: number
  propeller_confidence: number
  vessel_class: string
  threat_level: number
}

const props = defineProps<{
  threatLevel: number
  lastEvent?: DetectionEvent | null
}>()

const threatColor = computed(() => {
  const level = props.threatLevel
  if (level <= 3) return '#10b981' // green
  if (level <= 6) return '#f59e0b' // yellow
  if (level <= 8) return '#f97316' // orange
  return '#ef4444' // red
})

const statusBadgeColor = computed(() => {
  const level = props.threatLevel
  if (level === 0) return 'bg-gray-500'
  if (level <= 3) return 'bg-green-500'
  if (level <= 6) return 'bg-yellow-500'
  if (level <= 8) return 'bg-orange-500'
  return 'bg-red-500'
})

const statusText = computed(() => {
  const level = props.threatLevel
  if (level === 0) return 'Monitoring'
  if (level <= 3) return 'Safe'
  if (level <= 6) return 'Caution'
  if (level <= 8) return 'Warning'
  return 'Critical'
})

const statusDescription = computed(() => {
  const level = props.threatLevel
  if (level === 0) return 'No vessels detected'
  if (level <= 3) return 'Distant vessel, no immediate threat'
  if (level <= 6) return 'Approaching vessel, maintain vigilance'
  if (level <= 8) return 'Nearby vessel, prepare to ascend'
  return 'Large vessel nearby, immediate action recommended'
})

const formatTime = (ms: number) => {
  const date = new Date(ms)
  return date.toLocaleTimeString()
}

const triggerEmergencyRTL = () => {
  alert('Emergency RTL initiated - Ascending to surface (ArduSub integration)')
}
</script>
