# LimpidSlirm's Blog

一个用 Hexo + Fluid 搭建的静态博客，记录自动化专业的学习笔记、硬件与嵌入式开发日志，以及一些随笔。

> A static blog built with Hexo and the Fluid theme. It collects study notes, hardware and embedded development logs, and occasional essays.

- 站点 / Site: <https://limpidslirm.github.io>
- 主题 / Theme: [hexo-theme-fluid](https://github.com/fluid-dev/hexo-theme-fluid)
- 生成器 / Generator: Hexo 8

## 环境要求 | Requirements

| 项目 / Item | 版本 / Version |
| --- | --- |
| Node.js | 18 或更高 / 18+ |
| Hexo | 8.x（随 `npm install` 安装 / installed with `npm install`） |

## 快速开始 | Quick start

```powershell
npm install          # 安装依赖 / install dependencies
npm run server       # 本地预览 http://localhost:4000 / local preview
npm run build        # 生成静态文件到 public/ / build into public/
npm run clean        # 清理缓存与 public/ / clean cache and public/
npm run deploy       # 构建并部署 / build and deploy
```

## 目录结构 | Project structure

```text
_config.yml          # 站点配置（URL、永久链接、deploy）/ site config
_config.fluid.yml    # Fluid 主题配置 / Fluid theme config
scaffolds/           # hexo new 的模板 / templates for hexo new
scripts/             # Hexo 脚本插件 / Hexo script plugins
source/
  _posts/            # 文章 / posts
  _data/             # 主题数据覆盖 / theme data overrides
  notes/             # 学习笔记 PDF/TeX / study note files
  img/ downloads/    # 静态资源 / static assets
  css/               # 自定义样式 / custom styles
  categories/        # 分类页 / category pages
themes/              # 主题 / themes
public/              # 构建输出（已忽略）/ build output (git-ignored)
```

## 写文章 | Writing posts

```powershell
npx hexo new post "文章标题"    # 生成 source/_posts/YYYYMMDD-文章标题.md
```

Front matter 示例 / example front matter:

```yaml
---
title: 文章标题
date: 2026-10-30 18:00:00
index_img: /img/1.png   # 可选：首页卡片封面 / optional card cover
index_img_position: right  # 可选：封面放到卡片右侧（默认左侧）/ optional, cover on the right of the card
tags:
  - Tag Name
---
```

## 站内约定 | Conventions

- 文章文件名使用 `YYYYMMDD-Title.md`，标题按日期排序 / posts are named `YYYYMMDD-Title.md`
- 标签统一使用英文 / tags are written in English
- `scripts/study-notes-archive.js` 会把 `Study Notes` 分类聚合到一个归档页 / aggregates the `Study Notes` category into one archive page
- `scripts/index-img-right.js` 配合 `source/css/custom.css` 实现 `index_img_position: right`（桌面端首页卡片头图靠右，移动端仍在标题上方）/ implements the right-side cover for desktop index cards
- `source/notes/*.tex` 通过 `skip_render` 原样输出 / `.tex` files bypass rendering
- 构建产物 `public/`、缓存 `db.json` 与 `node_modules/` 不入库 / build artifacts are git-ignored

## 部署 | Deployment

`_config.yml` 中的 `deploy` 段使用 `hexo-deployer-git`，产物推送到 GitHub Pages 仓库：

> The `deploy` section of `_config.yml` uses `hexo-deployer-git` and pushes the output to the GitHub Pages repository:

```powershell
npm run deploy       # 等价于 hexo generate && hexo deploy
```

```yaml
deploy:
  type: git
  repo: https://github.com/LimpidSlirm/limpidslirm.github.io
  branch: main
```

## 许可证 | License

除另有说明外，本仓库中的文字与图片版权归作者所有，未经许可请勿转载。

> Unless stated otherwise, all text and images in this repository are copyright of the author. Please do not repost without permission.
