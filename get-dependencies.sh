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
                 

# GStreamer 1.26 instead of the 1.28.x shipped by Arch.
#
# Pitivi 2023.03 segfaults with GStreamer 1.28: the timeline keyframe curve is a
# matplotlib widget embedded in a GTK3 window, and GES 1.28 corrupts memory
# (the 1.28 release notes list use-after-free fixes in GES control bindings and
# GESUriSource callbacks). The corruption only shows up later, when matplotlib
# redraws the curve: figure.py raises from inside GtkWidget.do_draw(), Gtk keeps
# restarting the draw and the app dies with SIGSEGV a few seconds after a clip
# is added to the timeline.
#
# Notes on how this was narrowed down:
#   - Pitivi master (87 commits after 2023.03) crashes in the same place, so
#     this is not something fixed by newer Pitivi code.
#   - matplotlib + GTK3 alone, in the same AppImage, redraw the curve 149 times
#     without crashing -> Python 3.14 and matplotlib 3.11 are not at fault.
#   - The official Flatpak works, and its manifest pins GStreamer 1.26.
#     https://github.com/flathub/org.pitivi.Pitivi (module "gstreamer", 1.26.8)
#
# 1.26.10 is the latest 1.26.x Arch built. Arch only keeps one rolling version
# in the repos, so the pinned packages come from archive.archlinux.org.
# Keep this list in sync with the gst* packages installed above: they all have
# to move together, they are built against each other.
GST_PIN="${GST_PIN:-1.26.10-5}"
GST_PKGS="gstreamer gst-plugins-base gst-plugins-base-libs gst-plugins-good
gst-plugins-bad gst-plugins-bad-libs gst-plugins-ugly gst-libav
gst-editing-services gst-python gst-plugin-gtk gst-devtools gst-devtools-libs
gst-plugin-va gst-rtsp-server gst-plugin-opencv"

echo "Pinning GStreamer $GST_PIN (see comments above)..."
echo "---------------------------------------------------------------"
mkdir -p /tmp/gst-pin
cd /tmp/gst-pin
for pkg in $GST_PKGS; do
    file="$pkg-$GST_PIN-$ARCH.pkg.tar.zst"
    [ -f "$file" ] && continue
    curl -sfLO "https://archive.archlinux.org/packages/${pkg%${pkg#?}}/$pkg/$file" \
        || { echo "ERROR: could not download $file" >&2; exit 1; }
done
pacman -U --noconfirm --overwrite '*' ./*.pkg.tar.zst
cd /work
pacman -Q gstreamer gst-editing-services

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
