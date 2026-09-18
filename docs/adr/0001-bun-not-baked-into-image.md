---
status: accepted
---

# Bun 不烘进镜像

## Context

组织内部分前端项目使用 Bun 作为包管理器或运行时。Node 已按
hostedtoolcache 布局烘进镜像,自然的问题是:Bun 是否应享受同等待遇,
也烘进 `arc-runner-node`?

## Decision

不烘。使用 Bun 的消费方在自己的 workflow 里通过
[`oven-sh/setup-bun`](https://github.com/oven-sh/setup-bun) 自行安装。

理由:

- Bun 是单个静态二进制,`setup-bun` 安装只需几秒,烘进镜像省下的
  下载时间可以忽略。
- 本镜像的契约是单一版本线(见
  [ADR-0002](0002-single-node-24-version-line.md))。再烘入一个需要跟踪、
  钉版、校验 sha256 的工具,等于开了第二条版本线,直接违反该契约,
  维护面随之翻倍。
- Bun 不使用 Node 的 hostedtoolcache,既有的 tool-cache 契约对它没有
  任何加成 —— 烘进去也换不来消费方可感知的收益。

## Consequences

- Bun 项目的 workflow 多一个 setup 步骤,耗时以秒计;Bun 版本由各
  消费方自己钉,与本仓库解耦。
- 镜像内置 unzip（setup-bun 解压 Bun 发布 zip 的运行时依赖），消费方无需 workaround。
- 镜像维护面不变:本仓库不需要跟踪 Bun 的发布节奏。
- 重新评估的时机:Bun 项目成为本 scale set 的主要消费方,且
  `setup-bun` 被证明是瓶颈(下载耗时或稳定性)时。
