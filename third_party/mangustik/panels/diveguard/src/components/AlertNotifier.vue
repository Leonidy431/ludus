<template>
  <div class="fixed top-4 right-4 space-y-2 z-50">
    <div
      v-for="alert in alerts"
      :key="alert.id"
      :class="`px-4 py-3 rounded-lg text-white font-medium animate-slideIn transition-all duration-300 flex items-center gap-2 max-w-sm shadow-lg ${alertClass(alert.type)}`"
    >
      <span>{{ alert.message }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  alerts: Array<{
    id: number
    message: string
    type: 'success' | 'warning' | 'critical' | 'info'
  }>
}>()

const alertClass = (type: string) => {
  switch (type) {
    case 'success':
      return 'bg-green-600'
    case 'warning':
      return 'bg-yellow-600'
    case 'critical':
      return 'bg-red-600 animate-pulse'
    case 'info':
      return 'bg-blue-600'
    default:
      return 'bg-gray-600'
  }
}
</script>

<style scoped>
@keyframes slideIn {
  from {
    transform: translateX(400px);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

.animate-slideIn {
  animation: slideIn 0.3s ease-out;
}
</style>
