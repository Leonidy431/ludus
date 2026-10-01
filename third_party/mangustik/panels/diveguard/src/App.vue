<template>
  <div class="min-h-screen bg-primary text-text-primary transition-colors duration-200">
    <!-- Header -->
    <header class="bg-secondary border-b border-border sticky top-0 z-50">
      <div class="max-w-7xl mx-auto px-4 py-4 flex justify-between items-center">
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 bg-blue-500 rounded-lg flex items-center justify-center">
            <span class="text-white font-bold text-sm">🐚</span>
          </div>
          <h1 class="text-2xl font-bold">DiveGuard Monitor</h1>
          <span class="text-sm text-text-secondary">Propeller Detection System</span>
        </div>

        <div class="flex items-center gap-6">
          <div class="hidden md:block text-right text-sm">
            <SystemStatus />
          </div>

          <button @click="toggleDarkMode" class="p-2 hover:bg-primary rounded-lg transition">
            <span>{{ isDark ? '☀️' : '🌙' }}</span>
          </button>
        </div>
      </div>

      <!-- Module Tabs (CONTROL_INTERFACE_TZ.md Phase 6 - unified operator dashboard) -->
      <nav class="max-w-7xl mx-auto px-4 border-t border-border">
        <div class="flex gap-1">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            :data-testid="`tab-${tab.id}`"
            @click="activeTab = tab.id"
            class="px-4 py-2 text-sm font-medium border-b-2 transition"
            :class="
              activeTab === tab.id
                ? 'border-blue-500 text-blue-500'
                : 'border-transparent text-text-secondary hover:text-text-primary'
            "
          >
            {{ tab.label }}
          </button>
        </div>
      </nav>
    </header>

    <!-- Main Content -->
    <main class="max-w-7xl mx-auto px-4 py-6">
      <div v-if="activeTab === 'diveguard'">
        <!-- Threat Indicator (Top) -->
        <div class="mb-6">
          <ThreatIndicator :threat-level="detectionStore.threatLevel" :last-event="detectionStore.lastEvent" />
        </div>

        <!-- Dashboard Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          <!-- Spectrogram (Large) -->
          <div class="lg:col-span-2">
            <div class="bg-secondary border border-border rounded-lg p-6">
              <h2 class="text-lg font-bold mb-4">Real-time Spectrogram</h2>
              <SpectrogramChart :recent-data="detectionStore.spectrogramData" />
            </div>
          </div>

          <!-- Status & Metrics Panel (Right) -->
          <div class="space-y-6">
            <div class="bg-secondary border border-border rounded-lg p-6">
              <h3 class="font-bold mb-4">Detection Status</h3>
              <DetectionStatus />
            </div>

            <div class="bg-secondary border border-border rounded-lg p-6">
              <h3 class="font-bold mb-4">System Metrics</h3>
              <MetricsPanel :metrics="detectionStore.metrics" />
            </div>

            <div class="bg-secondary border border-border rounded-lg p-6">
              <h3 class="font-bold mb-4">Environmental</h3>
              <EnvironmentalParams :params="detectionStore.environmental" @update-params="updateEnvironmental" />
            </div>

            <div class="bg-secondary border border-border rounded-lg p-6">
              <h3 class="font-bold mb-4">Detection Thresholds</h3>
              <ThresholdConfig />
            </div>
          </div>
        </div>

        <!-- Detection Timeline (Full Width) -->
        <div class="bg-secondary border border-border rounded-lg p-6">
          <h2 class="text-lg font-bold mb-4">Detection History</h2>
          <DetectionTimeline :events="detectionStore.detectionHistory" :total="detectionStore.totalDetections" />
        </div>
      </div>

      <div v-else-if="activeTab === 'dive-buddy'" class="bg-secondary border border-border rounded-lg p-6">
        <h2 class="text-lg font-bold mb-4">Dive-Buddy Mission</h2>
        <DiveBuddyPanel />
      </div>

      <div v-else-if="activeTab === 'companion-bridge'" class="bg-secondary border border-border rounded-lg p-6">
        <h2 class="text-lg font-bold mb-4">Companion Bridge</h2>
        <CompanionBridgePanel />
      </div>

      <div v-else-if="activeTab === 'gaz2410'" class="bg-secondary border border-border rounded-lg p-6">
        <h2 class="text-lg font-bold mb-4">GAZ-2410 HUD</h2>
        <Gaz2410Panel />
      </div>
    </main>

    <!-- Alert Notifications -->
    <AlertNotifier :alerts="alerts" />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useDetectionStore } from './stores/detection'
