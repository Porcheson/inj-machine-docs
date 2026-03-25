import DefaultTheme from 'vitepress/theme'

// 样式
import './style/index.css' //自定义样式

import { h } from 'vue' // h函数
import { useData , useRoute } from 'vitepress'
// mediumZoom
import mediumZoom from 'medium-zoom';
import { onMounted, watch, nextTick } from 'vue';


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
  
  // medium-zoom
  setup() {
    const route = useRoute();
    const initZoom = () => {
      mediumZoom('.main img', { background: 'var(--vp-c-bg)' }); // 不显式添加{data-zoomable}的情况下为所有图像启用此功能
    };
    onMounted(() => {
      initZoom();
    });
    watch(
      () => route.path,
      () => nextTick(() => initZoom())
    );

  },

}
