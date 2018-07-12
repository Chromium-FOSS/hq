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
## directly using fetch would checkout nacl
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

## gclient stuff
rm .gclient
mv .gclient_entries src/CFOSSlogs/gclient_entries

#############
###CLEANUP###
#############

## kill depot_tools, will use bundled during build
rm -rf depot_tools

##### prebuilts to be symlinked
## kill NDK, upstream r16 should be OK
rm -rf src/third_party/android_ndk
## kill unused SDK
rm -rf src/third_party/android_sdk
## sdk extras
rm -rf src/third_party/android_tools/sdk/extras/android
## kill SDK sources
rm -rf src/third_party/android_tools/sdk/sources
## kill parts of SDK, will use standard
rm -rf src/third_party/android_tools/sdk/tools
rm -rf src/third_party/android_tools/sdk/platform-tools
rm -rf src/third_party/android_tools/sdk/platforms
rm -rf src/third_party/android_tools/sdk/build-tools

##### other prebuilts
## android_deps
rm -rf src/third_party/android_deps/repository
rm src/third_party/android_deps/additional_readme_paths.json
## kill emulator, don't need
rm -rf src/third_party/android_tools/sdk/emulator
## VR SDK
rm -rf src/third_party/gvr-android-sdk
## more GCM stuff
rm -rf src/third_party/cacheinvalidation/src/example-app-build
rm -rf src/third_party/android_tools/sdk/extras/google/gcm
## kill Clang and LLVM prebuilts
rm -rf src/third_party/llvm-build
## gn can be rebuilt
rm -rf src/buildtools/linux64
## binutils
rm -rf src/third_party/binutils
## nodejs to be reassembled 
rm -rf src/third_party/node/linux
rm -rf src/third_party/node/node_modules
rm src/third_party/node/node_modules.tar.gz
## unused blobs
rm -rf src/tools/luci-go
rm -rf src/components/zucchini/testdata
rm -rf src/v8/test/fuzzer/wasm_corpus
rm -rf src/tools/traffic_annotation
rm -rf src/buildtools/android/doclava
rm src/buildtools/android/doclava.tar.gz
## ninja
rm src/third_party/depot_tools/ninja-linux64
rm src/third_party/depot_tools/ninja-linux32
rm src/third_party/depot_tools/ninja-mac
## eu-strip
rm -rf src/third_party/eu-strip/bin
rm -rf src/third_party/pdfium/third_party/eu-strip/bin
rm -rf src/v8/third_party/eu-strip/bin

