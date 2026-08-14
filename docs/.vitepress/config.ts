import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'
import path from 'node:path'
import fs from 'node:fs'
import fg from 'fast-glob'

// ===== 自动导航 / 侧栏生成：文档放入 docs 对应目录后重新构建即自动出现 =====
// 优先以 process.cwd() 定位 docs 目录（vitepress build docs 在项目根执行时可靠）
const DOCS_DIR = fs.existsSync(path.join(process.cwd(), 'docs'))
  ? path.join(process.cwd(), 'docs')
  : process.cwd()
const scanMd = (pattern: string) =>
  fg.sync(pattern, { cwd: DOCS_DIR, onlyFiles: true }).sort()

const cleanTitle = (rel: string) => {
  let name = rel.split(/[\\/]/).pop()!.replace(/\.md$/, '')
  name = name.replace(/^\d+_/, '')
  name = name.replace(/整理$/, '')
  name = name.replace(/^(\d{4})(\d{2})(\d{2})/, (_m: string, _y: string, mo: string, d: string) => `${parseInt(mo)}月${parseInt(d)}日`)
  return name.replace(/_/g, ' ')
}
const itemsOf = (pattern: string) =>
  scanMd(pattern).map((p) => ({
    text: cleanTitle(p),
    link: '/' + p.replace(/\\/g, '/').replace(/\.md$/, '')
  }))

const navFuncDocs = itemsOf('{0*,1[0-4]*}.md')
const navProcess = itemsOf('工艺模块/*.md')
const navTech = itemsOf('技术方案/*.md')
const navMeeting = itemsOf('会议记录/*.md')


