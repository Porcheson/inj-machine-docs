# Runtime API Examples

This page demonstrates usage of some of the runtime APIs provided by VitePress.

## The `useData()` API

```ts
import { useData } from 'vitepress'

const { theme, page, frontmatter } = useData()
```

## Results

### Theme Data
<pre>{{ theme }}</pre>

### Page Data
<pre>{{ page }}</pre>

### Page Frontmatter
<pre>{{ frontmatter }}</pre>

## More

Check out the documentation for the [full list of runtime APIs](https://vitepress.dev/reference/runtime-api#usedata).
