<template>
  <canvas ref="canvasRef" class="particles-canvas"></canvas>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useData } from 'vitepress'

const canvasRef = ref<HTMLCanvasElement | null>(null)
let animationId: number
const { isDark } = useData()

interface Particle {
  x: number
  y: number
  vx: number
  vy: number
  size: number
  alpha: number
  colorIndex: number
}

const darkColors = ['#00d4aa', '#00b4d8', '#7209b7', '#f72585', '#4cc9f0']
const lightColors = ['#00b894', '#00a0c8', '#6c5ce7', '#e84393', '#0984e3']

const getColors = () => isDark.value ? darkColors : lightColors

onMounted(() => {
  const canvas = canvasRef.value
  if (!canvas) return

  const ctx = canvas.getContext('2d')
  if (!ctx) return

  const resizeCanvas = () => {
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
  }
  resizeCanvas()
  window.addEventListener('resize', resizeCanvas)

  const particles: Particle[] = []
  const particleCount = 80

  for (let i = 0; i < particleCount; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      vx: (Math.random() - 0.5) * 0.5,
      vy: (Math.random() - 0.5) * 0.5,
      size: Math.random() * 3 + 1,
      alpha: Math.random() * 0.5 + 0.2,
      colorIndex: Math.floor(Math.random() * getColors().length)
    })
  }

  const animate = () => {
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    const colors = getColors()

    particles.forEach((particle, index) => {
      particle.x += particle.vx
      particle.y += particle.vy

      if (particle.x < 0) particle.x = canvas.width
      if (particle.x > canvas.width) particle.x = 0
      if (particle.y < 0) particle.y = canvas.height
      if (particle.y > canvas.height) particle.y = 0

      ctx.beginPath()
      ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2)
      ctx.fillStyle = colors[particle.colorIndex]
      ctx.globalAlpha = particle.alpha
      ctx.fill()

      particles.slice(index + 1).forEach(otherParticle => {
        const dx = particle.x - otherParticle.x
        const dy = particle.y - otherParticle.y
        const distance = Math.sqrt(dx * dx + dy * dy)

        if (distance < 120) {
          ctx.beginPath()
          ctx.moveTo(particle.x, particle.y)
          ctx.lineTo(otherParticle.x, otherParticle.y)
          ctx.strokeStyle = colors[particle.colorIndex]
          ctx.globalAlpha = (120 - distance) / 120 * 0.15
          ctx.lineWidth = 1
          ctx.stroke()
        }
      })
    })

    ctx.globalAlpha = 1
    animationId = requestAnimationFrame(animate)
  }

  animate()

  onUnmounted(() => {
    window.removeEventListener('resize', resizeCanvas)
    cancelAnimationFrame(animationId)
  })
})
</script>

<style scoped>
.particles-canvas {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 0;
  pointer-events: none;
}
</style>