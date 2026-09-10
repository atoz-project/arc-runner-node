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
| `:latest` | yes | currently the 24 line |

## Using it in a workflow

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

## Building

Built and pushed by [.github/workflows/build.yml](.github/workflows/build.yml)
on push to `main`, on any tag, and on manual dispatch. Layers are cached with
`type=gha,mode=max`.

Issues and dependency requests belong to this repo.

## License

[MIT](LICENSE)
