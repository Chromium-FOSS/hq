#!/bin/bash

## get the tags from
## https://omahaproxy.appspot.com/
RELEASE="67.0.3396.87"

mkdir chromium && cd chromium

## get their dev tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PATH:`pwd`/depot_tools"

## their tools require python 2
## use virtualenv to provide it
ret=`python -c 'import sys; print("%i" % (sys.hexversion<0x03000000))'`
if [ $ret -eq 0 ]; then
    echo "We require python version <3"
	virtualenv2 venv
	source venv/bin/activate
else 
    echo "Python version is <3"
fi

## checkout source
## directly using fetch would checkout nacl, which we don't really need
## maybe also "'checkout_libaom': False,"
## To see what fetch does, run it with "-n"
## original command
# fetch --nohooks android --target_os_only=true
gclient root
cat >.gclient <<EOL
solutions = [
  {
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "managed": False,
    "name": "src",
    "custom_deps": {},
    "custom_vars": {
      'checkout_nacl': False
    },
  },
]
target_os = ["android"]
target_os_only = "true"
EOL
gclient sync --nohooks > sync.log
mkdir -p src/CFOSSlogs
mv sync.log src/CFOSSlogs/
cd src
git submodule foreach 'git config -f $toplevel/.git/config submodule.$name.ignore all'
git config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'
git config diff.ignoreSubmodules all

## get the required release tag
gclient sync --nohooks --with_branch_heads -r $RELEASE --jobs 32 > CFOSSlogs/sync_release.log

## should run `build/install-build-deps-android.sh`, if on supported ubuntu or debian
## they say Arch equivalent for the Linux analogue of `build/install-build-deps.sh` is
# sudo pacman -S --needed python perl gcc gcc-libs bison flex gperf pkgconfig nss alsa-lib glib2 gtk2 nspr ttf-ms-fonts freetype2 cairo dbus libgnome-keyring
## (fails because ttf-ms-fonts is not in repo, but in AUR)
## but there are more deps in the currently needed `build/install-build-deps-android.sh`
## so possibly also
# sudo pacman -S --needed bsdiff python-pexpect xorg-server-xvfb lighttpd

## runhooks
## have to accept the play services license?
## Do you accept the license for version 11.2.0 of the Google Play services client library? [y/n]:
echo n | gclient runhooks > CFOSSlogs/runhooks.log

## for some reason, libsync is not checked out
git clone https://chromium.googlesource.com/aosp/platform/system/core/libsync.git third_party/libsync/src

## save release version
echo "$RELEASE" > CFOSSRELEASE

## up to chromium
cd ..

#############
###CLEANUP###
#############

## kill depot_tools, will use bundled during build
rm -rf depot_tools

## gclient stuff
rm .gclient
mv .gclient_entries src/CFOSSlogs/gclient_entries

## kill NDK, upstream r16 should be OK
rm -rf src/third_party/android_ndk
## kill parts of SDK, will use standard
rm -rf src/third_party/android_sdk/public/tools
rm -rf src/third_party/android_sdk/public/platform-tools
rm -rf src/third_party/android_sdk/public/platforms
rm -rf src/third_party/android_sdk/public/build-tools
## one more SDK(?!)
rm -rf src/third_party/android_tools/sdk/tools
rm -rf src/third_party/android_tools/sdk/platform-tools
rm -rf src/third_party/android_tools/sdk/platforms
rm -rf src/third_party/android_tools/sdk/build-tools
## kill SDK sources
rm -rf src/third_party/android_tools/sdk/sources
## kill emulator, don't need
rm -rf src/third_party/android_sdk/public/emulator
rm -rf src/third_party/android_tools/sdk/emulator
## kill heavy WebKit stuff
rm -rf src/third_party/WebKit/LayoutTests
rm -rf src/third_party/WebKit/PerformanceTests
## heavy files
rm -rf src/chrome/test/data/vr/webvr_info/samples/media/textures
## VR SDK
rm -rf src/third_party/gvr-android-sdk

# remove unsafe symlinks
rm -f src/third_party/mesa/src/src/gallium/state_trackers/d3d1x/w32api

## remove git files
find -name .git | xargs rm -rf
## and gitignore
find . -type f -name .gitignore -exec rm -f {} \;

## can't immediately remove cipd files, they are symlinked all over the src
## @nvasya solution
find -type l -print0 | while IFS= read -r -d $'\0' symlink; do
  REAL=$(realpath -- "$symlink")
  if ! test "$REAL" = "${REAL/\.cipd/}"; then
    rm -- "$symlink"
    cp -alr -- "$REAL" "$symlink"  # warning! hardlinking.
  fi
done
rm -rf .cipd


## rm out dir
rm -rf src/out

## pack
cd ..
tar cfJ chromium-$RELEASE.tar.xz chromium/
