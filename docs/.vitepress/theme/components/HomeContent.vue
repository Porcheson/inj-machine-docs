<template>
  <div class="home-content">
    <!-- 核心功能高亮区 -->
    <section class="feature-highlight">
      <div class="feature-highlight-inner">
        <div class="feature-highlight-left">
          <h2 class="feature-highlight-title">核心功能模块</h2>
          <p class="feature-highlight-desc">
            覆盖注塑机完整工作流程，从合模到射出，从储料到顶出，每个模块都经过精心设计和验证
          </p>
          <div class="feature-badges">
            <span class="feature-badge" v-for="(badge, i) in badges" :key="i">
              <span class="badge-dot"></span>
              {{ badge }}
            </span>
          </div>
          <a :href="withBase('/01_开合模功能整理')" class="view-all-link">
            查看全部功能
            <span class="view-all-arrow">→</span>
          </a>
        </div>
        <div class="feature-highlight-right">
          <div class="feature-grid">
            <a
              v-for="(item, i) in coreFeatures"
              :key="i"
              :href="withBase(item.link)"
              class="feature-item"
            >
              <div class="feature-item-icon">{{ item.icon }}</div>
              <div class="feature-item-name">{{ item.name }}</div>
              <div class="feature-item-cat">{{ item.cat }}</div>
            </a>
          </div>
        </div>
      </div>
    </section>

    <!-- 快速导航 -->
    <section class="nav-section">
      <div class="section-header">
        <h2 class="section-title">快速导航</h2>
        <p class="section-subtitle">一站式访问所有技术文档和资源</p>
      </div>
      <div class="nav-grid">
        <div class="nav-card" v-for="(card, i) in navCards" :key="i">
          <div class="nav-card-header">
            <div class="nav-card-icon-wrap">
              <span class="nav-card-icon">{{ card.icon }}</span>
            </div>
            <div class="nav-card-title-group">
              <span class="nav-card-title">{{ card.title }}</span>
              <span class="nav-card-desc">{{ card.desc }}</span>
            </div>
            <span class="nav-card-count">{{ card.items.length }}</span>
          </div>
          <div class="nav-card-body">
            <a
              v-for="(item, j) in card.items"
              :key="j"
              :href="withBase(item.link)"
              class="nav-link"
            >
              <span class="nav-link-text">{{ item.text }}</span>
              <span class="nav-link-arrow">→</span>
            </a>
          </div>
        </div>
      </div>
    </section>

    <!-- 最近更新 -->
    <section class="updates-section">
      <div class="section-header">
        <h2 class="section-title">最近更新</h2>
        <p class="section-subtitle">追踪项目最新进展和文档更新</p>
      </div>
      <RecentUpdates />
    </section>

    <!-- CTA 行动号召 -->
    <section class="cta-section">
      <div class="cta-content">
        <h2 class="cta-title">准备好开始了吗？</h2>
        <p class="cta-desc">立即浏览功能文档，深入了解宝捷信立式注塑机的技术细节</p>
        <div class="cta-actions">
          <a :href="withBase('/01_开合模功能整理')" class="cta-button-primary">
            开始阅读
            <span class="cta-button-arrow">→</span>
          </a>
          <a :href="withBase('/IM_SYS_PRG/CLAUDE')" class="cta-button-secondary">查看源码</a>
        </div>
      </div>
    </section>

    <!-- 关于 -->
    <section class="about-section">
      <div class="section-header">
        <h2 class="section-title">关于本项目</h2>
        <p class="section-subtitle">整理和文档化宝捷信立式注塑机的各项功能和技术细节</p>
      </div>
      <div class="about-grid">
        <div class="about-card">
          <div class="about-card-icon">📋</div>
          <h3 class="about-card-title">项目目标</h3>
          <p class="about-card-text">
            为技术人员提供全面、准确的参考资料，涵盖注塑机完整工作流程的功能说明、参数定义和接口规范。
          </p>
        </div>
        <div class="about-card">
          <div class="about-card-icon">🔧</div>
          <h3 class="about-card-title">技术栈</h3>
          <p class="about-card-text">
            基于 IEC 61131-3 标准开发，使用 Codesys 平台，模块化设计，标准接口，便于扩展和维护。
          </p>
        </div>
        <div class="about-card">
          <div class="about-card-icon">📞</div>
          <h3 class="about-card-title">联系方式</h3>
          <p class="about-card-text">
            技术交流：13971612060<br>
            Luban 下载：<a href="https://pan.baidu.com/s/134uu-YZ_6xK4FOy7PBDbXw?pwd=por1">百度网盘</a>
          </p>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import RecentUpdates from './RecentUpdates.vue'
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

