# Allow build scripts to be referenced without being copied into the final image

LABEL org.opencontainers.image.source=https://github.com/rlatosky/mbp-bazzite

ARG KERNEL_VERSION
FROM ghcr.io/ublue-os/akmods-extra:${KERNEL_VERSION} AS akmods-extra
FROM ghcr.io/ublue-os/akmods:${KERNEL_VERSION} AS akmods

FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite:stable

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


#     /tmp/akmods-extra-rpms/kmods/kmod-facetimehd*.rpm \

RUN --mount=type=bind,from=akmods-extra,src=/rpms,dst=/tmp/akmods-extra-rpms \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=akmods,src=/rpms,dst=/tmp/akmods-rpms \
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo && \
    find /tmp/akmods-extra-rpms && \
    find /tmp/akmods-rpms && \
    rpm-ostree install \
    /tmp/akmods-rpms/kmods/*kvmfr*.rpm \
    /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
    /tmp/akmods-rpms/kmods/*wl*.rpm \
    /tmp/akmods-extra-rpms/kmods/*gcadapter_oc*.rpm \
    /tmp/akmods-extra-rpms/kmods/*evdi*.rpm \
    || true && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion-*.repo && \
    ostree container commit

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    ostree container commit
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
