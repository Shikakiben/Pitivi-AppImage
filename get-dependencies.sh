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

# Apply the thumbnail pixel format fix that the Flatpak carries on top of the
# 2023.03.0 tag.
#
# Pitivi 2023.03 dies with SIGSEGV when a clip is dragged into the timeline.
# The crash is inside matplotlib's draw, reached from GtkWidget's draw while
# painting the keyframe curve of the clip.
#
# The Flatpak applies three patches on top of the same upstream tag, and this
# is the only functional one that the Arch package does not already have:
#
#   pitivi-appdata.patch      metadata only, irrelevant here
#   pitivi-viewer.patch       ALREADY in the Arch package (the pkgrel rebuilds
#                             backported it: Pipeline.create_sink() is gone from
#                             utils/pipeline.py and viewer.py sets the preview
#                             video sink only after the widget is embedded)
#   pitivi-thumbnails.patch   NOT in the Arch package  <-- applied below
#
# pitivi-thumbnails.patch is upstream commit 57199472, "timeline: generate
# thumbnails in RGB - RGBA isn't supported to be saved as JPEG", see
# https://gitlab.gnome.org/GNOME/pitivi/-/issues/2677
#
# It is applied here instead of via 'patch' on purpose: the AppImage is built
# from pacman's copy of pitivi, so editing the file after the packages are in
# place is enough, and a two-word substitution is easier to read than a patch
# file. quick-sharun picks up whatever sits in /usr/lib/pitivi afterwards.
#
# Note on what has already been ruled out at this point, so this stays the only
# variable being tested:
#   Pitivi master (a6473c58, 87 commits after 2023.03) - crashes the same
#   GStreamer 1.26.10 instead of 1.28.8                   - no change
#   matplotlib 3.10.9 instead of 3.11.2                   - no change
#
# Left over from those tests: Python 3.14.8 and pygobject 3.58.1 are the only
# other differences against the working Flatpak, but neither can be moved on
# its own on Arch.
PREVIEWERS=/usr/lib/pitivi/python/pitivi/timeline/previewers.py

echo "Applying the RGBA -> RGB thumbnails fix (see comments above)..."
echo "---------------------------------------------------------------"
if [ ! -f "$PREVIEWERS" ]; then
    echo "ERROR: $PREVIEWERS not found" >&2
    exit 1
fi
sed -i 's/format=(string)RGBA/format=(string)RGB/g' "$PREVIEWERS"
grep -n 'format=(string)' "$PREVIEWERS"

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
