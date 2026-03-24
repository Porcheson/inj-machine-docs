import { defineConfig } from 'vitepress'
import { generateSidebar } from 'vitepress-sidebar'
import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid({
  lang: 'zh-CN',
  title: "宝捷信立式注塑机",
  description: "宝捷信立式注塑机技术文档与功能整理",
  titleTemplate: ':title - 宝捷信立式注塑机',
  head: [
    ['link', { rel: 'icon', href: '/favicon.svg' }]
  ],
  appearance: 'dark',
  sitemap: {
    hostname: 'http://localhost:5174'
  },
  cleanUrls: true,

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