const badges = ['模块化设计', '标准接口', '文档齐全', 'IEC 61131-3']

const coreFeatures = [
  { icon: '🔒', name: '开合模', cat: '合模系统', link: '/01_开合模功能整理' },
  { icon: '🔧', name: '调模', cat: '合模系统', link: '/02_调模功能整理' },
  { icon: '💨', name: '射出', cat: '射出系统', link: '/03_射出功能整理' },
  { icon: '⚡', name: '储料清料', cat: '射出系统', link: '/05_储料清料功能整理' },
  { icon: '⬆️', name: '托模', cat: '顶出系统', link: '/07_托模功能整理' },
  { icon: '🔹', name: '中子', cat: '顶出系统', link: '/10_中子功能整理' },
  { icon: '🌡️', name: '温度', cat: '控制系统', link: '/13_温度功能整理' },
  { icon: '🔄', name: '自动流程', cat: '控制系统', link: '/14_自动流程功能整理' }
]

const navCards = [
  {
    icon: '📖',
    title: '技术文档',
    desc: '地址点表、命名规范、流程图等参考资料',
    items: [
      { text: '地址点表', link: '/地址点表_Sheet1' },
      { text: '动作提示列表', link: '/动作提示列表' },
      { text: '命名规范', link: '/命名规范' },
      { text: '流程图', link: '/15_流程图' },
      { text: '源码文档', link: '/IM_SYS_PRG/CLAUDE' }
    ]
  },
  {
    icon: '📅',
    title: '会议记录',
    desc: '项目进展沟通会与技术方案讨论记录',
    items: [
      { text: '7月23日上机测试汇报', link: '/会议记录/20260723上机测试结果汇报与后续规划讨论会' },
      { text: '7月8日项目进展', link: '/会议记录/20260708项目进展沟通会' },
      { text: '6月17日项目进展', link: '/会议记录/20260617项目进展沟通会' },
      { text: '5月27日项目进展', link: '/会议记录/20260527项目进展沟通会' },
      { text: '4月13日开发计划', link: '/会议记录/20260413项目开发计划与接口验证方法讨论' },
      { text: '4月10日液压库方案', link: '/会议记录/20260410注塑机液压运动控制功能库开发技术方案讨论' },
      { text: '更多会议记录 →', link: '/会议记录/20260723上机测试结果汇报与后续规划讨论会' }
    ]
  }
]
</script>

<style scoped>
.home-content {
  position: relative;
  z-index: 1;
}

/* ============ 通用区块标题 ============ */
.section-header {
  text-align: center;
  margin-bottom: 32px;
}

.section-title {
  font-size: 32px;
  font-weight: 800;
  margin: 0 0 8px;
  background: linear-gradient(135deg, var(--vp-c-text-1) 0%, var(--vp-c-brand-1) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.section-subtitle {
  font-size: 15px;
  color: var(--vp-c-text-2);
  margin: 0;
}

/* ============ 核心功能高亮区 ============ */
.feature-highlight {
  padding: 24px 24px 32px;
  margin: 0;
  position: relative;
}

.feature-highlight-inner {
  max-width: 1400px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: 1fr 1.3fr;
  gap: 40px;
  align-items: center;
}

.feature-highlight-left {
  padding: 8px 0;
}

.feature-highlight-title {
  font-size: 36px;
  font-weight: 900;
  margin: 12px 0 16px;
  line-height: 1.1;
  background: linear-gradient(135deg, var(--vp-c-text-1) 0%, var(--vp-c-brand-1) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.feature-highlight-desc {
  font-size: 15px;
  color: var(--vp-c-text-2);
  line-height: 1.7;
  margin: 0 0 20px;
}

.feature-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.feature-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: var(--tag-bg);
  border: 1px solid var(--tag-border);
  border-radius: 24px;
  font-size: 13px;
  font-weight: 600;
  color: var(--vp-c-brand-1);
  transition: all 0.3s ease;
}

.feature-badge:hover {
  background: var(--vp-c-brand-soft);
  transform: translateY(-2px);
}

.badge-dot {
  width: 6px;
  height: 6px;
  background: var(--vp-c-brand-1);
  border-radius: 50%;
  box-shadow: 0 0 8px var(--vp-c-brand-1);
}

.view-all-link {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin-top: 24px;
  padding: 10px 22px;
  background: linear-gradient(135deg, var(--vp-c-brand-1) 0%, var(--vp-c-brand-2) 100%);
  color: #fff;
  font-size: 14px;
  font-weight: 700;
  border-radius: 12px;
  text-decoration: none;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  box-shadow: 0 6px 20px var(--vp-c-brand-soft);
}

.dark .view-all-link {
  color: #050810;
}

.view-all-link:hover {
  transform: translateY(-3px);
  box-shadow: 0 10px 28px var(--vp-c-brand-soft);
}

.view-all-arrow {
  transition: transform 0.3s ease;
}

.view-all-link:hover .view-all-arrow {
  transform: translateX(4px);
}

.feature-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}

.feature-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 18px 12px;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: 16px;
  text-decoration: none;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  position: relative;
  overflow: hidden;
  backdrop-filter: blur(10px);
}

.feature-item::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: var(--gradient-accent);
  transform: scaleX(0);
  transform-origin: center;
  transition: transform 0.4s ease;
}

