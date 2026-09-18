---
status: accepted
---

# 镜像只承载 Node 24 单一版本线

## Context

组织内仍有部分消费方仓库把 Node 钉在 22(`.nvmrc`、workflow 里的
`node-version`)。兄弟镜像 arc-runner-golang 同时烘入两条 Go 版本线
(1.25 + 1.26),问题自然出现:本镜像要不要同时烘 Node 22 和 24?

## Decision

只烘 Node 24(当前 active LTS)一条线。仍钉 22 的消费方在自身完成
升级后再迁移到本 scale set;在此之前,`setup-node` 请求 22 会在 job
运行时正常下载 —— 更慢,但不是错误,也可以继续跑在 GitHub-hosted
runner 上。

为什么与 golang 镜像不同:golang 烘两条线,是因为组织内 Go 仓库在
迁移窗口内同时活跃在 1.25/1.26 两条线上,双版本线能消除迁移期的
下载开销。Node 消费方没有这种双活跃窗口 —— 钉 22 的仓库只是还没
升级,而不是需要长期并存。本镜像的版本线策略因此是:跟随唯一的
active LTS,镜像保持单一版本、单一浮动 tag(`:24`)。

## Consequences

- 仍钉 22 的仓库在本 set 上能跑(`setup-node` 运行时下载),只是每次
  job 多花下载时间;升级自身的 Node 版本是它们迁移的前提。
- 镜像保持单版本线契约:tag 方案(浮动 `:24` + 不可变
  `:<node 版本>-<日期><run>`)无需为多线扩展。
- 重新评估的时机:Node 26 成为 active LTS(届时考虑平移或短暂双线
  过渡),或出现硬性消费方需求(某仓库无法升级且运行时下载不可接受)。
