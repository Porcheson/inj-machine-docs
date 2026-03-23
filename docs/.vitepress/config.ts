import { defineConfig } from 'vitepress'
import { generateSidebar } from 'vitepress-sidebar'
import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid(
  defineConfig({
    lang: 'zh-CN',
    title: "宝捷信立式注塑机",
    description: "宝捷信立式注塑机技术文档与功能整理",
    titleTemplate: ':title - 宝捷信立式注塑机',
    head: [
      ['link', { rel: 'icon', href: '/favicon.ico' }]
    ],
    appearance: true,
    sitemap: {
      hostname: 'http://localhost:5174'
    },
    cleanUrls: true,

    markdown: {
      lineNumbers: true,
    },

    themeConfig: {
      logo: '/logo.png',
      siteTitle: '宝捷信立式注塑机',
      outline: {
        level: [2, 4]
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
        message: '基于 VitePress 构建',
        copyright: `© ${new Date().getFullYear()} 宝捷信立式注塑机技术文档`
      }
    }
  })
)
