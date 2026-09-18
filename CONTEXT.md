# arc-runner-node

面向组织内 Node.js 技术栈仓库的共享 CI runner 镜像上下文。词汇与
arc-runner-golang 共用。

## 术语

**版本线(version line)**:
单一 Node 主版本(`24`),由同一个浮动镜像 tag 和同一个 scale set 对外提供。
_避免_:多版本镜像

**Scale set**:
一个 ARC `AutoscalingRunnerSet`。它的名字就是 `runs-on` 标签,因此标签
*本身*就是镜像选择。
_避免_:runner pool、fleet

**Tool-cache 契约**:
hostedtoolcache 布局(`/opt/hostedtoolcache/node/<version>/x64/` 加上旁边的
`x64.complete` 标记文件),让 `actions/setup-node` 在本地解析、跳过下载。

**缓存目录契约**:
包管理器缓存(`npm_config_cache`、pnpm/yarn 默认目录)统一收敛在
`/home/runner/.cache`,这样一个卷挂载就能让所有缓存跨临时 runner pod
持久化。与 arc-runner-golang 的路径约定一致 —— 同一个共享卷可以同时服务
两种镜像。

**ImageCache**:
阿里云 ECI 集群侧的镜像快照,用来消除 runner pod 冷启动时的拉镜像开销。
按精确的 `name:tag` 匹配;只适用不可变 tag。