.feature-item:hover {
  transform: translateY(-6px);
  border-color: var(--card-hover-border);
  box-shadow: var(--card-hover-shadow);
}

.feature-item:hover::before {
  transform: scaleX(1);
}

.feature-item-icon {
  font-size: 32px;
  margin-bottom: 10px;
  transition: transform 0.4s ease;
}

.feature-item:hover .feature-item-icon {
  transform: scale(1.2);
}

.feature-item-name {
  font-size: 14px;
  font-weight: 700;
  color: var(--vp-c-text-1);
  margin-bottom: 4px;
}

.feature-item-cat {
  font-size: 11px;
  color: var(--vp-c-text-2);
  opacity: 0.7;
}

/* ============ 快速导航 ============ */
.nav-section {
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px 24px 32px;
}

.nav-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 28px;
  max-width: 1000px;
  margin: 0 auto;
}

.nav-card {
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: 20px;
  overflow: hidden;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  backdrop-filter: blur(20px);
}

.nav-card:hover {
  transform: translateY(-6px);
  border-color: var(--card-hover-border);
  box-shadow: var(--card-hover-shadow);
}

.nav-card-header {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 24px;
  border-bottom: 1px solid var(--card-border);
}

.nav-card-icon-wrap {
  width: 48px;
  height: 48px;
  border-radius: 14px;
  background: var(--icon-bg);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.3s ease;
  flex-shrink: 0;
}

.nav-card:hover .nav-card-icon-wrap {
  transform: scale(1.1);
  background: var(--icon-bg-hover);
}

.nav-card-icon {
  font-size: 24px;
}

.nav-card-title-group {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-card-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--vp-c-text-1);
}

.nav-card-desc {
  font-size: 12px;
  color: var(--vp-c-text-2);
  opacity: 0.7;
}

.nav-card-count {
  font-size: 13px;
  font-weight: 700;
  color: var(--vp-c-brand-1);
  background: var(--tag-bg);
  padding: 4px 12px;
  border-radius: 16px;
  min-width: 32px;
  text-align: center;
}

.nav-card-body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4px;
  padding: 12px;
}

.nav-card-body .nav-link:nth-last-child(1):nth-child(odd) {
  grid-column: 1 / -1;
}

.nav-link {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
  border-radius: 10px;
  text-decoration: none;
  color: var(--vp-c-text-2);
  font-size: 14px;
  transition: all 0.3s ease;
  position: relative;
}