export default withMermaid({
  lang: 'zh-CN',
  title: "宝捷信立式注塑机",
  description: "宝捷信立式注塑机技术文档与功能整理",
  titleTemplate: ':title - 宝捷信立式注塑机',
  base: process.env.NETLIFY ? '/' : '/inj-machine-docs/',
  ignoreDeadLinks: true,
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
    ['link', { rel: 'icon', type: 'image/png', href: '/logo.png', sizes: '192x192' }],
    // 内联关键CSS，实现首屏优先显示
    ['style', {}, `
      :root {
        --vp-font-family-base: 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', Arial, sans-serif;
        --vp-font-size-md: 16px;
        --vp-home-hero-padding-top: 80px;
        --vp-home-hero-padding-bottom: 48px;
        --vp-home-features-padding: 64px 0;
        --vp-layout-content-width: 1600px;
      }
      body {
        margin: 0;
        padding: 0;
        font-family: var(--vp-font-family-base);
        font-size: var(--vp-font-size-md);
        line-height: 1.6;
      }
      .VPHomeHero {
        padding-top: var(--vp-home-hero-padding-top);
        padding-bottom: var(--vp-home-hero-padding-bottom);
        text-align: center;
      }
      .VPHomeHero h1 {
        font-size: 56px;
        font-weight: 800;
        margin-bottom: 16px;
        line-height: 1.1;
        text-align: center;
        letter-spacing: -0.02em;
      }
      .VPHomeHero .tagline {
        font-size: 16px;
        margin-bottom: 32px;
        max-width: 600px;
        margin-left: auto;
        margin-right: auto;
        font-weight: 400;
        text-align: center;
        line-height: 1.5;
        opacity: 0.8;
      }
      .VPHomeFeatures {
        padding: var(--vp-home-features-padding);
      }
      .VPHomeFeatures .items {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 32px;
        max-width: 1600px;
        margin: 0 auto;
      }
      .VPHomeFeatures .item {
        border-radius: 12px;
        padding: 20px;
        min-height: 140px;
        min-width: 300px;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
      }
      /* 响应式布局 */
      @media (max-width: 768px) {
        .VPHomeFeatures .items {
          grid-template-columns: 1fr;
          gap: 20px;
        }
        .VPHomeFeatures .item {
          min-width: auto;
        }
        .VPHomeHero h1 {
          font-size: 32px;
        }
      }
      @media (min-width: 769px) and (max-width: 1024px) {
        .VPHomeFeatures .items {
          grid-template-columns: repeat(2, 1fr);
        }
      }
      img {
        max-width: 100%;
        height: auto;
      }
      /* 导航栏样式优化 */
      .VPNav {
        --vp-nav-height: 42px;
      }
      .VPNavBar {
        height: var(--vp-nav-height);
      }
      .VPNavBarMenu {
        height: var(--vp-nav-height);
      }
      .VPNavBarMenuLink {
        height: var(--vp-nav-height);
        line-height: var(--vp-nav-height);
        padding: 0 12px;
      }
      .VPNavBarMenuGroup {
        height: var(--vp-nav-height);
      }
      .VPNavBarMenuGroup .button {
        height: var(--vp-nav-height);
        line-height: var(--vp-nav-height);
        padding: 0 12px;
      }
      .VPNavBarMenuGroup .menu {
        top: calc(var(--vp-nav-height) + 6px);
        background-color: var(--vp-c-bg);
        border: 1px solid var(--vp-c-divider);
        border-radius: 12px;
        box-shadow: 0 12px 32px rgba(0, 0, 0, 0.12);
        padding: 6px;
        animation: vp-nav-menu-in 0.18s ease-out;
      }
      @keyframes vp-nav-menu-in {
        from { opacity: 0; transform: translateY(-6px); }
        to { opacity: 1; transform: translateY(0); }
      }
      .VPNavBarMenuGroup .menu .VPMenu {
        padding: 4px;
      }
      .VPNavBarMenuGroup .menu .VPMenu .items {
        display: flex;
        flex-direction: column;
        gap: 2px;
      }
      .VPNavBarMenuGroup .menu .VPMenuLink a {
        display: block;
        color: var(--vp-c-text-1);
        border-radius: 8px;
        padding: 7px 12px;
        font-size: 14px;
        line-height: 1.5;
        white-space: nowrap;
        transition: background-color 0.15s ease, color 0.15s ease;
      }
      .VPNavBarMenuGroup .menu .VPMenuLink a:hover {
        background-color: var(--vp-c-bg-alt);
        color: var(--vp-c-primary);
      }
      .VPNavBarMenuLink,
      .VPNavBarMenuGroup .button {
        transition: color 0.15s ease, opacity 0.15s ease;
      }
      .VPNavBarMenuLink:hover,
      .VPNavBarMenuGroup .button:hover {
        opacity: 1;
        color: var(--vp-c-primary);
      }
      /* 导航项 hover 下划线动效 */
      .VPNavBarMenuLink,
      .VPNavBarMenuGroup .button {
        position: relative;
      }
      .VPNavBarMenuLink::after,
      .VPNavBarMenuGroup .button::after {
        content: "";
        position: absolute;
        left: 12px;
        right: 12px;
        bottom: 0;
        height: 2px;
        border-radius: 2px;
        background: var(--vp-c-primary);
        transform: scaleX(0);
        transform-origin: center;
        transition: transform 0.2s ease;
      }
      .VPNavBarMenuLink:hover::after,
      .VPNavBarMenuGroup .button:hover::after,
      .VPNavBarMenuLink.active::after {
        transform: scaleX(1);
      }
      /* 下拉箭头展开旋转 */
      .VPNavBarMenuGroup .button .text-icon {
        transition: transform 0.2s ease;
      }
      .VPNavBarMenuGroup:hover .button .text-icon {
        transform: rotate(180deg);
      }
      .VPNavBarAppearance {
        height: var(--vp-nav-height);
      }
      .VPSocialLinks {
        height: var(--vp-nav-height);
      }
    `],
    
  ],
  sitemap: {
    hostname: 'http://localhost:5174'
  },
  cleanUrls: true,

  markdown: {
    lineNumbers: true,
  },
  lastUpdated: true,

  themeConfig: {
    logo: '/logo.png',
    siteTitle: '宝捷信立式注塑机',
    editLink: {
      pattern: 'https://github.com/Porcheson/inj-machine-docs/edit/main/:path',
      text: '在 GitHub 上编辑此页面'
    },
    outline: {
      level: [2, 4],
      label: '当前页大纲'
    },
    lastUpdated: {
      text: '最后更新'
    },
    search: {
      provider: 'local',
      options: {
        translations: {
          button: {
            buttonText: '搜索文档',
            buttonAriaLabel: '搜索文档'
          },
          modal: {
            noResultsText: '无法找到相关结果',
            resetButtonTitle: '清除查询条件',
            footer: {
              selectText: '选择',
              navigateText: '切换',
              closeText: '关闭'
            }
          }
        }
      }
    },
    nav: [
      { text: '首页', link: '/' },
      { text: '功能文档', items: navFuncDocs },
      { text: '工艺模块', items: navProcess },
      { text: '技术方案', items: navTech },
      { text: '会议记录', items: navMeeting },
      { text: '点表', link: '/点表/' }
    ],
    sidebar: {
      '/': [
        { text: '首页', link: '/', icon: 'home' },
        { text: '功能文档', icon: 'book', items: navFuncDocs },
        { text: '工艺模块', items: navProcess },
        { text: '技术方案', icon: 'file-code', items: navTech },
        { text: '会议记录', icon: 'calendar', items: navMeeting },
        {
          text: '技术文档',
          icon: 'file-code',
          items: [
            { text: '点表', link: '/点表/' },
            { text: '动作提示列表', link: '/动作提示列表' },
            { text: '命名规范', link: '/命名规范' },
            { text: '流程图', link: '/15_流程图' },
            { text: 'IM_SYS_PRG源码', link: '/IM_SYS_PRG/CLAUDE' },
          ]
        },
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/Porcheson/inj-machine-docs' }
    ],
    footer: {
      message: '技术交流：13971612060',
      copyright: `© ${new Date().getFullYear()} 宝捷信立式注塑机技术文档 | 更新时间: ${new Date().toLocaleString('zh-CN')}`
    }
  },
  mermaid: {
    theme: 'base'
  }
})
