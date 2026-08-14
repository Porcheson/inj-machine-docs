<template>
  <span class="animated-number">{{ displayValue }}</span>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'

const props = withDefaults(defineProps<{
  value: number
  duration?: number
  suffix?: string
}>(), {
  duration: 2000,
  suffix: ''
})

const currentValue = ref(0)

const displayValue = computed(() => {
  const val = Math.floor(currentValue.value)
  return props.suffix ? `${val}${props.suffix}` : val.toString()
})

onMounted(() => {
  const startTime = performance.now()
  const startValue = 0
  const endValue = props.value

  const animate = (currentTime: number) => {
    const elapsed = currentTime - startTime
    const progress = Math.min(elapsed / props.duration, 1)

    const easeOutQuart = 1 - Math.pow(1 - progress, 4)
    currentValue.value = startValue + (endValue - startValue) * easeOutQuart

    if (progress < 1) {
      requestAnimationFrame(animate)
    }
  }

  requestAnimationFrame(animate)
})
</script>

<style scoped>
.animated-number {
  font-variant-numeric: tabular-nums;
}
</style>