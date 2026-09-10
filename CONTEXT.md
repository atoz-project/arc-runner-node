# arc-runner-node

The shared CI runner image context for org repositories with a Node.js
toolchain. Vocabulary is shared with arc-runner-golang.

## Language

**Version line**:
One Node major (`24`), served by one floating image tag and one scale set.
_Avoid_: multi-version image

**Scale set**:
An ARC `AutoscalingRunnerSet`. Its name is the `runs-on` label, so the label
*is* the image choice.
_Avoid_: runner pool, fleet

**Tool-cache contract**:
The hostedtoolcache layout (`/opt/hostedtoolcache/node/<version>/x64/` plus
the sibling `x64.complete` marker) that makes `actions/setup-node` resolve
locally and skip downloading.

**Cache directory contract**:
Package-manager caches (`npm_config_cache`, pnpm/yarn defaults) live under
`/home/runner/.cache`, so one volume mount persists every cache across
ephemeral runner pods. Same path agreement as arc-runner-golang — a shared
volume can serve both images.

**ImageCache**:
An Alibaba ECI cluster-side image snapshot that removes the image-pull cost
from runner pod cold starts. Matches by exact `name:tag`; immutable tags only.
