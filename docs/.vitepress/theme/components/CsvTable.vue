<script setup lang="ts">
import { ref, onMounted } from 'vue'

const props = defineProps<{
  src: string
  title?: string
}>()

const rows = ref<string[][]>([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  try {
    const base = (import.meta.env.BASE_URL || '/').replace(/\/$/, '')
    const res = await fetch(base + props.src)
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const buf = await res.arrayBuffer()
    const text = decodeText(buf)
    rows.value = parseCsv(text)
  } catch (e: any) {
    error.value = e?.message || String(e)
  } finally {
    loading.value = false
  }
})

function decodeText(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf)
  // UTF-8 BOM
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    return new TextDecoder('utf-8').decode(bytes.subarray(3))
  }
  // 优先严格 UTF-8，失败则回退 GBK（兼容中文 Excel 导出的 GBK CSV）
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes)
  } catch {
    try {
      return new TextDecoder('gbk').decode(bytes)
    } catch {
      return new TextDecoder('utf-8').decode(bytes)
    }
  }
}

function parseCsv(text: string): string[][] {
  const lines = text.trim().split(/\r?\n/)
  return lines.map(line => {
    const row: string[] = []
    let cur = ''
    let inQ = false
    for (let i = 0; i < line.length; i++) {
      const c = line[i]
      if (inQ) {
        if (c === '"') {
          if (line[i + 1] === '"') { cur += '"'; i++ } else inQ = false
        } else cur += c
      } else {
        if (c === '"') inQ = true
        else if (c === ',') { row.push(cur); cur = '' }
        else cur += c
      }
    }
    row.push(cur)
    return row
  })
}
</script>

<template>
  <div class="csv-table">
    <h3 v-if="title" class="csv-table-title">{{ title }}</h3>
    <p v-if="loading" class="csv-table-hint">加载中…</p>
    <p v-else-if="error" class="csv-table-error">加载失败：{{ error }}</p>
    <div v-else class="csv-table-wrap">
      <table class="csv-table-grid">
        <thead v-if="rows.length">
          <tr><th v-for="(h, i) in rows[0]" :key="i">{{ h }}</th></tr>
        </thead>
        <tbody>
          <tr v-for="(r, ri) in rows.slice(1)" :key="ri">
            <td v-for="(c, ci) in r" :key="ci">{{ c }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.csv-table { margin: 1rem 0; }
.csv-table-title { font-size: 1.1rem; margin: 1.2rem 0 0.6rem; }
.csv-table-hint, .csv-table-error { color: var(--vp-c-text-2); }
.csv-table-error { color: var(--vp-c-danger-1); }
.csv-table-wrap { overflow-x: auto; border: 1px solid var(--vp-c-divider); border-radius: 8px; }
.csv-table-grid { border-collapse: collapse; width: 100%; font-size: 0.85rem; }
.csv-table-grid th, .csv-table-grid td { border: 1px solid var(--vp-c-divider); padding: 6px 10px; text-align: left; white-space: nowrap; }
.csv-table-grid thead th { background: var(--vp-c-bg-soft); font-weight: 600; position: sticky; top: 0; }
.csv-table-grid tbody tr:nth-child(even) { background: var(--vp-c-bg-soft); }
</style>
