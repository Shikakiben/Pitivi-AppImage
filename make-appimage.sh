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
export PATH_MAPPING='
  /usr/lib/pitivi: ${SHARUN_DIR}/lib/pitivi
  /usr/share/pitivi:${SHARUN_DIR}/share/pitivi
'

# Deploy dependencies
quick-sharun \
      /usr/bin/pitivi
      #/usr/lib/pitivi/python/pitivi*

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage
