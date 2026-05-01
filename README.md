# zfs_exporter_image

Container packaging of [pdf/zfs_exporter](https://github.com/pdf/zfs_exporter) for the ralton-dev homelab cluster.

## What this is

Upstream `pdf/zfs_exporter` is a Prometheus exporter for ZFS (pools, filesystems, snapshots, volumes). It ships release binaries but no official container image. This repo builds a multi-arch container (linux/amd64 + linux/arm64) and publishes it to GHCR.

## Image

| | |
|---|---|
| Registry | `ghcr.io/ralton-dev/zfs_exporter` |
| Tags | `vX.Y.Z[-N]` (the git tag pushed to trigger the build) |
| Base | `ubuntu:24.04` (matches NAS host's `zfsutils-linux 2.2.x`) |
| Entrypoint | `/usr/local/bin/zfs_exporter`, listens on `:9134` |

Always pin by digest in production manifests, not by tag.

## Why a separate image (vs. third-party / scratch)

The exporter binary is statically linked Go but **shells out** to `zpool` and `zfs` via `os/exec`. That means:

1. The container needs ZFS userspace utilities — can't use `scratch` or `distroless`.
2. The userspace utilities should match the host's kernel module version. Host is Ubuntu 24.04, so the container is too.
3. The container talks to the host kernel module via `/dev/zfs` (mounted at runtime by a `privileged: true` DaemonSet).

Existing third-party images (`derekgottlieb/zfs_exporter`, `quay.io/enix/zfs-exporter`) work but are single-vendor dependencies we can't rebuild. Same posture as everything else in the homelab — we own what we run.

## Releases

Builds are triggered only by **pushing a `v*` git tag** (or `workflow_dispatch`). Pushes to `main` don't build — they're a no-op for CI. PRs against `main` do a build-only smoke test (no push) so Dockerfile changes are validated before merge.

### Tag scheme

```
v<UPSTREAM>[-<BUILD>]
```

`UPSTREAM` is the pdf/zfs_exporter release we're packaging. `BUILD` increments when we re-release the same upstream version (e.g., a Dockerfile fix). Examples: `v2.3.12`, `v2.3.12-2`, `v2.3.13-1`.

### Bumping the upstream version

```bash
# 1. Update Dockerfile
$EDITOR Dockerfile  # change ARG VERSION=2.3.12 to 2.3.13
git commit -am "chore: bump upstream zfs_exporter to 2.3.13"
git push origin main

# 2. Tag and push to trigger the build
git tag v2.3.13-1
git push origin v2.3.13-1

# 3. Wait for GHA, then update the digest pin in homelab-k8s
#    manifests/zfs-exporter/daemonset.yaml.
```

## License

MIT — see [LICENSE](LICENSE). Upstream `pdf/zfs_exporter` is also MIT.
