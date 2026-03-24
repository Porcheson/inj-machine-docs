// 声明.vue文件的类型
declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}

// 声明busuanzi.pure.js模块
declare module 'busuanzi.pure.js' {
  const busuanzi: any
  export default busuanzi
}
