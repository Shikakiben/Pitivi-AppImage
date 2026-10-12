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
