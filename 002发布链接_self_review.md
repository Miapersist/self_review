# 002 发布链接 — self_review

## 三个版本

| 版本 | 位置 / 地址 | 是否发布 | 说明 |
|---|---|---|---|
| 本地版 | 本地 `site/index.html` | 不发布 | 开发调试用 |
| 个人版（带个人数据） | https://miapersist.github.io/self_review/output/index.html | 发布 | 自用，含个人数据 |
| 发布版（不带个人数据） | https://miapersist.github.io/self_review_public/index.html | 发布 | 对外分享，去个人数据 |

## 更新流程

1. 改本地 `site/index.html`。
2. 同步到 `self_review` 仓库 `output/` → 个人版更新。
3. 复制不含个人数据的版本到 `self_review_public` 仓库 → 发布版更新。

**发布版更新时机**：每次更新完本地版或个人版之后，再复制到 `self_review_public` 发布。

## 使用约定

- 对外只发发布版（`self_review_public`）；个人版含个人数据，仅自用。
- 页面调用的外部服务：Bark（`api.day.app`）、企业微信机器人（`qyapi.weixin.qq.com`）、ntfy、GitHub API；凭据不入库。
- 个人版更新后未同步到 `self_review_public` 时，对外仍为旧版。

## 最近一次发布

| 日期 | 内容 | 发布版提交 |
|---|---|---|
| 2026-10-29 | 情绪标记改为情绪测量仪（多选弹窗 + 释义区），保留月度复盘 | `b18feb9` |
