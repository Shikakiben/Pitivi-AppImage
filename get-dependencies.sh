#!/bin/sh

set -eu

ARCH=$(uname -m)

# Build against an Arch Linux SNAPSHOT of the whole repository.
#
# Pitivi 2023.03 crashes with SIGSEGV under CPython 3.14 (a use-after-free in
# re-entrant C->Py->C callbacks). Python 3.13 is not affected.
#
# Arch is rolling and every Python module is built against one exact interpreter
# version, so a single package cannot be moved back. archive.archlinux.org keeps
# complete snapshots of the whole repository for every day; pointing pacman at
# one rebuilds the entire stack as it was on that date, all mutually compatible.
#
# 2025/11/01 is the last snapshot before Arch rebuilt the world for Python 3.14
# (which also bumped pitivi to 2023.03-10 on 2025-12-14), so it still ships the
# 3.13 series: pitivi 2023.03-9, python 3.13.7, matplotlib 3.10.6,
# python-gobject 3.54.5, gstreamer 1.26.7, ffmpeg 8.0, opencv 4.12.
#
# Temporary: drop the snapshot once CPython fixes the bug.
ARCH_SNAPSHOT="${ARCH_SNAPSHOT:-2025/11/01}"

echo "Pinning the repository to the Arch snapshot $ARCH_SNAPSHOT..."
echo "---------------------------------------------------------------"
echo "Server=https://archive.archlinux.org/repos/$ARCH_SNAPSHOT/\$repo/os/\$arch" \
    > /etc/pacman.d/mirrorlist

# The snapshot ships the archlinux-keyring of that date; several packager keys
# have been revoked since, so pacman rejects the older packages. The archive is
# Arch's own mirror, fetched over HTTPS.
sed -i 's/^SigLevel.*/SigLevel = Never/' /etc/pacman.conf

# 'vulkan-mesa-device-select' was split in two after the snapshot date, which
# pacman reports as a conflict. This build does not use Vulkan.
pacman -Rdd --noconfirm vulkan-mesa-implicit-layers 2>/dev/null || :

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
# -Syyuu rather than -Syu: the extra 'u' lets pacman downgrade to the snapshot.
pacman -Syyuu --noconfirm --overwrite '*' \
                 xorg-server-xvfb \
                 curl \
                 wget \
                 pitivi \
                 libpeas \
                 frei0r-plugins \
                 gst-libav \
                 gst-plugin-opencv \
                 gst-plugins-ugly \
                 python-librosa

echo "Snapshot versions in use:"
echo "---------------------------------------------------------------"
pacman -Q pitivi python python-matplotlib python-gobject python-numpy \
          gstreamer gst-editing-services ffmpeg opencv

# Thumbnails fix: Pitivi generates them in RGBA, but JPEG has no alpha channel
# and glycin refuses to encode RGBA as JPEG, so every thumbnail fails to save
# and the timeline clips stay blank. Switch the caps to RGB. (Same fix as the
# Flatpak's pitivi-thumbnails patch, missing from the Arch package.)
PREVIEWERS=/usr/lib/pitivi/python/pitivi/timeline/previewers.py
echo "Applying the RGBA -> RGB thumbnails fix..."
echo "---------------------------------------------------------------"
sed -i 's/format=(string)RGBA/format=(string)RGB/g' "$PREVIEWERS"
grep -n 'format=(string)' "$PREVIEWERS"

# The debloated package set is NOT used here. get-debloated-pkgs installs
# prebuilt .pkg.tar.zst from a GitHub release with 'pacman -U', so it never
# reads /etc/pacman.d/mirrorlist: the snapshot above does not apply to them.
# That release is rebuilt against today's Arch, which is 3.14, so it would drag
# 3.14 packages back in and break the snapshot. Restore it once we go back to
# the current repository.
# get-debloated-pkgs --add-common --prefer-nano '!' glycin

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here
