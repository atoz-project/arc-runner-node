# arc-runner-node

Custom [ARC (actions-runner-controller)](https://github.com/actions/actions-runner-controller)
runner image with the Node.js toolchain baked in. Sibling of
[arc-runner-golang](https://github.com/atoz-project/arc-runner-golang); same
base image and the same contracts (tool-cache layout, cache directory, no DinD).

Image: `ghcr.io/atoz-project/arc-runner-node`

## Tags

| Tag | Moves? | Meaning |
|---|---|---|
| `:24` | yes, per patch release | floating major line — what scale sets should consume |
| `:<node>-<date><run>` (e.g. `:24.21.0-202609101`) | never | immutable build, for pinned rollouts and ECI ImageCache |

There is deliberately **no `:latest` tag**: consumers pin an explicit line (or
date tag) so "what is running" is never time-dependent.

Select the scale set per job — the label *is* the image choice:

```yaml
jobs:
  frontend:
    runs-on: arc-runner-set-node   # Node 24.x preinstalled
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "24"       # hits the baked-in toolcache, no download
      - run: npm ci && npm run build
```

With the hostedtoolcache layout baked in, `setup-node` resolves instantly;
plain `node`/`npm` also work with no setup step at all. `corepack` is enabled
with the download prompt off, so `pnpm`/`yarn` activate non-interactively.

## What's inside

| Component | Version / source | Notes |
|---|---|---|
| GitHub Actions Runner | `2.337.0` (pinned base image) | [releases](https://github.com/actions/runner/releases) |
| Node.js | `24.21.0` linux/x64 | sha256-verified download from nodejs.org |
| Tools | `build-essential`, `git`, `jq`, `zstd`, `curl`, `ca-certificates` | via apt; build-essential covers node-gyp native modules (python3 is in the base image) |

Versions are pinned `ARG`s at the top of the [Dockerfile](Dockerfile).

### Node pre-installed in the tool-cache layout

```
/opt/hostedtoolcache/node/<version>/x64/          # the Node distribution
/opt/hostedtoolcache/node/<version>/x64.complete  # empty completion marker
```

`actions/setup-node` (through `@actions/tool-cache`) only accepts a cached
tool when both the directory and the sibling `<arch>.complete` marker exist;
with this layout it skips the download entirely (`check-latest: false`, the
default). Node is also on `PATH` directly.

## Cache directory contract

Package-manager caches live under `/home/runner/.cache` (`npm_config_cache` is
set image-wide; pnpm/yarn default under `$HOME/.cache` as well), matching the
contract in arc-runner-golang: one persistent volume mounted at
`/home/runner/.cache` keeps every cache alive across ephemeral runner pods.
See the arc-runner-golang README for the scale-set volume snippet (`fsGroup:
1001`). ECI ImageCache applies to this image the same way — immutable date
tags only.

## No DinD by design

**No Docker daemon, no dind sidecar.** (The docker CLI binary is inherited
from the base image for container actions, but with no daemon and no socket it
is inert.) Jobs that genuinely need Docker — image builds, compose-based
integration tests, job-level `container:`/`services:` — should keep running on
GitHub-hosted runners.

## 部署 scale set(运维)

`deploy/` 是 scale set 配置的源事实(source of truth),结构与 arc-runner-golang 一致:

- `deploy/arc-runner-set-node.values.yaml` — 本镜像的 scale set;helm release 名
  `arc-runner-set-node` 就是消费方 workflow 里的 `runs-on` 标签。镜像固定消费浮动
  tag `:24`,并把 `/home/runner/.cache` 持久缓存卷挂上(引用事先创建的 RWX PVC
  `arc-node-cache`,`fsGroup: 1001` 保证 runner 用户可写)。
- `deploy/arc-runner-set.values.yaml` — 纯 Ubuntu 通用 scale set,镜像自
  arc-runner-golang 的同名文件(该 set 的线上捕获以 golang 仓库为准,改动需
  两边同步)。

安装 / 升级(chart 次版本必须与 controller 一致,当前 0.14.2;不要用本地过期副本
做 upgrade —— helm 会整体替换渲染后的 spec,漂移会被回滚):

```bash
helm upgrade arc-runner-set-node \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.14.2 -n arc-runners --kube-context k8s-sg-dev \
  -f deploy/arc-runner-set-node.values.yaml
```

注意:应用前必须先创建好 `arc-node-cache` PVC(见 values 文件注释),否则 runner
pod 无法调度。设计取舍(Bun 不烘进镜像、只承载 Node 24 单线)见
[docs/adr/](docs/adr/)。

## Building

Built and pushed by [.github/workflows/build.yml](.github/workflows/build.yml)
on push to `main`, on any tag, and on manual dispatch. Layers are cached with
`type=gha,mode=max`.

Issues and dependency requests belong to this repo.

## License

[MIT](LICENSE)
