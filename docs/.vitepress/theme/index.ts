import DefaultTheme from 'vitepress/theme'

// 样式
import './style/index.css' //自定义样式

import { h } from 'vue' // h函数
import { useData } from 'vitepress'
import { onMounted } from 'vue';


// 组件
import MNavLinks from './components/MNavLinks.vue' //导航
import HomeUnderline from "./components/HomeUnderline.vue" // 首页下划线
import update from "./components/update.vue" // 更新时间
import ArticleMetadata from "./components/ArticleMetadata.vue" //字数阅读时间
import Linkcard from "./components/Linkcard.vue" //链接卡片
import MyLayout from "./components/MyLayout.vue" //视图过渡

export default {
  extends: DefaultTheme,

  enhanceApp({app}: { app: any }) {
    // 注册全局组件
    app.component('MNavLinks' , MNavLinks) //导航
    app.component('HomeUnderline' , HomeUnderline) // 首页下划线
    app.component('update' , update) // 更新
    app.component('ArticleMetadata' , ArticleMetadata) //字数阅读时间
    app.component('Linkcard' , Linkcard) //链接卡片
  },

  //导航
  Layout: () => {
    const props: Record<string, any> = {}
    // 获取 frontmatter
    const { frontmatter } = useData()

    /* 添加自定义 class */
    if (frontmatter.value?.layoutClass) {
      props.class = frontmatter.value.layoutClass
    }

    return h(MyLayout,props)
  },
  
  // 延迟加载非关键功能
  setup() {
    
    // 图片懒加载
    const initLazyLoad = () => {
      const images = document.querySelectorAll('img');
      const imageObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target as HTMLImageElement;
            img.classList.remove('lazy');
            imageObserver.unobserve(img);
          }
        });
      });
      
      images.forEach(img => {
        if (!img.complete) {
          img.classList.add('lazy');
          imageObserver.observe(img);
        }
      });
    };
    
    // 延迟加载 medium-zoom
    const initZoom = () => {
      import('medium-zoom').then(({ default: mediumZoom }) => {
        mediumZoom('.main img', { background: 'var(--vp-c-bg)' });
      });
    };
    
    // 页面加载后延迟执行非关键功能
    onMounted(() => {
      // 先执行图片懒加载
      initLazyLoad();
      
      // 延迟执行 zoom 功能
      setTimeout(initZoom, 1000);
    });

  },

}
