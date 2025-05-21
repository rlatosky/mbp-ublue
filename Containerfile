# Allow build scripts to be referenced without being copied into the final image

LABEL org.opencontainers.image.source=https://github.com/rlatosky/mbp-bazzite

ARG KERNEL_VERSION
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
#FROM ghcr.io/ublue-os/akmods-extra@sha256:ae00ea0caca27bc3cb593f0ffc71f586b9cab7920cdadcb9f8a0df6a36e49867 AS akmods-extra
#FROM ghcr.io/ublue-os/akmods:${KERNEL_VERSION} AS akmods

FROM scratch AS ctx
COPY build_files /

# Base Image - bazzite kernel fails to install facetimehd camera
FROM ghcr.io/ublue-os/aurora-dx:stable AS mbp-bazzite

# COPY system_files/desktop/shared system_files/desktop/kinoite /

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

# --mount=type=bind,from=akmods,src=/rpms,dst=/tmp/akmods-rpms
#     /tmp/akmods-rpms/kmods/*kvmfr*.rpm \
#     /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
#     /tmp/akmods-rpms/kmods/*wl*.rpm \

#     rpm-ostree override replace \
#     --experimental \
#     --from repo=copr:copr.fedorainfracloud.org:ublue-os:staging \
#     fwupd \
#     fwupd-plugin-flashrom \
#     fwupd-plugin-modem-manager \
#     fwupd-plugin-uefi-capsule-data && \

# Install mbp facetimehd kernel module
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build-kmod-facetimehd && \
    /ctx/cleanup && \
    ostree container commit

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install-other-packages && \
    /ctx/cleanup && \
    ostree container commit

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/add-systemd-services && \
    /ctx/cleanup && \
    ostree container commit

#     # Setup firmware
# RUN --mount=type=cache,dst=/var/cache \
#     --mount=type=cache,dst=/var/log \
#     --mount=type=bind,from=ctx,source=/,target=/ctx \
#     --mount=type=tmpfs,dst=/tmp \
#     /ctx/install-firmware && \
#     /ctx/cleanup

### LINTING
## Verify final image and contents are correct.
RUN dnf5 config-manager setopt skip_if_unavailable=1 && \
    bootc container lint
