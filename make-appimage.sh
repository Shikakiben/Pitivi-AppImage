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

# On Arch, libgdk-pixbuf does not decode images itself: it delegates to glycin
# (libgdk_pixbuf-2.0.so has a NEEDED entry on libglycin-2.so.0), which runs each
# image decoder as a separate "loader" binary (glycin-image-rs, glycin-svg...)
# and also needs its config in /usr/share/glycin-loaders.
#
# quick-sharun only inspects the ldd of the binaries we pass, and libglycin is a
# second-level dependency (pulled in through libgdk_pixbuf), so its automatic
# detection never runs for Pitivi. Passing libglycin-2.so* explicitly as an
# argument makes quick-sharun see it and turn glycin deployment on for real
# (it then also copies glycin-loaders/*/*, the conf.d directory in
# share/glycin-loaders and the glycin-fix preload).
#
# Without that, GdkPixbuf.Pixbuf.new_from_file() fails with "null loader (0)";
# Pitivi raises that from inside GtkWidget.do_draw(), Gtk then re-runs the draw
# in a loop, the frames pile up and the app segfaults a few seconds later. That
# was the crash on every click, and it also emptied the Effects panel.

# GStreamer is the heart of Pitivi: it is already deployed implicitly through
# the GStreamer libraries we pass, but "implicit" only deploys a handful of
# plugins and, crucially, no gst-plugin-scanner -> GStreamer then prints
# "External plugin loader failed" and NO plugin gets registered: the UI works
# but almost everything is missing (no effects, no export encoders, no
# frei0r...). Deploy the full plugin set explicitly.
export DEPLOY_GSTREAMER_ALL=1

# Pitivi hardcodes both LIBDIR=/usr/lib + PKGDATADIR=/usr/share/pitivi *and*
# its gettext domain directory: bin/pitivi calls
#     gettext.bindtextdomain("pitivi", os.path.join("/usr/share", "locale"))
# There is no environment variable to relocate that path (TEXTDOMAINDIR is
# ignored as soon as bindtextdomain is given an explicit directory -- and
# Pitivi discards LC_ALL too), so it has to go through pathmap as well.
# Without this entry the app runs in English no matter the system locale.
# NOTE: ${SHARUN_DIR} MUST NOT be escaped here. quick-sharun itself expands it;
# writing \${SHARUN_DIR} (inside the single quotes) leaves a literal backslash
# in the generated .env, which breaks pathmap and makes pitivi fail to import
# its own module ("No module named 'pitivi'").
#
# But PATH_MAPPING alone is not enough: pathmap reverse-maps its own outputs by
# default (PATHMAP_REVERSE, on unless disabled). That reverse mapping also
# applies to realpath()/canonicalize_file_name(), and glycin -- the loader
# gdk-pixbuf delegates every image decode to on Arch -- canonicalizes the path
# it is given. It therefore received a corrupted path built out of the original
# one plus the last (len(TARGET) - len(SOURCE)) characters of it, e.g.
#     /usr/share/pitivi/pixmaps/trimbar-focused.pngused.png   (8 = 25 - 17)
#     ...trimbar-focused.png/share/pitivi/pixmaps/...        (36 = 53 - 17)
# could never be opened. Pitivi raises that from inside GtkWidget.do_draw(),
# Gtk keeps restarting the draw, the frames pile up and the app segfaults a few
# seconds after importing a clip -- which is why the crash looked so random.
# PATHMAP_REVERSE=0 is set below, in .env, to turn that reverse mapping off.
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

# pathmap virtualizes the paths it hands back (its "reverse mapping") by default,
# including what realpath()/canonicalize_file_name() return. glycin canonicalizes
# the image path before opening it, so it got a corrupted path and failed to load
# every single image -- gdk-pixbuf returns an error, pitivi raises it from
# inside GtkWidget.do_draw(), Gtk re-runs the draw in a loop and the app
# segfaults. Disabling the reverse mapping fixes it; see the comment above
# PATH_MAPPING for the details. This has to go through .env because pathmap is
# preloaded by sharun at runtime, after this script is done.
echo 'PATHMAP_REVERSE=0' >> ./AppDir/.env

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
