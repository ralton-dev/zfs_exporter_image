# syntax=docker/dockerfile:1.7
#
# Container build for upstream pdf/zfs_exporter.
#
# Two-stage build:
#   - Stage 1 (download) runs on the BUILDPLATFORM (no QEMU emulation),
#     pulls the per-TARGETARCH release binary from GitHub, extracts it.
#   - Stage 2 (runtime) is per-target-arch ubuntu:24.04 with zfsutils-linux,
#     so the container's `zpool`/`zfs` userspace versions match what
#     ships on the Ubuntu 24.04 NAS host. The exporter shells out to
#     these binaries via os/exec, then talks to the host kernel module
#     via /dev/zfs (mounted by the DaemonSet at runtime, privileged).

ARG ZFS_EXPORTER_VERSION=2.3.12

FROM --platform=$BUILDPLATFORM alpine:3.20 AS download
ARG ZFS_EXPORTER_VERSION
ARG TARGETARCH
WORKDIR /tmp
RUN apk add --no-cache curl tar
RUN curl -fsSL \
      "https://github.com/pdf/zfs_exporter/releases/download/v${ZFS_EXPORTER_VERSION}/zfs_exporter-${ZFS_EXPORTER_VERSION}.linux-${TARGETARCH}.tar.gz" \
      -o zfs.tgz \
 && tar -xzf zfs.tgz \
 && mv "zfs_exporter-${ZFS_EXPORTER_VERSION}.linux-${TARGETARCH}/zfs_exporter" /zfs_exporter \
 && chmod +x /zfs_exporter

FROM ubuntu:24.04
ARG ZFS_EXPORTER_VERSION
# org.opencontainers.image.version + .revision + .created come from
# docker/metadata-action in the GHA workflow (driven by the git tag),
# so don't hard-code them here. Only the upstream-binary version is
# fixed at build time, captured in a custom label for traceability.
LABEL org.opencontainers.image.source="https://github.com/ralton-dev/zfs_exporter_image"
LABEL org.opencontainers.image.description="pdf/zfs_exporter packaged with ubuntu:24.04 zfsutils-linux"
LABEL org.opencontainers.image.licenses="MIT"
LABEL upstream.version="v${ZFS_EXPORTER_VERSION}"
LABEL upstream.source="https://github.com/pdf/zfs_exporter"

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      zfsutils-linux \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY --from=download /zfs_exporter /usr/local/bin/zfs_exporter

EXPOSE 9134
ENTRYPOINT ["/usr/local/bin/zfs_exporter"]
CMD ["--web.listen-address=:9134"]
