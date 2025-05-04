# Allow build scripts to be referenced without being copied into the final image

ARG KERNEL_VERSION
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
#FROM ghcr.io/ublue-os/akmods-extra:${KERNEL_VERSION} AS akmods-extra
FROM ghcr.io/ublue-os/akmods:${KERNEL_VERSION} AS akmods

FROM scratch AS ctx
COPY build_files /

# Base Image - bazzite kernel fails to install facetimehd camera
FROM ghcr.io/ublue-os/kinoite-main:latest AS mbp-bazzite

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



# Setup Copr repos
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    mkdir -p /var/roothome && \
    dnf5 -y install dnf5-plugins && \
    for copr in \
        bazzite-org/bazzite \
        bazzite-org/bazzite-multilib \
        ublue-os/staging \
        ublue-os/packages \
        bazzite-org/LatencyFleX \
        bazzite-org/obs-vkcapture \
        bazzite-org/wallpaper-engine-kde-plugin \
        ycollet/audinux \
        bazzite-org/rom-properties \
        bazzite-org/webapp-manager \
        bazzite-org/vk_hdr_layer \
        hhd-dev/hhd \
        che/nerd-fonts \
        hikariknight/looking-glass-kvmfr \
        mavit/discover-overlay \
        rok/cdemu \
        lizardbyte/beta; \
    do \
        echo "Enabling copr: $copr"; \
        dnf5 -y copr enable $copr; \
        dnf5 -y config-manager setopt copr:copr.fedorainfracloud.org:${copr////:}.priority=98 ;\
    done && unset -v copr && \
    dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release{,-extras} && \
    dnf5 -y config-manager addrepo --overwrite --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo && \
    dnf5 -y install \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
    dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-steam.repo && \
    dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-rar.repo && \
    dnf5 -y config-manager setopt "*bazzite*".priority=1 && \
    dnf5 -y config-manager setopt "*akmods*".priority=2 && \
    dnf5 -y config-manager setopt "*terra*".priority=3 "*terra*".exclude="nerd-fonts topgrade" && \
    dnf5 -y config-manager setopt "terra-mesa".enabled=true && \
    dnf5 -y config-manager setopt "terra-nvidia".enabled=false && \
    eval "$(/ctx/dnf5-setopt setopt '*negativo17*' priority=4 exclude='mesa-* *xone*')" && \
    dnf5 -y config-manager setopt "*rpmfusion*".priority=5 "*rpmfusion*".exclude="mesa-*" && \
    dnf5 -y config-manager setopt "*fedora*".exclude="mesa-* kernel-core-* kernel-modules-* kernel-uki-virt-*" && \
    dnf5 -y config-manager setopt "*staging*".exclude="scx-scheds kf6-* mesa* mutter* rpm-ostree* systemd* gnome-shell gnome-settings-daemon gnome-control-center gnome-software libadwaita tuned*" && \
    /ctx/cleanup

#install kernel
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/tmp/kernel-rpms \
    --mount=type=bind,from=akmods-extra,src=/rpms,dst=/tmp/akmods-extra-rpms \
    --mount=type=bind,from=akmods,src=/rpms,dst=/tmp/akmods-rpms \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install-kernel-akmods && \
    dnf5 -y config-manager setopt "*rpmfusion*".enabled=0 && \
    dnf5 -y copr enable bieszczaders/kernel-cachyos-addons && \
    dnf5 -y install \
        scx-scheds && \
    dnf5 -y copr disable bieszczaders/kernel-cachyos-addons && \
    dnf5 -y swap --repo copr:copr.fedorainfracloud.org:bazzite-org:bazzite bootc bootc && \
    /ctx/cleanup

# # Install mbp facetimehd kernel module
# RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
#     --mount=type=cache,dst=/var/cache \
#     --mount=type=cache,dst=/var/log \
#     --mount=type=tmpfs,dst=/tmp \
#     /ctx/mbp-kernelmod && \
#     ostree container commit

    # Setup firmware
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install-firmware && \
    /ctx/cleanup

# Install patched fwupd
# Install Valve's patched Mesa, Pipewire, Bluez, and Xwayland
# Install patched switcheroo control with proper discrete GPU support
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    declare -A toswap=( \
        ["copr:copr.fedorainfracloud.org:bazzite-org:bazzite"]="wireplumber" \
        ["copr:copr.fedorainfracloud.org:bazzite-org:bazzite-multilib"]="pipewire bluez xorg-x11-server-Xwayland" \
        ["terra-extras"]="switcheroo-control" \
        ["terra-mesa"]="mesa-filesystem" \
        ["copr:copr.fedorainfracloud.org:ublue-os:staging"]="fwupd" \
    ) && \
    for repo in "${!toswap[@]}"; do \
        for package in ${toswap[$repo]}; do dnf5 -y swap --repo=$repo $package $package; done; \
    done && unset -v toswap repo package && \
    dnf5 versionlock add \
        pipewire \
        pipewire-alsa \
        pipewire-gstreamer \
        pipewire-jack-audio-connection-kit \
        pipewire-jack-audio-connection-kit-libs \
        pipewire-libs \
        pipewire-plugin-libcamera \
        pipewire-pulseaudio \
        pipewire-utils \
        wireplumber \
        wireplumber-libs \
        bluez \
        bluez-cups \
        bluez-libs \
        bluez-obexd \
        xorg-x11-server-Xwayland \
        switcheroo-control \
        mesa-dri-drivers \
        mesa-filesystem \
        mesa-libEGL \
        mesa-libGL \
        mesa-libgbm \
        mesa-va-drivers \
        mesa-vulkan-drivers \
        fwupd \
        fwupd-plugin-flashrom \
        fwupd-plugin-modem-manager \
        fwupd-plugin-uefi-capsule-data && \
    dnf5 -y install --enable-repo="*rpmfusion*" --disable-repo="*fedora-multimedia*" \
        libaacs \
        libbdplus \
        libbluray \
        libbluray-utils && \
    /ctx/cleanup

# Remove unneeded packages
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y remove \
        ublue-os-update-services \
        firefox \
        kwrite \
        firefox-langpacks && \
    /ctx/cleanup

# Install new packages
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y install \
        twitter-twemoji-fonts \
        google-noto-sans-cjk-fonts \
        lato-fonts \
        fira-code-fonts \
        nerd-fonts \
        discover-overlay \
        sunshine \
        python3-pip \
        libadwaita \
        duperemove \
        cpulimit \
        sqlite \
        xwininfo \
        xrandr \
        compsize \
        ryzenadj \
        ddcutil \
        input-remapper \
        i2c-tools \
        lm_sensors \
        fw-ectool \
        fw-fanctrl \
        udica \
        ladspa-caps-plugins \
        ladspa-noise-suppression-for-voice \
        pipewire-module-filter-chain-sofa \
        python3-icoextract \
        tailscale \
        webapp-manager \
        htop \
        timg \
        btop \
        duf \
        fish \
        lshw \
        xdotool \
        wmctrl \
        libcec \
        yad \
        f3 \
        pulseaudio-utils \
        lzip \
        p7zip \
        rar \
        libxcrypt-compat \
        vulkan-tools \
        extest.i686 \
        xwiimote-ng \
        fastfetch \
        glow \
        gum \
        vim \
        cockpit-networkmanager \
        cockpit-podman \
        cockpit-selinux \
        cockpit-system \
        cockpit-navigator \
        cockpit-storaged \
        topgrade \
        ydotool \
        stress-ng \
        snapper \
        btrfs-assistant \
        podman-compose \
        edk2-ovmf \
        qemu \
        libvirt \
        lsb_release \
        uupd \
        rocm-hip \
        rocm-opencl \
        rocm-clinfo \
        waydroid \
        cage \
        wlr-randr && \
    sed -i 's|uupd|& --disable-module-distrobox|' /usr/lib/systemd/system/uupd.service && \
    setcap 'cap_sys_admin+p' /usr/bin/sunshine-v* && \
    dnf5 -y --setopt=install_weak_deps=False install \
        rocm-hip \
        rocm-opencl \
        rocm-clinfo \
        rocm-smi && \
    dnf5 -y install \
        $(curl https://api.github.com/repos/bazzite-org/cicpoffs/releases/latest | jq -r '.assets[] | select(.name| test(".*rpm$")).browser_download_url') && \
    mkdir -p /etc/xdg/autostart && \
    sed -i~ -E 's/=.\$\(command -v (nft|ip6?tables-legacy).*/=/g' /usr/lib/waydroid/data/scripts/waydroid-net.sh && \
    sed -i 's/ --xdg-runtime=\\"${XDG_RUNTIME_DIR}\\"//g' /usr/bin/btrfs-assistant-launcher && \
    curl -Lo /usr/bin/installcab https://raw.githubusercontent.com/bazzite-org/steam-proton-mf-wmv/master/installcab.py && \
    chmod +x /usr/bin/installcab && \
    curl -Lo /usr/bin/install-mf-wmv https://github.com/bazzite-org/steam-proton-mf-wmv/blob/master/install-mf-wmv.sh && \
    chmod +x /usr/bin/install-mf-wmv && \
    curl -Lo /tmp/ls-iommu.tar.gz $(curl https://api.github.com/repos/HikariKnight/ls-iommu/releases/latest | jq -r '.assets[] | select(.name| test(".*x86_64.tar.gz$")).browser_download_url') && \
    mkdir -p /tmp/ls-iommu && \
    tar --no-same-owner --no-same-permissions --no-overwrite-dir -xvzf /tmp/ls-iommu.tar.gz -C /tmp/ls-iommu && \
    rm -f /tmp/ls-iommu.tar.gz && \
    cp -r /tmp/ls-iommu/ls-iommu /usr/bin/ && \
    curl -Lo /tmp/scopebuddy.tar.gz https://github.com/HikariKnight/ScopeBuddy/archive/refs/tags/$(curl https://api.github.com/repos/HikariKnight/scopebuddy/releases/latest | jq -r '.tag_name').tar.gz && \
    mkdir -p /tmp/scopebuddy && \
    tar --no-same-owner --no-same-permissions --no-overwrite-dir -xvzf /tmp/scopebuddy.tar.gz -C /tmp/scopebuddy && \
    rm -f /tmp/scopebuddy.tar.gz && \
    cp -r /tmp/scopebuddy/ScopeBuddy-*/bin/* /usr/bin/ && \
    /ctx/cleanup

# Install Steam & Lutris, plus supporting packages
# Downgrade ibus to fix an issue with the Steam keyboard
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y swap \
    --repo copr:copr.fedorainfracloud.org:bazzite-org:bazzite \
        ibus ibus && \
    dnf5 versionlock add \
        ibus && \
    dnf5 -y install \
        gamescope.x86_64 \
        gamescope-libs.x86_64 \
        gamescope-libs.i686 \
        gamescope-shaders \
        jupiter-sd-mounting-btrfs \
        umu-launcher \
        dbus-x11 \
        xdg-user-dirs \
        gobject-introspection \
        libFAudio.x86_64 \
        libFAudio.i686 \
        latencyflex-vulkan-layer \
        vkBasalt.x86_64 \
        vkBasalt.i686 \
        mangohud.x86_64 \
        mangohud.i686 \
        libobs_vkcapture.x86_64 \
        libobs_glcapture.x86_64 \
        libobs_vkcapture.i686 \
        libobs_glcapture.i686 \
        vk_hdr_layer.x86_64 \
        vk_hdr_layer.i686 && \
    dnf5 -y --setopt=install_weak_deps=False install \
        steam \
        lutris && \
    dnf5 -y remove \
        gamemode && \
    curl -Lo /tmp/latencyflex.tar.xz $(curl https://api.github.com/repos/ishitatsuyuki/LatencyFleX/releases/latest | jq -r '.assets[] | select(.name| test(".*.tar.xz$")).browser_download_url') && \
    mkdir -p /tmp/latencyflex && \
    tar --no-same-owner --no-same-permissions --no-overwrite-dir --strip-components 1 -xvf /tmp/latencyflex.tar.xz -C /tmp/latencyflex && \
    rm -f /tmp/latencyflex.tar.xz && \
    mkdir -p /usr/lib64/latencyflex && \
    cp -r /tmp/latencyflex/wine/usr/lib/wine/* /usr/lib64/latencyflex/ && \
    curl -Lo /usr/bin/latencyflex https://raw.githubusercontent.com/bazzite-org/LatencyFleX-Installer/main/install.sh && \
    chmod +x /usr/bin/latencyflex && \
    curl -Lo /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/bin/winetricks && \
    /ctx/cleanup

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y install \
        qt \
        krdp \
        steamdeck-kde-presets-desktop \
        wallpaper-engine-kde-plugin \
        kdeconnectd \
        kdeplasma-addons \
        rom-properties-kf6 \
        fcitx5-mozc \
        fcitx5-chinese-addons \
        fcitx5-hangul \
        kcm-fcitx5 \
        ptyxis && \
    dnf5 -y swap \
    --repo=terra-extras \
        kf6-kio kf6-kio && \
    dnf5 versionlock add \
        kf6-kio-core \
        kf6-kio-core-libs \
        kf6-kio-doc \
        kf6-kio-file-widgets \
        kf6-kio-gui \
        kf6-kio-widgets \
        kf6-kio-widgets-libs && \
    dnf5 -y remove \
        plasma-welcome \
        plasma-welcome-fedora \
        plasma-browser-integration \
        konsole && \
    git clone https://github.com/catsout/wallpaper-engine-kde-plugin.git --depth 1 --branch main /tmp/wallpaper-engine-kde-plugin && \
    kpackagetool6 --type=Plasma/Wallpaper --global --install /tmp/wallpaper-engine-kde-plugin/plugin && \
    sed -i '/<entry name="launchers" type="StringList">/,/<\/entry>/ s/<default>[^<]*<\/default>/<default>preferred:\/\/browser,applications:steam.desktop,applications:net.lutris.Lutris.desktop,applications:org.gnome.Ptyxis.desktop,applications:org.kde.discover.desktop,preferred:\/\/filemanager<\/default>/' /usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/config/main.xml && \
    sed -i '/<entry name="favorites" type="StringList">/,/<\/entry>/ s/<default>[^<]*<\/default>/<default>preferred:\/\/browser,steam.desktop,net.lutris.Lutris.desktop,systemsettings.desktop,org.kde.dolphin.desktop,org.kde.kate.desktop,org.gnome.Ptyxis.desktop,org.kde.discover.desktop,system-update.desktop<\/default>/' /usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/config/main.xml && \
    sed -i 's@\[Desktop Action new-window\]@\[Desktop Action new-window\]\nX-KDE-Shortcuts=Ctrl+Alt+T@g' /usr/share/applications/org.gnome.Ptyxis.desktop && \
    sed -i '/^Comment/d' /usr/share/applications/org.gnome.Ptyxis.desktop && \
    sed -i 's@Exec=ptyxis@Exec=kde-ptyxis@g' /usr/share/applications/org.gnome.Ptyxis.desktop && \
    sed -i 's@Keywords=@Keywords=konsole;console;@g' /usr/share/applications/org.gnome.Ptyxis.desktop && \
    sed -i 's/^Exec=plasma-discover/& --backends flatpak-backend/' /usr/share/applications/org.kde.discover.desktop && \
    cp /usr/share/applications/org.gnome.Ptyxis.desktop /usr/share/kglobalaccel/org.gnome.Ptyxis.desktop && \
    setcap 'cap_net_raw+ep' /usr/libexec/ksysguard/ksgrd_network_helper \

# ublue-os packages
# Homebrew & Bash Prexec
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 install -y ublue-brew && \
    curl -Lo /usr/share/bash-prexec https://raw.githubusercontent.com/ublue-os/bash-preexec/master/bash-preexec.sh && \
    /ctx/cleanup

# ublue-os-media-automount-udev, mount non-removable device partitions automatically under /media/media-automount/
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 install -y --enable-repo=copr:copr.fedorainfracloud.org:ublue-os:packages \
        ublue-os-media-automount-udev && \
    /ctx/cleanup

# Cleanup & Finalize
COPY system_files/overrides /
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    rm -f /etc/profile.d/toolbox.sh && \
    mkdir -p /var/tmp && chmod 1777 /var/tmp && \
    cp --no-dereference --preserve=links /usr/lib/libdrm.so.2 /usr/lib/libdrm.so && \
    cp --no-dereference --preserve=links /usr/lib64/libdrm.so.2 /usr/lib64/libdrm.so && \
    sed -i 's@/usr/bin/steam@/usr/bin/bazzite-steam@g' /usr/share/applications/steam.desktop && \
    sed -i 's@Exec=steam steam://open/bigpicture@Exec=/usr/bin/bazzite-steam-bpm@g' /usr/share/applications/steam.desktop && \
    mkdir -p /etc/skel/.config/autostart/ && \
    cp "/usr/share/applications/steam.desktop" "/etc/skel/.config/autostart/steam.desktop" && \
    sed -i 's@/usr/bin/bazzite-steam %U@/usr/bin/bazzite-steam -silent %U@g' /etc/skel/.config/autostart/steam.desktop && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/nvtop.desktop && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/btop.desktop && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/yad-icon-browser.desktop && \
    sed -i 's/#UserspaceHID.*/UserspaceHID=true/' /etc/bluetooth/input.conf && \
    sed -i "s/^SCX_SCHEDULER=.*/SCX_SCHEDULER=scx_bpfland/" /etc/default/scx && \
    sed -i "s|grub_probe\} --target=device /\`|grub_probe} --target=device /sysroot\`|g" /usr/bin/grub2-mkconfig && \
    rm -f /usr/share/vulkan/icd.d/lvp_icd.*.json && \
    rm -f /usr/lib/systemd/system/service.d/50-keep-warm.conf && \
    mkdir -p "/etc/xdg/autostart" && \
    cp "/usr/share/applications/discover_overlay.desktop" "/etc/xdg/autostart/discover_overlay.desktop" && \
    sed -i 's@Exec=discover-overlay@Exec=/usr/bin/bazzite-discover-overlay@g' /etc/xdg/autostart/discover_overlay.desktop && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/discover_overlay.desktop && \
    echo "import \"/usr/share/ublue-os/just/80-bazzite.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/81-bazzite-fixes.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/82-bazzite-apps.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/82-bazzite-cdemu.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/82-bazzite-sunshine.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/82-bazzite-rmlint.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/82-bazzite-waydroid.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/83-bazzite-audio.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/84-bazzite-virt.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/85-bazzite-image.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/86-bazzite-windows.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/87-bazzite-framegen.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/88-bazzite-webapps.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/90-bazzite-de.just\"" >> /usr/share/ublue-os/justfile && \
    if grep -q "kinoite" <<< "${BASE_IMAGE_NAME}"; then \
      systemctl enable usr-share-sddm-themes.mount && \
      mkdir -p "/usr/share/ublue-os/dconfs/desktop-kinoite/" && \
      cp "/usr/share/glib-2.0/schemas/zz0-"*"-bazzite-desktop-kinoite-"*".gschema.override" "/usr/share/ublue-os/dconfs/desktop-kinoite/" && \
      find "/etc/dconf/db/distro.d/" -maxdepth 1 -type f -exec cp {} "/usr/share/ublue-os/dconfs/desktop-kinoite/" \; && \
      dconf-override-converter to-dconf "/usr/share/ublue-os/dconfs/desktop-kinoite/zz0-"*"-bazzite-desktop-kinoite-"*".gschema.override" && \
      rm "/usr/share/ublue-os/dconfs/desktop-kinoite/zz0-"*"-bazzite-desktop-kinoite-"*".gschema.override" \
    ; else \
      mkdir -p "/usr/share/ublue-os/dconfs/desktop-silverblue/" && \
      cp "/usr/share/glib-2.0/schemas/zz0-"*"-bazzite-desktop-silverblue-"*".gschema.override" "/usr/share/ublue-os/dconfs/desktop-silverblue/" && \
      find "/etc/dconf/db/distro.d/" -maxdepth 1 -type f -exec cp {} "/usr/share/ublue-os/dconfs/desktop-silverblue/" \; && \
      dconf-override-converter to-dconf "/usr/share/ublue-os/dconfs/desktop-silverblue/zz0-"*"-bazzite-desktop-silverblue-"*".gschema.override" && \
      sed -i 's/\[org.gtk.Settings.FileChooser\]/\[org\/gtk\/settings\/file-chooser\]/g; s/\[org.gtk.gtk4.Settings.FileChooser\]/\[org\/gtk\/gtk4\/settings\/file-chooser\]/g' "/usr/share/ublue-os/dconfs/desktop-silverblue/zz0-00-bazzite-desktop-silverblue-global" && \
      rm "/usr/share/ublue-os/dconfs/desktop-silverblue/zz0-"*"-bazzite-desktop-silverblue-"*".gschema.override" \
    ; fi && \
    mkdir -p /tmp/bazzite-schema-test && \
    find "/usr/share/glib-2.0/schemas/" -type f ! -name "*.gschema.override" -exec cp {} "/tmp/bazzite-schema-test/" \; && \
    cp "/usr/share/glib-2.0/schemas/zz0-"*".gschema.override" "/tmp/bazzite-schema-test/" && \
    glib-compile-schemas --strict /tmp/bazzite-schema-test && \
    glib-compile-schemas /usr/share/glib-2.0/schemas &>/dev/null && \
    rm -r /tmp/bazzite-schema-test && \
    sed -i 's/stage/none/g' /etc/rpm-ostreed.conf && \
    for repo in \
        fedora-cisco-openh264 \
        fedora-steam \
        fedora-rar \
        terra \
        terra-extras \
        negativo17-fedora-multimedia \
        _copr_ublue-os-akmods; \
    do \
        sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/$repo.repo; \
    done && for copr in \
        bazzite-org/bazzite \
        bazzite-org/bazzite-multilib \
        ublue-os/staging \
        ublue-os/packages \
        bazzite-org/LatencyFleX \
        bazzite-org/obs-vkcapture \
        bazzite-org/vk_hdr_layer \
        bazzite-org/wallpaper-engine-kde-plugin \
        ycollet/audinux \
        bazzite-org/rom-properties \
        bazzite-org/webapp-manager \
        hhd-dev/hhd \
        che/nerd-fonts \
        mavit/discover-overlay \
        lizardbyte/beta \
        rok/cdemu \
        hikariknight/looking-glass-kvmfr; \
    do \
        dnf5 -y copr disable $copr; \
    done && unset -v copr && \
    dnf5 config-manager setopt "*tailscale*".enabled=0 && \
    dnf5 config-manager setopt "*charm*".enabled=0 && \
    eval "$(/ctx/dnf5-setopt setopt '*negativo17*' enabled=0)" && \
    sed -i 's#/var/lib/selinux#/etc/selinux#g' /usr/lib/python3.*/site-packages/setroubleshoot/util.py && \
    sed -i 's|#default.clock.allowed-rates = \[ 48000 \]|default.clock.allowed-rates = [ 44100 48000 ]|' /usr/share/pipewire/pipewire.conf && \
    sed -i 's|^ExecStart=.*|ExecStart=/usr/libexec/rtkit-daemon --no-canary|' /usr/lib/systemd/system/rtkit-daemon.service && \
    sed -i 's/balanced=balanced$/balanced=balanced-bazzite/' /etc/tuned/ppd.conf && \
    sed -i 's/performance=throughput-performance$/performance=throughput-performance-bazzite/' /etc/tuned/ppd.conf && \
    sed -i 's/balanced=balanced-battery$/balanced=balanced-battery-bazzite/' /etc/tuned/ppd.conf && \
    ln -s /usr/bin/true /usr/bin/pulseaudio && \
    mkdir -p /etc/flatpak/remotes.d && \
    curl -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo && \
    systemctl enable brew-setup.service && \
    systemctl disable brew-upgrade.timer && \
    systemctl disable brew-update.timer && \
    systemctl disable fw-fanctrl.service && \
    systemctl disable scx.service && \
    systemctl disable scx_loader.service && \
    systemctl enable input-remapper.service && \
    systemctl enable bazzite-flatpak-manager.service && \
    systemctl disable rpm-ostreed-automatic.timer && \
    systemctl enable uupd.timer && \
    systemctl enable incus-workaround.service && \
    systemctl enable bazzite-hardware-setup.service && \
    systemctl disable tailscaled.service && \
    systemctl enable dev-hugepages1G.mount && \
    systemctl --global enable bazzite-user-setup.service && \
    systemctl --global enable podman.socket && \
    systemctl --global enable systemd-tmpfiles-setup.service && \
    systemctl --global disable sunshine.service && \
    systemctl disable waydroid-container.service && \
    systemctl disable force-wol.service && \
    curl -Lo /etc/dxvk-example.conf https://raw.githubusercontent.com/doitsujin/dxvk/master/dxvk.conf && \
    curl -Lo /usr/bin/waydroid-choose-gpu https://raw.githubusercontent.com/bazzite-org/waydroid-scripts/main/waydroid-choose-gpu.sh && \
    chmod +x /usr/bin/waydroid-choose-gpu && \
    curl -Lo /usr/lib/sysctl.d/99-bore-scheduler.conf https://github.com/CachyOS/CachyOS-Settings/raw/master/usr/lib/sysctl.d/99-bore-scheduler.conf && \
    curl -Lo /etc/distrobox/docker.ini https://github.com/ublue-os/toolboxes/raw/refs/heads/main/apps/docker/distrobox.ini && \
    curl -Lo /etc/distrobox/incus.ini https://github.com/ublue-os/toolboxes/raw/refs/heads/main/apps/incus/distrobox.ini && \
    /ctx/build-initramfs && \
    /ctx/finalize


# /usr/libexec/containerbuild/cleanup.sh && \

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


    
### LINTING
## Verify final image and contents are correct.
RUN dnf5 config-manager setopt skip_if_unavailable=1 && \
    bootc container lint
