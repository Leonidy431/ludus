<template>
  <div class="w-full h-96 relative">
    <canvas ref="canvasRef" class="w-full h-full"></canvas>
    <div class="absolute bottom-0 left-0 right-0 h-12 bg-gradient-to-r from-blue-600 via-cyan-500 to-yellow-500 opacity-70 flex items-center justify-between px-4">
      <span class="text-xs text-white font-mono">0 Hz</span>
      <span class="text-xs text-white font-mono">12 kHz</span>
      <span class="text-xs text-white font-mono">24 kHz</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUpdated } from 'vue'

interface SpecData {
  frequencies: number[]
  magnitude: number[]
  bpf?: number
  timestamp: number
}

defineProps<{
  recentData: SpecData[]
}>()

const canvasRef = ref<HTMLCanvasElement | null>(null)

const drawSpectrogram = () => {
  const canvas = canvasRef.value
  if (!canvas) return

  const ctx = canvas.getContext('2d')
  if (!ctx) return

  canvas.width = canvas.offsetWidth
  canvas.height = canvas.offsetHeight

  const width = canvas.width
  const height = canvas.height
  const padLeft = 40
  const padBottom = 40

  // Draw background
  ctx.fillStyle = 'var(--bg-primary)'
  ctx.fillRect(0, 0, width, height)

  // Draw axes
  ctx.strokeStyle = 'var(--border)'
  ctx.lineWidth = 1
  ctx.beginPath()
  ctx.moveTo(padLeft, 0)
  ctx.lineTo(padLeft, height - padBottom)
  ctx.lineTo(width, height - padBottom)
  ctx.stroke()

  // Draw axis labels
  ctx.fillStyle = 'var(--text-secondary)'
  ctx.font = '12px monospace'
  ctx.textAlign = 'center'
  for (let i = 0; i <= 24; i += 6) {
    const x = padLeft + ((i / 24) * (width - padLeft))
    ctx.fillText(`${i}k`, x, height - 10)
  }

  // Draw colorful spectrum visualization
  const gradient = ctx.createLinearGradient(padLeft, 0, width, 0)
  gradient.addColorStop(0, '#1e40af')    // blue
  gradient.addColorStop(0.25, '#0891b2') // cyan
  gradient.addColorStop(0.5, '#06b6d4')  // light cyan
  gradient.addColorStop(0.75, '#eab308') // yellow
  gradient.addColorStop(1, '#dc2626')    // red

  ctx.fillStyle = gradient
  ctx.fillRect(padLeft, 0, width - padLeft, height - padBottom)

  // Draw BPF marker (example: 150 Hz for 300 RPM)
  const bpfHz = 150
  const bpfX = padLeft + ((bpfHz / 24000) * (width - padLeft))
  ctx.strokeStyle = '#ffffff'
  ctx.lineWidth = 2
  ctx.setLineDash([4, 4])
  ctx.beginPath()
  ctx.moveTo(bpfX, 0)
  ctx.lineTo(bpfX, height - padBottom)
  ctx.stroke()
  ctx.setLineDash([])

  ctx.fillStyle = '#ffffff'
  ctx.font = 'bold 12px monospace'
  ctx.textAlign = 'center'
  ctx.fillText('BPF', bpfX, 15)
}

onMounted(() => {
  drawSpectrogram()
})

onUpdated(() => {
  drawSpectrogram()
})
</script>
