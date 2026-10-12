#!/bin/sh

set -eu

ARCH=$(uname -m)

# Build against an Arch Linux SNAPSHOT of the whole repository.
#
# Pitivi 2023.03 is the last release (March 2023) and dies with SIGSEGV when a
# clip is dragged into the timeline. The crash is inside matplotlib's draw,
# called from GtkWidget.do_draw() on the keyframe curve. The official Flatpak
# on the very same machine, with the same project and the same media, works.
#
# The code is identical in both (both use the upstream 2023.03.0 tag), and the
# app has barely evolved since - local development is maintenance only. So the
# difference has to be the stack it is built against:
#
#                 Flatpak (works)      Arch today (crashes)
#   Python            3.13.15                 3.14.8
#   matplotlib         3.9.4                  3.11.2
#   pygobject         3.50.0                  3.58.1
#   GStreamer         1.26.11                 1.28.8
#   numpy             1.26.4                  2.5.4
#
# Arch is a rolling release: the repos carry exactly one version of each
# package, so moving a single package back is impossible. Downgrading only
# GStreamer to 1.26 has been tried and makes things worse - that gst-libav is
# linked against the older ffmpeg (libavcodec.so.62 vs .63) and against the
# older opencv, so gst-plugin-scanner can no longer load libgstlibav,
# libgstopencv, libgstvpx and friends, and the AppImage loses video decoding.
# Python is worse still: every Python module is built against one exact
# interpreter version, so it cannot be moved on its own at all.
#
# archive.archlinux.org keeps complete and mutually consistent snapshots of the
# whole repository for every day. Pointing pacman at one snapshot rebuilds the
# entire stack as it was on that date, so everything stays compatible with
# everything else - the same principle as the Flatpak's frozen runtime, but
# without leaving the packaging tooling.
#
# 2025/11/01 is the last snapshot before Arch rebuilt the world for Python
# 3.14 (which is also what bumped pitivi to 2023.03-10 on 2025-12-14), so it
# still ships the 3.13 series:
#   pitivi 2023.03-9, python 3.13.7, matplotlib 3.10.6,
#   python-gobject 3.54.5, gstreamer/gst-editing-services 1.26.7,
#   ffmpeg 8.0, opencv 4.12
ARCH_SNAPSHOT="${ARCH_SNAPSHOT:-2025/11/01}"

echo "Pinning the repository to the Arch snapshot $ARCH_SNAPSHOT..."
echo "---------------------------------------------------------------"
echo "Server=https://archive.archlinux.org/repos/$ARCH_SNAPSHOT/\$repo/os/\$arch" \
    > /etc/pacman.d/mirrorlist

# Signatures are not verified while on the snapshot: it ships the
# archlinux-keyring of that date, and several packager keys have been revoked
# since, so pacman refuses to accept the older packages ("key is disabled").
# The archive is Arch's own mirror, fetched over HTTPS.
sed -i 's/^SigLevel.*/SigLevel = Never/' /etc/pacman.conf

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
# -Syyuu rather than -Syu: the extra 'u' lets pacman downgrade the base system
# to the snapshot instead of refusing to move backwards.
#
# Vulkan stays at its current, newer version. 'vulkan-mesa-device-select' was
# split into two packages after the snapshot date, so the snapshot side and the
# current side do not line up (pacman reports a conflict) - and get-debloated-pkgs
# installs freshly built vulkan-*-nano packages a few lines below that require
# the NEW 'vulkan-mesa-implicit-layers'. Ignoring the whole set keeps both sides
# consistent. Pitivi does not use Vulkan.
pacman -Syyuu --noconfirm --overwrite '*' \
                 --ignore vulkan-intel,vulkan-radeon,vulkan-virtio,vulkan-mesa-device-select,vulkan-mesa-implicit-layers \
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

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
# '! glycin' excludes the debloated 'glycin-mini' from the '--add-common' set.
# glycin-mini is actually glycin-ng, a drop-in rewrite of GNOME glycin, and it
# fails to decode grayscale / 1-bit PNGs (modes L, LA and 1 return NULL from
# GdkPixbuf.Pixbuf.new_from_file*). Pitivi ships a few effect thumbnails in
# those modes and pitivi/effects.py does not catch the resulting exception, so
# the whole Effects panel ends up empty and rendering breaks.
# Keeping the real glycin avoids this and lets quick-sharun deploy the glycin
# loaders and bubblewrap the same way it does for any GNOME glycin app.
get-debloated-pkgs --add-common --prefer-nano '!' glycin

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here