##### random heavy files and binaries
## fuzzy stuff
rm -rf src/third_party/boringssl/src/fuzz/
rm -rf src/ui/display/util/fuzz_corpus/
rm -rf src/third_party/blink/renderer/platform/text_codec_fuzzer_seed_corpus/
rm -rf src/third_party/blink/renderer/bindings/core/v8/serialization/fuzz_corpus/
rm -rf src/third_party/libwebm/source/webm_parser/fuzzing/corpus/
rm -rf src/net/data/fuzzer_data/
rm -rf src/device/usb/fuzz_corpus/
rm -rf src/device/fido/response_data_fuzzer_corpus/
rm -rf src/components/cbor/cbor_reader_fuzzer_corpus/
rm -rf src/third_party/hunspell/fuzz/
rm -rf src/media/midi/fuzz/corpus/
rm -rf src/services/device/hid/fuzz_corpus/
rm -rf src/third_party/webrtc/test/fuzzers/
rm -rf src/content/test/data/fuzzer_corpus/
rm -rf src/components/cast_channel/fuzz_corpus/
rm src/third_party/skia/resources/invalid_images/ossfuzz6347
## tests
rm -rf src/third_party/blink/manual_tests/
rm -rf src/third_party/elfutils/src/tests/
rm -rf src/net/data/cache_tests/
rm -rf src/components/test/data/
rm -rf src/courgette/testdata/
rm -rf src/third_party/protobuf/src/google/protobuf/testdata/
rm -rf src/third_party/android_protobuf/src/src/google/protobuf/testdata/
rm -rf src/media/test/data/
rm -rf src/extensions/test/data/
rm -rf src/third_party/libphonenumber/dist/java/libphonenumber/test/
rm -rf src/third_party/ffmpeg/tests/
rm -rf src/third_party/protobuf/python/compatibility_tests/
rm -rf src/third_party/libphonenumber/dist/java/geocoder/test/
rm -rf src/third_party/libphonenumber/dist/java/carrier/test/
rm -rf src/third_party/afl/src/testcases/
rm -rf src/third_party/tlslite/tests/
rm -rf src/tools/binary_size/libsupersize/testdata/
rm -rf src/base/test/data/
rm -rf src/content/test/data/
rm -rf src/third_party/breakpad/breakpad/src/processor/testdata/
rm -rf src/third_party/android_platform/bionic/tools/relocation_packer/test_data/
rm -rf src/chrome/test/data/page_cycler/cached_data_dir/
rm -rf src/chrome/test/data/vr/webxr_samples/
rm -rf src/chrome/test/data/diagnostics/user/
rm -rf src/chrome/test/data/safe_browsing/
rm -rf src/chrome/test/data/extensions/api_test/
rm -rf src/chrome/test/data/profiles/profile_with_complex_theme/Default/Extensions/
rm -rf src/chrome/test/data/profiles/sample/
rm -rf src/third_party/catapult/third_party/gsutil/third_party/httplib2/test/
rm -rf src/third_party/junit/src/src/test/resources/junit/tests/runner/
rm -rf src/third_party/webgl/src/sdk/demos/
rm -rf src/chrome/test/data/extensions/api_test/
rm -rf src/chrome/test/data/profiles/profile_with_complex_theme/Default/Extensions/
rm -rf src/chrome/test/data/profiles/sample/
rm -rf src/third_party/catapult/third_party/gsutil/third_party/httplib2/test/
rm -rf src/third_party/junit/src/src/test/resources/junit/tests/runner/
rm -rf src/third_party/webgl/src/sdk/demos/
## kill heavy WebKit stuff
rm -rf src/third_party/WebKit/LayoutTests
rm -rf src/third_party/WebKit/PerformanceTests
## heavy files
rm -rf src/chrome/test/data/vr/webvr_info/samples/media/textures
## more random unused files
rm -rf src/tools/perf/contrib/leak_detection
rm -rf src/third_party/deqp
rm -rf src/ios
rm -rf src/native_client_sdk
rm -rf src/third_party/win_build_output/
rm -rf src/third_party/openh264/src/autotest/performanceTest/ios/
rm -rf src/ppapi/native_client/
rm -rf src/third_party/protobuf/objectivec/
rm -rf src/third_party/libphonenumber/dist/java/geocoder/src/com/google/i18n/phonenumbers/
rm -rf src/third_party/libphonenumber/dist/java/libphonenumber/src/com/google/i18n/phonenumbers/data/
rm -rf src/third_party/libphonenumber/dist/java/carrier/src/com/google/i18n/phonenumbers/carrier/data/
rm -rf src/third_party/breakpad/breakpad/src/client/mac/
rm -rf src/third_party/sfntly/src/cpp/ext/redist/
rm -rf src/tools/binary_size/libsupersize/third_party/gvr-android-sdk/
rm -rf src/third_party/catapult/third_party/vinn/third_party/v8/
rm -rf src/third_party/webrtc/data/rtp_rtcp/
rm -rf src/third_party/skia/platform_tools/android/bin/
rm -rf src/chrome/common/extensions/docs/
rm -rf src/tools/binary_size/libsupersize/third_party/gvr-android-sdk/
rm -rf src/third_party/catapult/third_party/vinn/third_party/v8/
rm -rf src/third_party/webrtc/data/rtp_rtcp/
rm -rf src/third_party/skia/platform_tools/android/bin/
rm -rf src/chrome/common/extensions/docs/
rm -rf src/third_party/breakpad/breakpad/src/client/mac/
rm -rf src/third_party/sfntly/src/cpp/ext/redist/
## kill specific file extensions
find . -iname "*.exe" -exec rm {} \;
find . -iname "*.dll" -exec rm {} \;
find . -iname "*.apk" -exec rm {} \;
find . -iname "*.dylib" -exec rm {} \;
find . -iname "*.so" -exec rm {} \;
find . -iname "*.aar" -exec rm {} \;
find . -iname "*.jar" -exec rm {} \;
## kill gradle files
find . -type f -name gradle-wrapper.jar -exec rm -f {} \;
#find . -type f -name build.gradle -exec rm -f {} \;
rm src/third_party/libaddressinput/src/android/build.gradle
rm src/third_party/robolectric/robolectric/shadows/playservices/build.gradle
## gradle-wrapper
rm -rf src/third_party/gradle_wrapper

## remove unsafe symlinks
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