.nav-link-text {
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.nav-link-arrow {
  font-size: 14px;
  color: var(--vp-c-brand-1);
  opacity: 0;
  transform: translateX(-8px);
  transition: all 0.3s ease;
  margin-left: 8px;
}

.nav-link:hover {
  background: var(--tag-bg);
  color: var(--vp-c-brand-1);
  padding-left: 18px;
}

.nav-link:hover .nav-link-arrow {
  opacity: 1;
  transform: translateX(0);
}

/* ============ 最近更新 ============ */
.updates-section {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 24px 32px;
}

/* ============ CTA 行动号召 ============ */
.cta-section {
  margin: 16px 0 24px;
  padding: 48px 24px;
  position: relative;
  overflow: hidden;
  background:
    radial-gradient(ellipse at 20% 50%, var(--hero-glow-1) 0%, transparent 50%),
    radial-gradient(ellipse at 80% 50%, var(--hero-glow-3) 0%, transparent 50%);
  border-top: 1px solid var(--card-border);
  border-bottom: 1px solid var(--card-border);
}

.cta-content {
  text-align: center;
  max-width: 700px;
  margin: 0 auto;
  position: relative;
  z-index: 1;
}

.cta-title {
  font-size: 34px;
  font-weight: 900;
  margin: 0 0 12px;
  background: var(--gradient-primary);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.cta-desc {
  font-size: 16px;
  color: var(--vp-c-text-2);
  margin: 0 0 24px;
  line-height: 1.6;
}

.cta-actions {
  display: flex;
  gap: 16px;
  justify-content: center;
  flex-wrap: wrap;
}

.cta-button-primary,
.cta-button-secondary {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 14px 32px;
  font-size: 15px;
  font-weight: 700;
  border-radius: 14px;
  text-decoration: none;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.cta-button-primary {
  background: linear-gradient(135deg, var(--vp-c-brand-1) 0%, var(--vp-c-brand-2) 100%);
  color: #fff;
  box-shadow: 0 8px 24px var(--vp-c-brand-soft);
}

.dark .cta-button-primary {
  color: #050810;
}

.cta-button-primary:hover {
  transform: translateY(-3px);
  box-shadow: 0 12px 32px var(--vp-c-brand-soft);
}

.cta-button-arrow {
  transition: transform 0.3s ease;
}

.cta-button-primary:hover .cta-button-arrow {
  transform: translateX(4px);
}

.cta-button-secondary {
  background: var(--tag-bg);
  color: var(--vp-c-brand-1);
  border: 1.5px solid var(--tag-border);
}

.cta-button-secondary:hover {
  background: var(--vp-c-brand-soft);
  border-color: var(--vp-c-brand-1);
  transform: translateY(-3px);
}

/* ============ 关于 ============ */
.about-section {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 24px 48px;
}

.about-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
}

.about-card {
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: 20px;
  padding: 24px 20px;
  text-align: center;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  backdrop-filter: blur(20px);
  position: relative;
  overflow: hidden;
}

.about-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: var(--gradient-accent);
  transform: scaleX(0);
  transform-origin: center;
  transition: transform 0.4s ease;
}

.about-card:hover {
  transform: translateY(-8px);
  border-color: var(--card-hover-border);
  box-shadow: var(--card-hover-shadow);
}

.about-card:hover::before {
  transform: scaleX(1);
}

.about-card-icon {
  font-size: 40px;
  margin-bottom: 16px;
  filter: drop-shadow(0 0 12px var(--vp-c-brand-soft));
}

.about-card-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--vp-c-text-1);
  margin: 0 0 12px;
}

.about-card-text {
  font-size: 14px;
  color: var(--vp-c-text-2);
  line-height: 1.8;
  margin: 0;
}

.about-card-text a {
  color: var(--vp-c-brand-1);
  text-decoration: none;
  border-bottom: 1px solid transparent;
  transition: all 0.3s;
}

.about-card-text a:hover {
  border-bottom-color: var(--vp-c-brand-1);
}

/* ============ 响应式 ============ */
@media (max-width: 1024px) {
  .feature-highlight-inner {
    grid-template-columns: 1fr;
    gap: 40px;
  }

  .nav-grid {
    grid-template-columns: 1fr;
    max-width: 600px;
  }

  .about-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 768px) {
  .feature-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .nav-grid {
    grid-template-columns: 1fr;
  }

  .nav-card-body {
    grid-template-columns: 1fr;
  }

  .about-grid {
    grid-template-columns: 1fr;
    max-width: 400px;
    margin: 0 auto;
  }

  .section-title {
    font-size: 24px;
  }

  .feature-highlight-title {
    font-size: 28px;
  }

  .cta-title {
    font-size: 28px;
  }

  .cta-actions {
    flex-direction: column;
    align-items: stretch;
  }
}

@media (max-width: 480px) {
  .feature-grid {
    grid-template-columns: 1fr;
  }
}
</style>