import { defineConfig } from 'vitepress'

import { devDependencies } from '../../package.json'
import markdownItTaskCheckbox from 'markdown-it-task-checkbox'
import { groupIconMdPlugin, groupIconVitePlugin, localIconLoader } from 'vitepress-plugin-group-icons'
import { MermaidMarkdown, MermaidPlugin } from 'vitepress-plugin-mermaid';

import { usePosts } from './theme/untils/permalink';

export default defineConfig(async () => {
  const { rewrites } = await usePosts();

  return {
    lang: 'zh-CN',
    title: "VitePress",
    description: "我的vitpress文档教程",
    rewrites,

    // #region fav
    head: [
      ['link', { rel: 'icon', href: '/logo.png' }],
    ],
    // #endregion fav

    base: '/vertical-injection-machine-docs/', //网站部署到github的vertical-injection-machine-docs这个仓库里

    // cleanUrls:true, //开启纯净链接无html

    //启用深色模式
    appearance: 'dark',

    //多语言
    locales: {
      root: {
        label: '简体中文',
        lang: 'Zh_CN',
      },
      en: {
        label: 'English',
        lang: 'en',
        link: '/en/',
      },
      fr: {
        label: 'French',
        lang: 'fr',
        link: '/fr/',
      }
    },

    //markdown配置
    markdown: {
      //行号
      lineNumbers: true,
      //锚点
      anchor: {
        permalink: true,
        permalinkBefore: true,
        permalinkSymbol: '#',
      },
      //目录
      toc: {
        includeLevel: [1, 2, 3, 4],
      },

      //配置markdown-it插件
      config: (md) => {
        md.use(markdownItTaskCheckbox, {
          disabled: true,
          divWrap: true,
          divClass: 'task-list-item',
          idPrefix: 'task-item-',
        });
        md.use(MermaidMarkdown);
        md.use(groupIconMdPlugin);
      },
    },

    //主题配置
    themeConfig: {
      //站点logo
      logo: '/logo.png',

      //站点名称
      siteTitle: 'VitePress',

      //导航栏
      nav: [
        {
          text: '首页',
          link: '/',
          activeMatch: '^/$',
        },
        {
          text: '指南',
          items: [
            {
              text: '快速开始',
              link: '/guide/quick-start',
            },
            {
              text: '部署',
              link: '/guide/deploy',
            },
          ],
        },
        {
          text: '组件',
          link: '/components/',
        },
        {
          text: '配置',
          link: '/config/',
        },
        {
          text: '关于',
          link: '/about/',
        },
      ],

      //侧边栏
      sidebar: {
        //自动生成侧边栏
        // '/guide/': 'auto',

        //自定义侧边栏
        '/guide/': [
          {
            text: '指南',
            items: [
              {
                text: '快速开始',
                link: '/guide/quick-start',
              },
              {
                text: '部署',
                link: '/guide/deploy',
              },
            ],
          },
        ],

        '/components/': [
          {
            text: '组件',
            items: [
              {
                text: '组件1',
                link: '/components/component1',
              },
              {
                text: '组件2',
                link: '/components/component2',
              },
            ],
          },
        ],

        '/config/': [
          {
            text: '配置',
            items: [
              {
                text: '配置1',
                link: '/config/config1',
              },
              {
                text: '配置2',
                link: '/config/config2',
              },
            ],
          },
        ],
      },

      //编辑链接
      editLink: {
        pattern: 'https://github.com/wuhanheibao01/vertical-injection-machine-docs/edit/main/docs/:path', // 改成自己的仓库
        text: '在GitHub编辑本页',
      },

      //最后更新时间
      lastUpdated: {
        text: '最后更新时间',
        formatOptions: {
          dateStyle: 'full',
          timeStyle: 'medium',
        },
      },

      //Algolia搜索
      search: {
        provider: 'algolia',
        options: {
          appId: 'QVKQI62L15',
          apiKey: 'bef8783dde57293ce082c531aa7c7e0c',
          indexName: 'doc',
          locales: {
            root: {
              placeholder: '搜索文档',
              translations: {
                button: {
                  buttonText: '搜索文档',
                  buttonAriaLabel: '搜索文档',
                },
                modal: {
                  searchBox: {
                    resetButtonTitle: '清除查询条件',
                    resetButtonAriaLabel: '清除查询条件',
                    cancelButtonText: '取消',
                    cancelButtonAriaLabel: '取消',
                  },
                  startScreen: {
                    recentSearchesTitle: '搜索历史',
                    noRecentSearchesText: '没有搜索历史',
                    saveRecentSearchButtonTitle: '保存至搜索历史',
                    removeRecentSearchButtonTitle: '从搜索历史中移除',
                    favoriteSearchesTitle: '收藏',
                    removeFavoriteSearchButtonTitle: '从收藏中移除',
                  },
                  errorScreen: {
                    titleText: '无法获取结果',
                    helpText: '你可能需要检查你的网络连接',
                  },
                  footer: {
                    selectText: '选择',
                    navigateText: '切换',
                    closeText: '关闭',
                    searchByText: '搜索提供者',
                  },
                  noResultsScreen: {
                    noResultsText: '无法找到相关结果',
                    suggestedQueryText: '你可以尝试查询',
                    reportMissingResultsText: '你认为该查询应该有结果？',
                    reportMissingResultsLinkText: '点击反馈',
                  },
                },
              },
            },
          },
        },
      },

      //社交链接
      socialLinks: [
        { icon: 'github', link: 'https://github.com/wuhanheibao01/vertical-injection-machine-docs' },
        { icon: 'twitter', link: 'https://twitter.com/' },
        { icon: 'discord', link: 'https://chat.vitejs.dev/' },
        {
          icon: {
            svg: '<svg t="1703483542872" class="icon" viewBox="0 0 1309 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="6274" width="200" height="200"><path d="M1147.26896 912.681417l34.90165 111.318583-127.165111-66.823891a604.787313 604.787313 0 0 1-139.082747 22.263717c-220.607239 0-394.296969-144.615936-394.296969-322.758409s173.526026-322.889372 394.296969-322.889372C1124.219465 333.661082 1309.630388 478.669907 1309.630388 656.550454c0 100.284947-69.344929 189.143369-162.361428 256.130963zM788.070086 511.869037a49.11114 49.11114 0 0 0-46.360916 44.494692 48.783732 48.783732 0 0 0 46.360916 44.494693 52.090549 52.090549 0 0 0 57.983885-44.494693 52.385216 52.385216 0 0 0-57.983885-44.494692z m254.985036 0a48.881954 48.881954 0 0 0-46.09899 44.494692 48.620028 48.620028 0 0 0 46.09899 44.494693 52.385216 52.385216 0 0 0 57.983886-44.494693 52.58166 52.58166 0 0 0-57.951145-44.494692z m-550.568615 150.018161a318.567592 318.567592 0 0 0 14.307712 93.212943c-14.307712 1.080445-28.746387 1.768001-43.283284 1.768001a827.293516 827.293516 0 0 1-162.394168-22.296458l-162.001279 77.955749 46.328175-133.811485C69.410411 600.858422 0 500.507993 0 378.38496 0 166.683208 208.689602 0 463.510935 0c227.908428 0 427.594322 133.18941 467.701752 312.379588a427.463358 427.463358 0 0 0-44.625655-2.619261c-220.24709 0-394.100524 157.74498-394.100525 352.126871zM312.90344 189.143369a64.270111 64.270111 0 0 0-69.803299 55.659291 64.532037 64.532037 0 0 0 69.803299 55.659292 53.694846 53.694846 0 0 0 57.852923-55.659292 53.465661 53.465661 0 0 0-57.852923-55.659291z m324.428188 0a64.040926 64.040926 0 0 0-69.574114 55.659291 64.302852 64.302852 0 0 0 69.574114 55.659292 53.694846 53.694846 0 0 0 57.951145-55.659292 53.465661 53.465661 0 0 0-57.951145-55.659291z" p-id="6275"></path></svg>',
          },
          link: 'https://weixin.qq.com/',
          // You can include a custom label for accessibility too (optional but recommended):
          ariaLabel: 'wechat',
        },
      ],

      //手机端深浅模式文字修改
      darkModeSwitchLabel: '深浅模式',

      //页脚
      footer: {
        message: 'Released under the MIT License.',
        copyright: `Copyright © 2023-${new Date().getFullYear()} 备案号：<a href="https://beian.miit.gov.cn/" target="_blank">京****号</a>`,
      },

      //侧边栏文字更改(移动端)
      sidebarMenuLabel: '目录',

      //返回顶部文字修改(移动端)
      returnToTopLabel: '返回顶部',

      //大纲显示2-3级标题
      outline: {
        level: [2, 3],
        label: '当前页大纲',
      },

      //自定义上下页名
      docFooter: {
        prev: '上一页',
        next: '下一页',
      },
    },
  };
});
