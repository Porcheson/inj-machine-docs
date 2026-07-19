<template>
  <div class="recent-updates">
    <div class="update-item" v-for="(item, index) in updates" :key="index">
      <div class="update-date">{{ item.date }}</div>
      <div class="update-info">
        <a :href="base + item.link" class="update-title">{{ item.title }}</a>
        <div class="update-desc">{{ item.desc }}</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useData } from 'vitepress'

const { site } = useData()
const base = site.value.base || ''

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
    link: '/IM_SYS_PRG/Code/伺服系统/液压轴/FB_HydAxis',
    title: 'FB_HydAxis液压轴功能块',
    desc: '更新液压控制库文档，增加MaxSpeed变量'
  }
]
</script>

<style scoped>
.recent-updates {
  max-width: 1200px;
  margin: 40px auto;
}

.update-item {
  display: flex;
  gap: 20px;
  padding: 16px 20px;
  background: var(--vp-c-bg-1);
  border-radius: 8px;
  margin-bottom: 12px;
  transition: all var(--vp-transition-normal);
  border: 1px solid transparent;
}

.update-item:hover {
  background: var(--vp-c-bg-soft);
  border-color: var(--vp-c-divider);
  transform: translateX(4px);
}

.update-date {
  font-size: 14px;
  color: var(--vp-c-text-3);
  font-weight: 500;
  min-width: 100px;
  flex-shrink: 0;
}

.update-info {
  flex: 1;
}

.update-title {
  font-size: 16px;
  color: var(--vp-c-text-1);
  font-weight: 500;
  text-decoration: none;
  display: block;
  margin-bottom: 4px;
}

.update-title:hover {
  color: var(--vp-c-brand);
}

.update-desc {
  font-size: 14px;
  color: var(--vp-c-text-2);
}
</style>