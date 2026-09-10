# Custom ARC (actions-runner-controller) runner image with the Node.js toolchain baked in.
# Sibling of arc-runner-golang; same contracts (toolcache layout, cache dirs, no DinD).
#
# Base: official GitHub Actions runner image, pinned to the latest stable release.
# Check for updates: https://github.com/actions/runner/releases
FROM ghcr.io/actions/actions-runner:2.337.0

# NODE_VERSION is a build argument; NODE_SHA256 must match it:
# https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt (node-v...-linux-x64.tar.gz row).
ARG NODE_VERSION=24.21.0
ARG NODE_SHA256=6e1db87ef58b8819e5d5402eff1536491b18edd8eb7bee5ef7897876e88dc5ff

USER root

# CI utilities. build-essential covers node-gyp native modules (gcc/g++/make/
# libc headers); python3 comes from the base image. zstd is the compression
# format cache backends prefer.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        jq \
        zstd \
    && rm -rf /var/lib/apt/lists/*

# NO DinD BY DESIGN: this image intentionally ships without a Docker daemon or
# any container runtime. (The base image does include the docker CLI binary,
# which the Actions runner needs for container actions; with no daemon and no
# socket it is inert.) Jobs that genuinely need Docker must run on
# GitHub-hosted runners instead.

# Pre-install Node into the GitHub "hostedtoolcache" layout:
#   ${RUNNER_TOOL_CACHE}/node/<version>/<arch>/            <- extracted distribution
#   ${RUNNER_TOOL_CACHE}/node/<version>/<arch>.complete    <- empty completion marker
# actions/setup-node (via @actions/tool-cache) only accepts a cached tool when BOTH
# the directory and the sibling "<arch>.complete" marker file exist. With this
# layout in place, setup-node (check-latest: false, the default) finds the image's
# Node locally and skips the download entirely.
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
ENV NODE_TOOLCACHE_DIR=${RUNNER_TOOL_CACHE}/node/${NODE_VERSION}/x64

RUN curl -fsSL -o /tmp/node.tgz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz" \
    && echo "${NODE_SHA256}  /tmp/node.tgz" | sha256sum -c - \
    && mkdir -p "${NODE_TOOLCACHE_DIR}" \
    && tar -xzf /tmp/node.tgz -C "${NODE_TOOLCACHE_DIR}" --strip-components=1 \
    && touch "${NODE_TOOLCACHE_DIR}.complete" \
    && rm /tmp/node.tgz \
    && chown -R runner:runner "${RUNNER_TOOL_CACHE}"

# Node on PATH regardless of whether a workflow uses actions/setup-node.
ENV PATH="${NODE_TOOLCACHE_DIR}/bin:${PATH}"

# Cache directory contract (parity with arc-runner-golang): package-manager
# caches live under /home/runner/.cache so the scale set can persist them
# across pods with ONE volume. npm respects npm_config_cache; pnpm/yarn via
# corepack default under ~/.cache as well.
ENV npm_config_cache=/home/runner/.cache/npm
# CI is non-interactive: let corepack fetch pnpm/yarn without prompting.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0

RUN mkdir -p /home/runner/.cache \
    && chown -R runner:runner /home/runner/.cache \
    && corepack enable

USER runner

# Smoke check at build time: fail the build if anything does not run from this image.
RUN node --version \
    && npm --version \
    && corepack --version
