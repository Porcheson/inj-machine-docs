<template>
  <div class="recent-updates">
    <div 
      class="update-item" 
      v-for="(item, index) in updates" 
      :key="index"
      :style="{ animationDelay: `${index * 0.1}s` }"
    >
      <div class="update-indicator"></div>
      <div class="update-date-wrap">
        <div class="update-day">{{ formatDay(item.date) }}</div>
        <div class="update-month">{{ formatMonth(item.date) }}</div>
      </div>
      <div class="update-info">
        <a :href="withBase(item.link)" class="update-title">
          <span class="update-icon">📄</span>
          {{ item.title }}
        </a>
        <div class="update-desc">{{ item.desc }}</div>
      </div>
      <div class="update-arrow">→</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useData } from 'vitepress'

const { site } = useData()
const base = site.value.base || ''

// 拼接 base 路径，确保链接在子路径部署下也能正常工作
const withBase = (link: string) => {
  if (!link) return base || '/'
  if (link.startsWith('http')) return link
  const normalizedLink = link.startsWith('/') ? link.slice(1) : link
  const normalizedBase = base.endsWith('/') ? base : base + '/'
  return normalizedBase + normalizedLink
}

const updates = [
  {
    date: '2026-07-19',
    link: '/会议记录/20260708项目进展沟通会',
    title: '7月8日项目进展沟通会',
    desc: '会议记录：各单元开发状态、7月15日上机节点准备情况'
  },
  {
    date: '2026-07-19',
    link: '/会议记录/20260617项目进展沟通会',
    title: '6月17日项目进展沟通会',
    desc: '会议记录：新版本软件开发进展、AI集成方案、内存优化策略'
  },
  {
    date: '2026-07-19',
    link: '/会议记录/20260527项目进展沟通会',
    title: '5月27日项目进展沟通会',
    desc: '会议记录：项目延期至9月交付、编译器开发、运动控制模块进展'
  },
  {
    date: '2026-07-03',
    link: '/IM_SYS_PRG/伺服系统资料/液压库参数读写接口设计文档',
    title: '液压库参数读写接口设计文档',
    desc: '更新液压控制库文档，增加MaxSpeed变量'
  }
]

const formatDay = (dateStr: string) => {
  const date = new Date(dateStr)
  return date.getDate().toString().padStart(2, '0')
}

const formatMonth = (dateStr: string) => {
  const date = new Date(dateStr)
  return `${date.getMonth() + 1}月`
}
</script>

<style scoped>
.recent-updates {
  max-width: 100%;
  margin: 0 auto;
}

.update-item {
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 24px 28px;
  background: linear-gradient(145deg, rgba(255, 255, 255, 0.03) 0%, rgba(255, 255, 255, 0.01) 100%);
  border: 1px solid rgba(0, 212, 170, 0.1);
  border-radius: 16px;
  margin-bottom: 16px;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  position: relative;
  overflow: hidden;
  backdrop-filter: blur(10px);
  animation: updateSlideIn 0.5s ease-out both;
}

@keyframes updateSlideIn {
  from {
    opacity: 0;
    transform: translateX(-30px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

.update-item::before {
  content: '';
  position: absolute;
  inset: 0;
  background: var(--gradient-accent);
  opacity: 0;
  transition: opacity 0.4s ease;
}

.update-item:hover {
  transform: translateX(8px);
  border-color: rgba(0, 212, 170, 0.4);
  box-shadow: 
    0 8px 32px rgba(0, 212, 170, 0.12),
    0 0 40px rgba(0, 212, 170, 0.05);
}

.update-indicator {
  width: 4px;
  height: 40px;
  background: var(--gradient-accent);
  border-radius: 2px;
  flex-shrink: 0;
  transition: height 0.3s ease;
}

.update-item:hover .update-indicator {
  height: 60px;
}

.update-date-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-width: 60px;
  padding: 12px;
  background: rgba(0, 212, 170, 0.06);
  border-radius: 12px;
  border: 1px solid rgba(0, 212, 170, 0.1);
}

.update-day {
  font-size: 28px;
  font-weight: 900;
  color: var(--vp-c-brand-1);
  line-height: 1;
}

.update-month {
  font-size: 12px;
  color: var(--vp-c-text-2);
  margin-top: 4px;
  font-weight: 500;
}

.update-info {
  flex: 1;
  min-width: 0;
}

.update-title {
  font-size: 16px;
  color: var(--vp-c-text-1);
  font-weight: 600;
  text-decoration: none;
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 6px;
  transition: all 0.3s ease;
}

.update-title:hover {
  color: var(--vp-c-brand-1);
}

.update-icon {
  font-size: 16px;
  filter: drop-shadow(0 0 8px rgba(0, 212, 170, 0.3));
}

.update-desc {
  font-size: 14px;
  color: var(--vp-c-text-2);
  line-height: 1.5;
}

.update-arrow {
  font-size: 20px;
  color: rgba(0, 212, 170, 0.3);
  transition: all 0.3s ease;
}

.update-item:hover .update-arrow {
  color: var(--vp-c-brand-1);
  transform: translateX(8px);
}
</style>