import ThreatIndicator from './components/ThreatIndicator.vue'
import SpectrogramChart from './components/SpectrogramChart.vue'
import MetricsPanel from './components/MetricsPanel.vue'
import DetectionStatus from './components/DetectionStatus.vue'
import SystemStatus from './components/SystemStatus.vue'
import EnvironmentalParams from './components/EnvironmentalParams.vue'
import ThresholdConfig from './components/ThresholdConfig.vue'
import DetectionTimeline from './components/DetectionTimeline.vue'
import AlertNotifier from './components/AlertNotifier.vue'
import DiveBuddyPanel from './components/DiveBuddyPanel.vue'
import CompanionBridgePanel from './components/CompanionBridgePanel.vue'
import Gaz2410Panel from './components/Gaz2410Panel.vue'
import { initWebSocket, closeWebSocket } from './services/websocket'
import { fetchSystemHealth } from './services/api'

const detectionStore = useDetectionStore()
const isDark = ref(localStorage.getItem('dark-mode') === 'true')
const systemStatus = ref('Connected')
const alerts = ref<any[]>([])

const tabs = [
  { id: 'diveguard', label: '🐚 DiveGuard' },
  { id: 'dive-buddy', label: '🤿 Dive-Buddy' },
  { id: 'companion-bridge', label: '🔗 Companion Bridge' },
  { id: 'gaz2410', label: '🚗 GAZ-2410' },
] as const
type TabId = (typeof tabs)[number]['id']
const activeTab = ref<TabId>('diveguard')

const toggleDarkMode = () => {
  isDark.value = !isDark.value
  localStorage.setItem('dark-mode', isDark.value.toString())
  document.documentElement.setAttribute('data-theme', isDark.value ? 'dark' : 'light')
}

const updateEnvironmental = (params: any) => {
  detectionStore.updateEnvironmental(params)
}

const addAlert = (message: string, type: 'success' | 'warning' | 'critical' | 'info') => {
  const id = Date.now()
  alerts.value.push({ id, message, type })
  if (type !== 'critical') {
    setTimeout(() => {
      alerts.value = alerts.value.filter(a => a.id !== id)
    }, 5000)
  }
}

onMounted(async () => {
  // Load dark mode preference
  if (isDark.value) {
    document.documentElement.setAttribute('data-theme', 'dark')
  }

  // Start WebSocket
  try {
    await initWebSocket((event: any) => {
      detectionStore.addDetection(event)
      if (event.threat_level >= 8) {
        addAlert(`🚨 CRITICAL: ${event.vessel_class} detected! Threat ${event.threat_level}/10`, 'critical')
      }
    })
    systemStatus.value = 'Connected'
  } catch (err) {
    console.error('WebSocket failed:', err)
    systemStatus.value = 'Offline'
    addAlert('Failed to connect to DiveGuard server', 'warning')
  }

  // Fetch system health periodically
  const healthInterval = setInterval(async () => {
    try {
      const health = await fetchSystemHealth()
      detectionStore.updateSystemHealth(health)
    } catch (err) {
      console.error('Health check failed:', err)
      systemStatus.value = 'Disconnected'
    }
  }, 5000)

  return () => clearInterval(healthInterval)
})

onUnmounted(() => {
  closeWebSocket()
})
</script>

<style>
:root {
  --bg-primary: #ffffff;
  --bg-secondary: #f3f4f6;
  --text-primary: #111827;
  --text-secondary: #6b7280;
  --border: #e5e7eb;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg-primary: #1f2937;
    --bg-secondary: #111827;
    --text-primary: #f3f4f6;
    --text-secondary: #9ca3af;
    --border: #374151;
  }
}

[data-theme="dark"] {
  --bg-primary: #1f2937;
  --bg-secondary: #111827;
  --text-primary: #f3f4f6;
  --text-secondary: #9ca3af;
  --border: #374151;
}

body {
  background-color: var(--bg-primary);
  color: var(--text-primary);
}
</style>
