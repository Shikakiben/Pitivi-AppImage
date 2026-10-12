#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
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

# matplotlib 3.10 instead of the 3.11.x shipped by Arch.
#
# Pitivi 2023.03 dies with SIGSEGV when a clip is dragged into the timeline,
# and the crash happens inside matplotlib's own draw code:
#
#   File "matplotlib/figure.py", line 161 in _get_draw_artists
#   File "matplotlib/figure.py", line 3271 in draw
#   File "matplotlib/backends/backend_gtk3cairo.py", line 30 in on_draw_event
#   File "pitivi/timeline/elements.py", line 812 in do_draw
#
# so matplotlib is reached from GtkWidget's do_draw, to paint the keyframe
# curve of a clip. The official Flatpak on this very same machine, with the
# same project and the same media, does not crash - and matplotlib is one of
# the few pieces where the two stacks actually differ:
#
#                 Flatpak (works)      Arch today (crashes)
#   Python            3.13.15                 3.14.8
#   matplotlib         3.9.4                  3.11.2
#   pygobject         3.50.0                  3.58.1
#   GStreamer         1.26.11                 1.28.8
#   numpy             1.26.4                  2.5.4
#
# Why this one package can be pinned when GStreamer could not:
#
#   GStreamer is a family of fifteen packages built on top of each other and
#   linked against ffmpeg and opencv. Moving one of them breaks the others, and
#   the AppImage loses video decoding. matplotlib is the opposite case: it is a
#   leaf, and the only compiled dependency it really cares about is numpy, whose
#   2.x series promises ABI stability across the whole series (a module built
#   against numpy 2.3 keeps working with numpy 2.5). Installing this older
#   matplotlib changes nothing else in the system.
#
# 3.10.9-1 is the last 3.10.x Arch built (2026-04-24), just before 3.11.0
# (2026-06-15). Arch only ever keeps one version in the repos, so the package
# comes from archive.archlinux.org. A different version can be tried by setting
# MATPLOTLIB_PIN.
#
# If this does not change anything, matplotlib is innocent and the next
# suspects are pygobject and Python itself, which cannot be moved on their own.
MATPLOTLIB_PIN="${MATPLOTLIB_PIN:-3.10.9-1}"

echo "Installing matplotlib $MATPLOTLIB_PIN (see comments above)..."
echo "---------------------------------------------------------------"
workdir=$(pwd)
mkdir -p /tmp/mpl-pin
cd /tmp/mpl-pin
file="python-matplotlib-$MATPLOTLIB_PIN-$ARCH.pkg.tar.zst"
curl -sfLO "https://archive.archlinux.org/packages/p/python-matplotlib/$file" \
    || { echo "ERROR: could not download $file" >&2; exit 1; }
pacman -U --noconfirm --overwrite '*' "$file"
cd "$workdir"
pacman -Q python-matplotlib python-numpy

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
