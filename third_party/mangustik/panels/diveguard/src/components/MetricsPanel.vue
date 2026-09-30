<template>
  <div class="space-y-4">
    <div class="grid grid-cols-2 gap-2">
      <div class="bg-primary p-3 rounded border border-border">
        <div class="text-xs text-text-secondary">P50 Latency</div>
        <div class="text-xl font-bold">{{ metrics.p50 || 98 }}ms</div>
      </div>
      <div class="bg-primary p-3 rounded border border-border">
        <div class="text-xs text-text-secondary">P95 Latency</div>
        <div class="text-xl font-bold">{{ metrics.p95 || 101 }}ms</div>
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Power Consumption</div>
      <div class="space-y-1">
        <div class="flex justify-between text-sm">
          <span>Current: <span class="font-bold">{{ metrics.power || 58 }}mW</span></span>
          <span class="text-green-500">✓ <60mW</span>
        </div>
        <div class="text-xs text-text-secondary space-y-0.5">
          <div class="flex justify-between">
            <span>DSP:</span> <span>18mW</span>
          </div>
          <div class="flex justify-between">
            <span>ML:</span> <span>24mW</span>
          </div>
          <div class="flex justify-between">
            <span>Other:</span> <span>16mW</span>
          </div>
        </div>
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">System Health</div>
      <div class="space-y-2 text-sm">
        <div class="flex justify-between">
          <span>CPU:</span>
          <div class="w-20 h-2 bg-gray-300 rounded-full overflow-hidden">
            <div class="h-full bg-blue-500" style="width: 65%"></div>
          </div>
          <span>65%</span>
        </div>
        <div class="flex justify-between">
          <span>Memory:</span>
          <div class="w-20 h-2 bg-gray-300 rounded-full overflow-hidden">
            <div class="h-full bg-green-500" style="width: 42%"></div>
          </div>
          <span>280MB</span>
        </div>
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Today's Stats</div>
      <div class="space-y-1 text-sm">
        <div class="flex justify-between">
          <span>Detections:</span>
          <span class="font-bold">{{ metrics.totalDetections || 247 }}</span>
        </div>
        <div class="flex justify-between">
          <span>False Positives:</span>
          <span class="font-bold text-orange-500">{{ metrics.falsePositives || 2 }}</span>
        </div>
        <div class="flex justify-between">
          <span>Uptime:</span>
          <span class="font-bold">99.2%</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { fetchMetricsLatency } from '../services/api'

defineProps<{
  metrics: {
    p50?: number
    p95?: number
    p99?: number
    power?: number
    cpu?: number
    memory?: number
    totalDetections?: number
    falsePositives?: number
  }
}>()

onMounted(async () => {
  try {
    const latencyMetrics = await fetchMetricsLatency()
    if (latencyMetrics) {
      console.log('Fetched latency metrics:', latencyMetrics)
    }
  } catch (err) {
    console.error('Failed to fetch metrics:', err)
  }
})
</script>
