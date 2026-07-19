# 项目规则

## 文档管理

- 所有文档必须放在 `docs/` 目录下，GitHub Pages 构建源为 `docs/`
- 会议记录统一放在 `docs/会议记录/` 目录，命名格式：`YYYYMMDD会议主题.md`
- 会议记录格式模板：基本信息 → 关键词 → 会议背景 → 核心要点 → 待办事项 → 综合总结

## 代码规范

- ST 代码相关规则参考 `CLAUDE.md` 和 `docs/IM_SYS_PRG/.claude/` 目录下的技能文档
- 文档命名使用中文，避免拼音或英文缩写

## Git 操作

- 远程仓库：`立式机` → `https://github.com/Porcheson/inj-machine-docs.git`
- 推送前必须执行 `git remote -v` 确认远程地址正确
- 推送前必须执行 `git fetch 立式机` 对比本地与远程提交历史，确保本地基于正确分支开发
- 禁止推送到其他远程仓库

## 部署

- GitHub Actions 自动构建部署，推送到 `main` 分支后触发
- 构建命令：`npm run docs:build`，输出目录：`docs/.vitepress/dist`
- 部署完成后访问：`https://porcheson.github.io/inj-machine-docs/`

## 目录结构

```
docs/
├── IM_SYS_PRG/          # ST 源代码和生成技能
├── ST定义/              # ST 定义文件
├── image/               # 文档图片资源
├── public/              # 公共资源
├── 会议记录/            # 会议记录
├── .vitepress/          # VitePress 配置
├── index.md             # 首页
└── *.md                 # 功能文档
```

## 注意事项

- 不要创建 `docs-site/` 或类似的重复目录
- 不要在根目录放置未使用的配置文件或脚本