import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    host: true,
    port: 5174,
    open: false,
    cors: true,
    // 修复 WebSocket 连接错误 - 完全禁用 HMR
    hmr: false,
    // 优化开发服务器性能
    watch: {
      ignored: ['**/node_modules/**', '**/dist/**', '**/docs/.vitepress/cache/**']
    },
    // 优化服务器响应
    fs: {
      strict: false
    }
  },
  optimizeDeps: {
    // 预构建依赖，减少初始加载时间
    include: ['vue', 'dayjs', 'medium-zoom', 'mermaid', '@braintree/sanitize-url', 'khroma', 'cytoscape', 'cytoscape-cose-bilkent', 'd3-scale', 'd3-selection', 'd3-transition', 'd3-format', 'd3-interpolate', 'd3-quadtree', 'lodash-es'],
    exclude: ['vitepress']
  },
  build: {
    // 优化生产构建
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
        // 更激进的压缩选项
        passes: 2,
        keep_fnames: false
      }
    },
    // 启用CSS代码分割
    cssCodeSplit: true,
    // 启用rollup的 treeshaking
    rollupOptions: {
      output: {
        manualChunks: {
          // 分割大型依赖
          vendor: ['vue'],
          mermaid: ['mermaid'],
          search: ['vitepress/dist/client/theme-default/composables/search'],
          // 分割图片和媒体资源
          media: ['**/*.png', '**/*.jpg', '**/*.svg']
        },
        // 启用长期缓存
        hashFunction: 'sha256',
        // 优化chunk大小
        maxAssetSize: 400000, // 400KB
        // 输出更详细的构建信息
        generatedCode: 'es2015'
      }
    },
    // 启用sourcemap（可选，用于调试）
    sourcemap: false,
    // 自定义输出目录
    outDir: 'docs/.vitepress/dist',
    // 清空输出目录
    emptyOutDir: true
  },
  // 配置CDN
  resolve: {
    alias: {
      // 可以在这里配置CDN别名
      '@': '/docs',
      '@assets': '/docs/.vitepress/dist/assets'
    }
  }
})
