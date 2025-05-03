#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux timg

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 41 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

curl -L -o /etc/yum.repos.d/_copr_mulderje-intel-mac-rpms.repo \
    "https://copr.fedorainfracloud.org/coprs/mulderje/intel-mac-rpms/repo/fedora-${RELEASE}/mulderje-intel-mac-rpms-fedora-${RELEASE}.repo"

echo "Fixing directory permissions for build ..."
chmod a=rwx,u+t /tmp # fix /tmp permissions
mkdir -p /run/akmods # fix missing location for lock file

### BUILD facetimehd (succeed or fail-fast with debug output)
echo "Installing akmod-facetimehd-*.fc${RELEASE}.${ARCH} ..."
dnf5 install -y akmod-facetimehd-*.fc${RELEASE}.${ARCH}

echo "Patching /usr/sbin/akmods (should not see --nogpgcheck or --disablerepo flags below) ..."
# fix the --gpgcheck and --disablerepo errors for /usr/sbin/akmods
# see: https://universal-blue.discourse.group/t/need-help-building-system76-io-akmods/5725/3
# Note: escape the $ and * if in double quotes, and use double quotes to avoid escaping the single quotes!
sed -i "s/dnf -y \${pkg_install:-install} --nogpgcheck --disablerepo='\*'/dnf5 -y \${pkg_install:-install}/" /usr/sbin/akmods
# check this is working
cat /usr/sbin/akmods | grep "dnf5 -y"

echo "Running akmods for facetimehd ..."
akmods --force --kernels "${KERNEL}" --kmod facetimehd

modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz" > /dev/null \
|| (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_mulderje-facetimehd-kmod.repo
rm -f /etc/yum.repos.d/_copr_mulderje-intel-mac-rpms.repo

#### Example for enabling a System Unit File

systemctl enable podman.socket
