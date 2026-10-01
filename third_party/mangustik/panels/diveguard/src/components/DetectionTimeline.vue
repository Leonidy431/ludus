<template>
  <div class="space-y-4">
    <!-- Stats -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="bg-primary p-3 rounded border border-border text-center">
        <div class="text-xs text-text-secondary">Total Events</div>
        <div class="text-2xl font-bold">{{ total }}</div>
      </div>
      <div class="bg-primary p-3 rounded border border-border text-center">
        <div class="text-xs text-text-secondary">Large Vessels</div>
        <div class="text-2xl font-bold text-blue-500">{{ countByClass('large_vessel') }}</div>
      </div>
      <div class="bg-primary p-3 rounded border border-border text-center">
        <div class="text-xs text-text-secondary">Small Vessels</div>
        <div class="text-2xl font-bold text-cyan-500">{{ countByClass('small_vessel') }}</div>
      </div>
      <div class="bg-primary p-3 rounded border border-border text-center">
        <div class="text-xs text-text-secondary">Marine Mammals</div>
        <div class="text-2xl font-bold text-green-500">{{ countByClass('marine_mammal') }}</div>
      </div>
    </div>

    <!-- Timeline Table -->
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-border text-text-secondary">
            <th class="px-4 py-2 text-left">Time</th>
            <th class="px-4 py-2 text-left">Class</th>
            <th class="px-4 py-2 text-center">Confidence</th>
            <th class="px-4 py-2 text-center">Threat</th>
            <th class="px-4 py-2 text-center">Latency</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(event, idx) in displayedEvents"
            :key="idx"
            class="border-b border-border hover:bg-secondary transition"
          >
            <td class="px-4 py-2 font-mono text-xs">{{ formatTime(event.timestamp_ms) }}</td>
            <td class="px-4 py-2 capitalize">
              <span :class="classColors[event.vessel_class] || 'text-gray-500'">
                {{ event.vessel_class }}
              </span>
            </td>
            <td class="px-4 py-2 text-center">{{ (event.propeller_confidence * 100).toFixed(1) }}%</td>
            <td class="px-4 py-2 text-center">
              <span :class="threatColors(event.threat_level)">{{ event.threat_level }}/10</span>
            </td>
            <td class="px-4 py-2 text-center font-mono text-xs">{{ event.total_latency_ms?.toFixed(1) || 'N/A' }}ms</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Pagination -->
    <div class="flex justify-between items-center text-sm">
      <button
        @click="previousPage"
        :disabled="currentPage === 0"
        class="px-4 py-2 bg-primary border border-border rounded hover:bg-secondary disabled:opacity-50 transition"
      >
        ← Previous
      </button>
      <div class="text-text-secondary">
        Page {{ currentPage + 1 }} of {{ totalPages }}
      </div>
      <button
        @click="nextPage"
        :disabled="currentPage >= totalPages - 1"
        class="px-4 py-2 bg-primary border border-border rounded hover:bg-secondary disabled:opacity-50 transition"
      >
        Next →
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

interface DetectionEvent {
  timestamp_ms: number
  propeller_confidence: number
  vessel_class: string
  threat_level: number
  total_latency_ms?: number
}

const props = defineProps<{
  events: DetectionEvent[]
  total: number
}>()

const currentPage = ref(0)
const pageSize = 10

const displayedEvents = computed(() => {
  const start = currentPage.value * pageSize
  return props.events.slice(start, start + pageSize)
})

const totalPages = computed(() => {
  return Math.ceil(props.events.length / pageSize)
})

const classColors: Record<string, string> = {
  large_vessel: 'text-blue-600 font-bold',
  small_vessel: 'text-cyan-600',
  marine_mammal: 'text-green-600',
  ambient: 'text-gray-500',
}

const threatColors = (level: number) => {
  if (level <= 3) return 'text-green-600 font-bold'
  if (level <= 6) return 'text-yellow-600 font-bold'
  if (level <= 8) return 'text-orange-600 font-bold'
  return 'text-red-600 font-bold'
}

const formatTime = (ms: number) => {
  const date = new Date(ms)
  return date.toLocaleTimeString()
}

const countByClass = (className: string) => {
  return props.events.filter(e => e.vessel_class === className).length
}

const nextPage = () => {
  if (currentPage.value < totalPages.value - 1) {
    currentPage.value++
  }
}

const previousPage = () => {
  if (currentPage.value > 0) {
    currentPage.value--
  }
}
</script>
