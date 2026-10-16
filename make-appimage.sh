#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q pitivi | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/scalable/apps/org.pitivi.Pitivi.svg
export DESKTOP=/usr/share/applications/org.pitivi.Pitivi.desktop
export STARTUPWMCLASS=org.pitivi.Pitivi
export DEPLOY_PYTHON=1
export DEPLOY_GTK=1
export DEPLOY_GDK=1

# gdk-pixbuf delegates image decoding to glycin on Arch. quick-sharun only
# reads the ldd of the binaries we pass, and libglycin is reached through
# libgdk_pixbuf, so it never sees it. Passing libglycin-2.so* explicitly makes
# quick-sharun deploy glycin, its loaders and its conf.d. Without it,
# Pixbuf.new_from_file() fails ("null loader") and no image loads.

# Without this, GStreamer only registers a handful of plugins and no
# gst-plugin-scanner, so the UI works but effects, export encoders and frei0r
# are all missing.
export DEPLOY_GSTREAMER_ALL=1

# Pitivi hardcodes /usr/lib/pitivi, /usr/share/pitivi and /usr/share/locale,
# with no env var to relocate them, so they go through pathmap.
# ${SHARUN_DIR} must NOT be escaped here: a literal backslash in .env breaks
# pathmap and pitivi fails to import itself.
#
# pathmap also reverse-maps realpath() by default, and glycin realpaths the
# image path before opening it: the path comes back corrupted
# (trimbar-focused.png -> trimbar-focused.pngar-focused.png), so all 12 PNGs
# in /usr/share/pitivi/pixmaps (markers, trim handles, icons) fail to load.
# PATHMAP_REVERSE=0 (set in .env below) fixes that.
export PATH_MAPPING='
  /usr/lib/pitivi:${SHARUN_DIR}/lib/pitivi
  /usr/share/pitivi:${SHARUN_DIR}/share/pitivi
  /usr/share/locale:${SHARUN_DIR}/share/locale
'

# Deploy dependencies
quick-sharun \
      /usr/bin/pitivi \
      /usr/lib/pitivi/python/pitivi \
      /usr/lib/libpeas-1.0.so* \
      /usr/lib/girepository-1.0 \
      /usr/lib/libgmodule-2.0.so* \
      /usr/share/gstreamer-1.0 \
      /usr/lib/frei0r-1 \
      /usr/lib/libgsttranscoder-1.0.so* \
      /usr/lib/libglycin-2.so*

# /usr/share/gstreamer-1.0 carries the encoding-profiles used by Pitivi's
# render dialog plus the GStreamer element presets.
# /usr/lib/frei0r-1 carries the frei0r video effects (168 plugins).
# /usr/lib/libgsttranscoder-1.0.so* is what the GstTranscoder typelib binds to.
# quick-sharun deploys the typelib (Pitivi imports GstTranscoder) but not the
# shared object, which comes from gst-plugins-bad-libs and is not a direct
# dependency of the pitivi binary. Without it the Render dialog loads, but
# starting a render freezes/crashes a few seconds in.

# Additional changes can be done in between here

# Disable pathmap's reverse mapping so realpath() is left intact (see above).
echo 'PATHMAP_REVERSE=0' >> ./AppDir/.env

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
