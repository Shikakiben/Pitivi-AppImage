#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q pitivi | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.bg.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/scalable/apps/org.pitivi.Pitivi.svg
export DESKTOP=/usr/share/applications/org.pitivi.Pitivi.desktop
export DEPLOY_SYS_PYTHON=1
export DEPLOY_GTK=1
export DEPLOY_GDK=1
export GTK_DIR=/usr/lib/gtk-4.0
export ANYLINUX_LIB=1
export PATH_MAPPING='
  /usr/lib/pitivi: ${SHARUN_DIR}/lib/pitivi
  /usr/share/pitivi:${SHARUN_DIR}/share/pitivi
'

# Deploy dependencies
quick-sharun \
      /usr/bin/pitivi \
      /usr/lib/pitivi/python/pitivi \
      /usr/lib/libpeas-1.0.so* \
      /usr/lib/girepository-1.0 \
      /usr/lib/libgmodule-2.0.so*
      
#echo 'GI_TYPELIB_PATH=${SHARUN_DIR}/shared/lib/girepository-1.0' >> ./AppDir/.env

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage
