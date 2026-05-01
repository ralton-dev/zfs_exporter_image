# zfs_exporter_image

Container packaging of [pdf/zfs_exporter](https://github.com/pdf/zfs_exporter) for the ralton-dev homelab cluster.

## What this is

Upstream `pdf/zfs_exporter` is a Prometheus exporter for ZFS (pools, filesystems, snapshots, volumes). It ships release binaries but no official container image. This repo builds a multi-arch container (linux/amd64 + linux/arm64) and publishes it to GHCR.

## Image

| | |
|---|---|
| Registry | `ghcr.io/ralton-dev/zfs_exporter` |
| Tags | `vX.Y.Z` (upstream version), `latest` (HEAD of `main`), `sha-<short>` |
| Base | `ubuntu:24.04` (matches NAS host's `zfsutils-linux 2.2.x`) |
| Entrypoint | `/usr/local/bin/zfs_exporter`, listens on `:9134` |

Always pin by digest in production manifests, not by tag.

## Why a separate image (vs. third-party / scratch)

The exporter binary is statically linked Go but **shells out** to `zpool` and `zfs` via `os/exec`. That means:

1. The container needs ZFS userspace utilities — can't use `scratch` or `distroless`.
2. The userspace utilities should match the host's kernel module version. Host is Ubuntu 24.04, so the container is too.
3. The container talks to the host kernel module via `/dev/zfs` (mounted at runtime by a `privileged: true` DaemonSet).

Existing third-party images (`derekgottlieb/zfs_exporter`, `quay.io/enix/zfs-exporter`) work but are single-vendor dependencies we can't rebuild. Same posture as everything else in the homelab — we own what we run.

## Bumping the upstream version

1. Update `ARG VERSION=` in [Dockerfile](Dockerfile).
2. Update the `type=raw,value=vX.Y.Z` line in [.github/workflows/build.yml](.github/workflows/build.yml).
3. Commit + push to `main`. GHA builds and tags the new version.
4. In the `homelab-k8s` repo, bump the digest pin in `manifests/zfs-exporter/daemonset.yaml`.

## License

MIT — see [LICENSE](LICENSE). Upstream `pdf/zfs_exporter` is also MIT.
