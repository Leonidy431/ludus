<template>
  <div class="space-y-4">
    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">MAVLink Router</div>
      <div class="space-y-1 text-sm">
        <div class="flex justify-between">
          <span>Connected:</span>
          <span class="font-bold" data-testid="mavlink-connected">
            {{ mavlinkStatus?.connected ? 'yes' : 'no' }}
          </span>
        </div>
        <div class="flex justify-between">
          <span>Messages routed:</span>
          <span class="font-bold">{{ mavlinkStatus?.messages_routed ?? 0 }}</span>
        </div>
        <div class="flex justify-between">
          <span>Outputs:</span>
          <span class="font-bold">{{ mavlinkStatus?.output_endpoints?.length ?? 0 }}</span>
        </div>
      </div>
    </div>

    <div class="bg-primary p-3 rounded border border-border">
      <div class="text-xs text-text-secondary mb-2">Video Stream</div>
      <div class="space-y-1 text-sm mb-3">
        <div class="flex justify-between">
          <span>Running:</span>
          <span class="font-bold" data-testid="stream-running">
            {{ videoStatus?.is_running ? 'yes' : 'no' }}
          </span>
        </div>
        <div class="flex justify-between">
          <span>Protocol:</span>
          <span class="font-bold">{{ videoStatus?.protocol ?? 'n/a' }}</span>
        </div>
        <div class="flex justify-between">
          <span>Bitrate:</span>
          <span class="font-bold">{{ videoStatus?.bitrate_kbps ?? 0 }} kbps</span>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <button
          data-testid="stream-start"
          :disabled="isBusy"
          @click="start"
          class="bg-green-600 hover:bg-green-700 disabled:bg-gray-400 text-white font-bold py-2 rounded transition text-sm"
        >
          ▶ Start
        </button>
        <button
          data-testid="stream-stop"
          :disabled="isBusy"
          @click="stop"
          class="bg-red-600 hover:bg-red-700 disabled:bg-gray-400 text-white font-bold py-2 rounded transition text-sm"
        >
          ■ Stop
        </button>
      </div>
      <div v-if="errorMessage" class="text-xs text-threat-critical mt-2" data-testid="stream-error">
        {{ errorMessage }}
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import {
  fetchMavlinkRouterStatus,
  fetchVideoStreamerStatus,
  startVideoStream,
  stopVideoStream,
  type MavlinkRouterStatus,
  type VideoStreamerStatus,
} from '../services/gatewayApi'

const mavlinkStatus = ref<MavlinkRouterStatus | null>(null)
const videoStatus = ref<VideoStreamerStatus | null>(null)
const isBusy = ref(false)
const errorMessage = ref('')
let statusInterval: ReturnType<typeof setInterval> | null = null

const loadStatus = async () => {
  try {
    mavlinkStatus.value = await fetchMavlinkRouterStatus()
  } catch (err) {
    console.error('Failed to fetch mavlink-router status:', err)
  }
  try {
    videoStatus.value = await fetchVideoStreamerStatus()
  } catch (err) {
    console.error('Failed to fetch video-streamer status:', err)
  }
}

const start = async () => {
  isBusy.value = true
  errorMessage.value = ''
  try {
    videoStatus.value = await startVideoStream()
  } catch (err) {
    errorMessage.value = 'Failed to start video stream'
    console.error(err)
  } finally {
    isBusy.value = false
  }
}

const stop = async () => {
  isBusy.value = true
  errorMessage.value = ''
  try {
    videoStatus.value = await stopVideoStream()
  } catch (err) {
    errorMessage.value = 'Failed to stop video stream'
    console.error(err)
  } finally {
    isBusy.value = false
  }
}

onMounted(() => {
  loadStatus()
  statusInterval = setInterval(loadStatus, 3000)
})

onUnmounted(() => {
  if (statusInterval) clearInterval(statusInterval)
})

defineExpose({ loadStatus, start, stop })
</script>
