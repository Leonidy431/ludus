<template>
  <div class="space-y-4">
    <div class="grid grid-cols-2 gap-3">
      <div class="bg-primary p-3 rounded border" :class="statusBg">
        <div class="text-xs text-text-secondary mb-1">Current Threat</div>
        <div class="text-2xl font-bold" :class="threatColor">{{ status.threat_level || 0 }}/10</div>
      </div>

      <div class="bg-primary p-3 rounded border border-border">
        <div class="text-xs text-text-secondary mb-1">Last Detection</div>
        <div class="text-sm font-mono">{{ lastDetectionTime }}</div>
      </div>
    </div>

    <div v-if="status.last_event" class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Last Event Details</div>
      <div class="space-y-1 text-sm">
        <div class="flex justify-between">
          <span>Vessel Class:</span>
          <span class="font-bold">{{ status.last_event.vessel_class || 'N/A' }}</span>
        </div>
        <div class="flex justify-between">
          <span>Confidence:</span>
          <span class="font-bold">{{ ((status.last_event.propeller_confidence ?? 0) * 100).toFixed(1) }}%</span>
        </div>
        <div class="flex justify-between">
          <span>Latency:</span>
          <span class="font-bold">{{ status.last_event.total_latency_ms?.toFixed(1) || 'N/A' }}ms</span>
        </div>
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Statistics</div>
      <div class="space-y-1 text-sm">
        <div class="flex justify-between">
          <span>Total Detections:</span>
          <span class="font-bold">{{ status.total_detections || 0 }}</span>
        </div>
        <div class="flex justify-between">
          <span>Avg Latency:</span>
          <span class="font-bold">{{ status.average_latency_ms?.toFixed(1) || 'N/A' }}ms</span>
        </div>
        <div class="flex justify-between">
          <span>P95 Latency:</span>
          <span class="font-bold">{{ status.p95_latency_ms?.toFixed(1) || 'N/A' }}ms</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { fetchDetectionStatus } from '../services/api'

interface DetectionStatusData {
  threat_level?: number
  total_detections?: number
  average_latency_ms?: number
  p95_latency_ms?: number
  last_event?: {
    timestamp_ms?: number
    propeller_confidence?: number
    vessel_class?: string
    total_latency_ms?: number
  }
}

const status = ref<DetectionStatusData>({})
let statusInterval: ReturnType<typeof setInterval> | null = null

const statusBg = computed(() => {
  const level = status.value.threat_level || 0
  if (level >= 8) return 'border-threat-critical bg-red-900/20'
  if (level >= 5) return 'border-threat-warning bg-yellow-900/20'
  return 'border-threat-safe bg-green-900/20'
})

const threatColor = computed(() => {
  const level = status.value.threat_level || 0
  if (level >= 8) return 'text-red-500'
  if (level >= 5) return 'text-yellow-500'
  return 'text-green-500'
})

const lastDetectionTime = computed(() => {
  if (!status.value.last_event?.timestamp_ms) return 'Never'
  const diff = Date.now() - status.value.last_event.timestamp_ms
  if (diff < 1000) return 'Just now'
  if (diff < 60000) return Math.floor(diff / 1000) + 's ago'
  if (diff < 3600000) return Math.floor(diff / 60000) + 'm ago'
  return Math.floor(diff / 3600000) + 'h ago'
})

const fetchStatus = async () => {
  try {
    const response = await fetchDetectionStatus()
    if (response) {
      status.value = response
    }
  } catch (err) {
    console.error('Failed to fetch detection status:', err)
  }
}

onMounted(() => {
  fetchStatus()
  statusInterval = setInterval(fetchStatus, 2000)
})

onUnmounted(() => {
  if (statusInterval) clearInterval(statusInterval)
})
</script>
