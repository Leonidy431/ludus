import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

interface DetectionEvent {
  timestamp_ms: number
  propeller_confidence: number
  vessel_class: string
  threat_level: number
  total_latency_ms?: number
  environmental?: {
    temperature_c: number
    salinity_psu: number
    depth_m: number
  }
}

export const useDetectionStore = defineStore('detection', () => {
  // State
  const detectionHistory = ref<DetectionEvent[]>([])
  const threatLevel = ref(0)
  const lastEvent = ref<DetectionEvent | null>(null)
  const spectrogramData = ref<any[]>([])
  const totalDetections = ref(0)

  const metrics = ref({
    p50: 98,
    p95: 101,
    p99: 105,
    power: 58,
    cpu: 65,
    memory: 280,
    totalDetections: 0,
    falsePositives: 2
  })

  const environmental = ref({
    temperature: 18.5,
    salinity: 35.0,
    depth: 25.0
  })

  // Computed
  const recentDetections = computed(() => detectionHistory.value.slice(-50))

  // Actions
  const addDetection = (event: DetectionEvent) => {
    detectionHistory.value.unshift(event)
    if (detectionHistory.value.length > 1000) {
      detectionHistory.value.pop()
    }

    lastEvent.value = event
    threatLevel.value = event.threat_level
    totalDetections.value++

    // Update metrics
    metrics.value.totalDetections = totalDetections.value
  }

  const updateEnvironmental = (params: any) => {
    environmental.value = {
      temperature: params.temperature || environmental.value.temperature,
      salinity: params.salinity || environmental.value.salinity,
      depth: params.depth || environmental.value.depth
    }
  }

  const updateSystemHealth = (health: any) => {
    if (health.metrics) {
      metrics.value = {
        ...metrics.value,
        ...health.metrics
      }
    }

    if (health.threat_level !== undefined) {
      threatLevel.value = health.threat_level
    }
  }

  const clearHistory = () => {
    detectionHistory.value = []
    totalDetections.value = 0
  }

  return {
    detectionHistory,
    threatLevel,
    lastEvent,
    spectrogramData,
    totalDetections,
    metrics,
    environmental,
    recentDetections,
    addDetection,
    updateEnvironmental,
    updateSystemHealth,
    clearHistory
  }
})
