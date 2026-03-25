import { defineConfig } from 'vitepress'
import { generateSidebar } from 'vitepress-sidebar'
import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid({
  lang: 'zh-CN',
  title: "宝捷信立式注塑机",
  description: "宝捷信立式注塑机技术文档与功能整理",
  titleTemplate: ':title - 宝捷信立式注塑机',
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
        min-width: 400px;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
      }
      img {
        max-width: 100%;
        height: auto;
      }
    `],
    // 预加载关键资源
    ['link', { rel: 'preload', href: '/assets/app.js', as: 'script', defer: true }],
    ['link', { rel: 'preload', href: '/assets/style.css', as: 'style', onload: 'this.onload=null;this.rel="stylesheet"' }]
  ],
  appearance: 'toggle',
  sitemap: {
    hostname: 'http://localhost:5174'
  },
  cleanUrls: true,
  // 配置构建选项
  build: {
    minify: true,
    cssCodeSplit: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['vue'],
          mermaid: ['mermaid'],
          search: ['vitepress/dist/client/theme-default/composables/search']
        }
      }
    }
  },

  markdown: {
    lineNumbers: true,
  },
  lastUpdated: {
    text: '最后更新于',
    formatOptions: {
      dateStyle: 'full',
      timeStyle: 'medium'
    }
  },

  themeConfig: {
    logo: '/logo.png',
    siteTitle: '宝捷信立式注塑机',
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
      { text: '功能文档', link: '/01_开合模功能整理' },
      { text: '地址点表', link: '/地址点表_Sheet1' }
    ],

    sidebar: generateSidebar({
      documentRootPath: '/docs',
      collapsed: false,
      collapseDepth: 2,
    }),

    socialLinks: [
      { icon: 'github', link: 'https://github.com/wuhanheibao01/vertical-injection-machine-docs' }
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
