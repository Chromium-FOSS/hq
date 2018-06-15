#!/bin/bash

## some predefined stuff for now
VER_CODE="42"
ARCH="arm64"
## You can get a list of all of the other build targets from GN by running "gn ls out/Default"
NINJA_TARGET="chrome_modern_public_apk"

## define standard Android Tools locations
export ANDROID_NDK=/opt/ndk-r16b
export NDK=$ANDROID_NDK
#export ANDROID_HOME=/opt/android-sdk


## Generated vars
RELEASE=$(cat src/CFOSSRELEASE)
OUTPUT="out/Release_${RELEASE}_${ARCH}"

## replace NDK with local one
ln -s $NDK src/third_party/android_ndk

## their tools require python 2
## use virtualenv to provide it
ret=`python -c 'import sys; print("%i" % (sys.hexversion<0x03000000))'`
if [ $ret -eq 0 ]; then
    echo "we require python version <3"
	virtualenv2 venv
	source venv/bin/activate
else 
    echo "python version is <3"
fi

## it may be possible to use bundled
#DEPOT_TOOLS="$PWD/src/third_party/depot_tools"
export PATH="$PATH:`pwd`/depot_tools"

## create output directory
mkdir -p "$OUTPUT"
if [ -e src/out ]; then
        rm -rf src/out
fi
ln -s "$PWD/out" src/out

## Build date, with fix for locale
## from base/build_time.cc
# BUILD_DATE is exactly "Mmm DD YYYY HH:MM:SS".
# See //build/write_build_date_header.py. "HH:MM:SS" is normally expected to
# be "05:00:00"
export LC_ALL=en_US.utf-8
BDATE="$(date +'%b %d %Y') 05:00:00"

## read all arguments from file, skip comments
GN_ARGS="$(sed 's~ *#.*$~~' GN_ARGS | grep -v ^$ | tr '\n' ' ')"

cd src

## It's possible to compile GN like that
#tools/gn/bootstrap/bootstrap.py -s --no-clean
## Then just use it
#out/Release/gn
## or even better, move it to src/buildtools/linux64/gn
## gets automatically found there

## Important step 1/2
gn gen "--args=android_default_version_code=\"${VER_CODE}\" android_default_version_name=\"$RELEASE\" override_build_date=\"$BDATE\" target_cpu=\"$ARCH\" $GN_ARGS" "$OUTPUT"

echo "gn gen is done!"

## concurrency level for ninja
CONC=$(nproc)
let CONC+=1

## Important step 2/2
ninja -j$CONC -C "$OUTPUT" ${NINJA_TARGET}
