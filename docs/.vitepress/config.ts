import { defineConfig } from 'vitepress'
import { generateSidebar } from 'vitepress-sidebar'
import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid({
  lang: 'zh-CN',
  title: "宝捷信立式注塑机",
  description: "宝捷信立式注塑机技术文档与功能整理",
  titleTemplate: ':title - 宝捷信立式注塑机',
  base: process.env.NETLIFY ? '/' : '/inj-machine-docs/',
  ignoreDeadLinks: true,
  head: [
    ['link', { rel: 'icon', href: '/favicon.svg' }],
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
        --vp-nav-height: 48px;
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
        top: var(--vp-nav-height);
        background-color: var(--vp-c-bg);
        border: 1px solid var(--vp-c-divider);
      }
      .VPNavBarMenuGroup .menu .item {
        color: var(--vp-c-text-1);
      }
      .VPNavBarMenuGroup .menu .item:hover {
        background-color: var(--vp-c-bg-alt);
        color: var(--vp-c-primary);
      }
      .VPNavBarAppearance {
        height: var(--vp-nav-height);
      }
      .VPSocialLinks {
        height: var(--vp-nav-height);
      }
    `],
    // 预加载关键资源
    ['link', { rel: 'preload', href: '/assets/app.js', as: 'script' }],
    ['link', { rel: 'preload', href: '/assets/style.css', as: 'style', onload: 'this.onload=null;this.rel="stylesheet"' }]
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
      {
        text: '功能文档',
        items: [
          { text: '开合模功能', link: '/01_开合模功能整理' },
          { text: '调模功能', link: '/02_调模功能整理' },
          { text: '射出功能', link: '/03_射出功能整理' },
          { text: '吹气功能', link: '/04_吹气功能整理' },
          { text: '储料清料功能', link: '/05_储料清料功能整理' },
          { text: '座台功能', link: '/06_座台功能整理' },
          { text: '托模功能', link: '/07_托模功能整理' },
          { text: '移模功能', link: '/08_移模功能整理' },
          { text: '转盘功能', link: '/09_转盘功能整理' },
          { text: '中子功能', link: '/10_中子功能整理' },
          { text: '绞牙功能', link: '/11_绞牙功能整理' },
          { text: '计时计数功能', link: '/12_计时计数功能整理' },
          { text: '温度功能', link: '/13_温度功能整理' },
          { text: '自动流程', link: '/14_自动流程功能整理' }
        ]
      },
      { text: '地址点表', link: '/地址点表_Sheet1' }
    ],

    sidebar: generateSidebar({
      documentRootPath: '/docs',
      collapsed: false,
      collapseDepth: 2,
    }),

    socialLinks: [
      { icon: 'github', link: 'https://github.com/Porcheson/inj-machine-docs' }
    ],
    footer: {
      message: '技术交流：13971612060',
      copyright: `© ${new Date().getFullYear()} 宝捷信立式注塑机技术文档`
    }
  },
  mermaid: {
    theme: 'base'
  }
})
