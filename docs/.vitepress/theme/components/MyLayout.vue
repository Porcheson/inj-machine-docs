<!-- .vitepress/theme/MyLayout.vue -->

<script setup lang="ts">
import { useData, useRoute } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import backtotop from "./backtotop.vue"
import ArticleMetadata from "./ArticleMetadata.vue"
import { ref, onMounted, watch } from 'vue'

const { isDark } = useData()
const route = useRoute()

// 简化的主题切换
const toggleTheme = () => {
  isDark.value = !isDark.value
}

// 鼠标特效组件引用
const mouseEffectsLoaded = ref(false)

// 异步加载鼠标特效
const loadMouseEffects = async () => {
  if (mouseEffectsLoaded.value) return
  
  console.log('开始加载鼠标特效')
  
  try {
    // 直接渲染到页面，不使用动态导入Vue
    const mouseEffectsContainer = document.createElement('div')
    mouseEffectsContainer.id = 'mouse-effects-container'
    mouseEffectsContainer.style.position = 'fixed'
    mouseEffectsContainer.style.top = '0'
    mouseEffectsContainer.style.left = '0'
    mouseEffectsContainer.style.width = '100%'
    mouseEffectsContainer.style.height = '100%'
    mouseEffectsContainer.style.pointerEvents = 'none'
    mouseEffectsContainer.style.zIndex = '999999'
    
    // 添加MouseFollower
    const followerCanvas = document.createElement('canvas')
    followerCanvas.style.position = 'fixed'
    followerCanvas.style.left = '0'
    followerCanvas.style.top = '0'
    followerCanvas.style.pointerEvents = 'none'
    followerCanvas.style.zIndex = '999999'
    mouseEffectsContainer.appendChild(followerCanvas)
    
    // 添加MouseClick
    const clickContainer = document.createElement('div')
    clickContainer.style.position = 'fixed'
    clickContainer.style.left = '0'
    clickContainer.style.top = '0'
    clickContainer.style.width = '100%'
    clickContainer.style.height = '100%'
    clickContainer.style.pointerEvents = 'none'
    clickContainer.style.zIndex = '999999'
    mouseEffectsContainer.appendChild(clickContainer)
    
    document.body.appendChild(mouseEffectsContainer)
    
    // 直接加载MouseFollower逻辑
    const ctx = followerCanvas.getContext('2d')
    let particles: Particle[] = []
    let mouse = { x: window.innerWidth / 2, y: window.innerHeight / 2 }
    let targetMouse = { x: window.innerWidth / 2, y: window.innerHeight / 2 }
    let lastMouse = { x: window.innerWidth / 2, y: window.innerHeight / 2 }
    
    class Particle {
      constructor() {
        this.reset()
      }
      reset() {
        this.angle = Math.random() * Math.PI * 2
        this.radius = Math.random() * 40 + 25
        this.speed = (Math.random() * 2 + 2) * 0.01
        this.size = Math.random() * 3 + 1
        this.hue = Math.random() * 360
        this.clockwise = Math.random() > 0.5
        this.offsetX = (Math.random() - 0.5) * 10
        this.offsetY = (Math.random() - 0.5) * 10
        this.life = Math.random() * 0.5 + 0.5
        this.maxLife = this.life
        this.trail = []
        this.trailLength = Math.floor(Math.random() * 3) + 2
      }
      update() {
        this.angle += this.speed * (this.clockwise ? 1 : -1)
        const targetX = mouse.x + Math.cos(this.angle) * this.radius + this.offsetX
        const targetY = mouse.y + Math.sin(this.angle) * this.radius + this.offsetY
        if (!this.x) {
          this.x = targetX
          this.y = targetY
        }
        const dx = targetX - this.x
        const dy = targetY - this.y
        this.x += dx * 0.15
        this.y += dy * 0.15
        this.trail.unshift({ x: this.x, y: this.y })
        if (this.trail.length > this.trailLength) {
          this.trail.pop()
        }
        this.life -= 0.002
        if (this.life <= 0) {
          this.reset()
        }
      }
      draw() {
        if (!ctx) return
        const alpha = this.life / this.maxLife
        if (this.trail.length > 1) {
          ctx.beginPath()
          ctx.moveTo(this.trail[0].x, this.trail[0].y)
          for (let i = 1; i < this.trail.length; i++) {
            const point = this.trail[i]
            ctx.lineTo(point.x, point.y)
          }
          ctx.strokeStyle = `hsla(${this.hue}, 70%, 60%, ${alpha * 0.5})`
          ctx.lineWidth = this.size
          ctx.lineCap = "round"
          ctx.stroke()
        }
        ctx.fillStyle = `hsla(${this.hue}, 70%, 60%, ${alpha})`
        ctx.beginPath()
        ctx.arc(this.x, this.y, this.size * 0.5, 0, Math.PI * 2)
        ctx.fill()
      }
    }
    
    function updateMousePosition() {
      const dx = targetMouse.x - mouse.x
      const dy = targetMouse.y - mouse.y
      const mouseSpeed = Math.sqrt(
        Math.pow(targetMouse.x - lastMouse.x, 2) + Math.pow(targetMouse.y - lastMouse.y, 2)
      )
      const followSpeed = Math.min(0.15, 0.15 / (1 + mouseSpeed * 0.005))
      mouse.x += dx * followSpeed
      mouse.y += dy * followSpeed
      lastMouse.x = mouse.x
      lastMouse.y = mouse.y
    }
    
    function handleMouseMove(e) {
      targetMouse.x = e.clientX
      targetMouse.y = e.clientY
    }
    
    function animate() {
      if (!ctx || !followerCanvas) return
      ctx.clearRect(0, 0, followerCanvas.width, followerCanvas.height)
      updateMousePosition()
      if (particles.length < 25 && Math.random() < 0.1) {
        particles.push(new Particle())
      }
      particles.forEach((particle) => {
        particle.update()
        particle.draw()
      })
      requestAnimationFrame(animate)
    }
    
    function handleResize() {
      if (!followerCanvas) return
      followerCanvas.width = window.innerWidth
      followerCanvas.height = window.innerHeight
    }
    
    function initParticles() {
      particles = []
      const initialCount = Math.floor(Math.random() * 4) + 12
      for (let i = 0; i < initialCount; i++) {
        particles.push(new Particle())
      }
    }
    
    // 初始化MouseFollower
    handleResize()
    initParticles()
    window.addEventListener("resize", handleResize)
    window.addEventListener("mousemove", handleMouseMove)
    animate()
    
    // 添加MouseClick效果
    window.addEventListener('click', function(e) {
      const circle = document.createElement('div')
      circle.style.position = 'fixed'
      circle.style.left = (e.clientX - 25) + 'px'
      circle.style.top = (e.clientY - 25) + 'px'
      circle.style.width = '50px'
      circle.style.height = '50px'
      circle.style.border = '2px solid #1890ff'
      circle.style.borderRadius = '50%'
      circle.style.pointerEvents = 'none'
      circle.style.zIndex = '999999'
      circle.style.animation = 'clickAnimation 0.6s ease-out'
      
      // 添加动画样式
      const style = document.createElement('style')
      style.textContent = `
        @keyframes clickAnimation {
          0% {
            transform: scale(0);
            opacity: 1;
          }
          100% {
            transform: scale(1);
            opacity: 0;
          }
        }
      `
      document.head.appendChild(style)
      
      clickContainer.appendChild(circle)
      
      setTimeout(() => {
        circle.remove()
      }, 600)
    })
    
    mouseEffectsLoaded.value = true
    console.log('鼠标特效加载成功')
  } catch (error) {
    console.error('加载鼠标特效失败:', error)
  }
}

// 监听页面加载完成
onMounted(() => {
  // 页面加载完成后延迟加载鼠标特效
  window.addEventListener('load', () => {
    // 延迟1秒加载，确保核心内容已渲染
    setTimeout(loadMouseEffects, 1000)
  })
  
  // 如果页面已经加载完成，直接加载
  if (document.readyState === 'complete') {
    setTimeout(loadMouseEffects, 1000)
  }
})

// 监听路由变化，重新加载特效
watch(() => route.path, () => {
  // 路由变化时不重新加载，保持特效持续运行
})
</script>

<template>
  <DefaultTheme.Layout v-bind="$attrs">
    <template #doc-after>
      <ArticleMetadata />
    </template>
    <template #doc-footer-before>
      <backtotop />
    </template>
  </DefaultTheme.Layout>
</template>

<style>
.VPSwitchAppearance .check {
  transform: none !important;
}

/* 修正因视图过渡导致的月牙图标偏移 */
.VPSwitchAppearance .check .icon {
  top: -2px;
}
</style>