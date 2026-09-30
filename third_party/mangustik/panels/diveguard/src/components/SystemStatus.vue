<template>
  <div class="space-y-3">
    <div class="flex items-center justify-between">
      <span class="text-sm font-medium">API Connection</span>
      <div class="flex items-center gap-2">
        <div class="w-2 h-2 rounded-full" :class="apiConnected ? 'bg-green-500 animate-pulse' : 'bg-red-500'"></div>
        <span class="text-xs" :class="apiConnected ? 'text-green-500' : 'text-red-500'">
          {{ apiConnected ? 'Connected' : 'Disconnected' }}
        </span>
      </div>
    </div>

    <div class="flex items-center justify-between">
      <span class="text-sm font-medium">WebSocket Stream</span>
      <div class="flex items-center gap-2">
        <div class="w-2 h-2 rounded-full" :class="wsConnected ? 'bg-blue-500 animate-pulse' : 'bg-gray-500'"></div>
        <span class="text-xs" :class="wsConnected ? 'text-blue-500' : 'text-gray-500'">
          {{ wsConnected ? 'Streaming' : 'Idle' }}
        </span>
      </div>
    </div>

    <div class="flex items-center justify-between">
      <span class="text-sm font-medium">System Status</span>
      <span class="text-xs font-bold" :class="systemHealthy ? 'text-green-500' : 'text-yellow-500'">
        {{ systemHealthy ? 'Healthy' : 'Degraded' }}
      </span>
    </div>

    <div class="text-xs text-text-secondary pt-2 border-t border-border">
      <div>Version: {{ appVersion }}</div>
      <div>{{ connectedAt }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'

const apiConnected = ref(false)
const wsConnected = ref(false)
const appVersion = ref('1.0.0')
const sessionStart = ref(Date.now())

const systemHealthy = computed(() => apiConnected.value)

const connectedAt = computed(() => {
  const diff = Math.floor((Date.now() - sessionStart.value) / 1000)
  const hours = Math.floor(diff / 3600)
  const minutes = Math.floor((diff % 3600) / 60)
  return `Session: ${hours}h ${minutes}m`
})

const checkApiConnection = async () => {
  try {
    const response = await fetch('http://localhost:8083/v1/health', {
      signal: AbortSignal.timeout(3000)
    })
    apiConnected.value = response.ok
  } catch (err) {
    apiConnected.value = false
  }
}

onMounted(() => {
  checkApiConnection()
  setInterval(checkApiConnection, 5000)
})
</script>
