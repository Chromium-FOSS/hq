#!/bin/bash

## This script also uses a couple of tricks from
## Bromite build script for F-Droid
## by csagan5
## and separate contributions by csagan5

if [ ! $# -eq 3 ]; then
    echo "Usage: build.sh version-code arch ninja-target"
    exit 1
fi

VER_CODE="$1"
ARCH="$2"
NINJA_TARGET="$3"
## You can get a list of all of the other build targets from GN by running "gn ls out/Default"


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

## stop at first error
set -e

## use bundled depot tools
export PATH="$PATH:$PWD/third_party/depot_tools"

##### rebuild prebuilts
## download NodeJS
if [ ! -f third_party/node/linux/node-linux-x64.tar.gz ]; then
    echo "Need to download NodeJS"
	third_party/node/update_node_binaries
	third_party/node/update_npm_deps
fi
## download mavencentral jars
mkdir -p third_party/guava/lib/
wget https://repo1.maven.org/maven2/com/google/guava/guava/23.0-android/guava-23.0-android.jar -O third_party/guava/lib/guava-android.jar
wget https://repo1.maven.org/maven2/com/google/guava/guava/23.0/guava-23.0.jar -O third_party/guava/lib/guava.jar

mkdir -p third_party/errorprone/lib/
wget https://repo1.maven.org/maven2/com/google/errorprone/error_prone_ant/2.2.0/error_prone_ant-2.2.0.jar -O third_party/errorprone/lib/error_prone_ant-2.2.0.jar

mkdir -p third_party/ow2_asm/lib/
wget https://repo1.maven.org/maven2/org/ow2/asm/asm-analysis/5.0.1/asm-analysis-5.0.1.jar -O third_party/ow2_asm/lib/asm-analysis.jar
wget https://repo1.maven.org/maven2/org/ow2/asm/asm-commons/5.0.1/asm-commons-5.0.1.jar -O third_party/ow2_asm/lib/asm-commons.jar
wget https://repo1.maven.org/maven2/org/ow2/asm/asm-tree/5.0.1/asm-tree-5.0.1.jar -O third_party/ow2_asm/lib/asm-tree.jar
wget https://repo1.maven.org/maven2/org/ow2/asm/asm-util/5.0.1/asm-util-5.0.1.jar -O third_party/ow2_asm/lib/asm-util.jar
wget https://repo1.maven.org/maven2/org/ow2/asm/asm/5.0.1/asm-5.0.1.jar -O third_party/ow2_asm/lib/asm.jar

mkdir -p third_party/proguard/lib/
wget https://repo1.maven.org/maven2/net/sf/proguard/proguard-base/5.2.1/proguard-base-5.2.1.jar -O third_party/proguard/lib/proguard.jar
wget https://repo1.maven.org/maven2/net/sf/proguard/proguard-retrace/5.2.1/proguard-retrace-5.2.1.jar -O third_party/proguard/lib/retrace.jar

mkdir -p third_party/android_support_test_runner/lib
wget https://maven.google.com/com/android/support/test/runner/0.5/runner-0.5.aar -O third_party/android_support_test_runner/lib/rules.aar
## eu-strip
if [ ! -f third_party/eu-strip/bin/eu-strip ]; then
	echo "Building eu-strip"
	cd third_party/eu-strip
	mkdir -p bin
	./build.sh
	cd ../..
	ln -s ../../../eu-strip/bin third_party/pdfium/third_party/eu-strip/bin
	ln -s ../../../third_party/eu-strip/bin v8/third_party/eu-strip/bin
	echo "Finished eu-strip compilation"
fi
## desugar
if [ ! -f third_party/bazel/desugar/Desugar.jar ]; then
	echo "Building Desugar"
	git clone https://github.com/bazelbuild/bazel
	cd bazel
	bazel build //src/tools/android/java/com/google/devtools/build/android/desugar:Desugar_deploy.jar
	mkdir -p ../third_party/bazel/desugar/
	mv bazel-bin/src/tools/android/java/com/google/devtools/build/android/desugar/Desugar_deploy.jar ../third_party/bazel/desugar/Desugar.jar
	cd ..
	cd third_party/bazel/desugar/
	unzip Desugar.jar "com/google/devtools/build/android/desugar/runtime*"
	zip -rD0 Desugar-runtime.jar com
	rm -r com
	cd ../../..
	echo "Finished Desugar compilation"
fi
## gradle-wrapper
if [ ! -f third_party/gradle_wrapper/gradle/wrapper/gradle-wrapper.jar ]; then
	echo "Setting gradle-wrapper"
	mkdir -p third_party/gradle_wrapper
	cd third_party/gradle_wrapper
	echo "task wrapper(type: Wrapper) {gradleVersion = '4.3.1'}" > build.gradle
	gradle wrapper
	cd ../..
	echo "Finished setting up gradle-wrapper"
fi
## Compile GN
if [ ! -f buildtools/linux64/gn ]; then
    echo "Need to compile gn"
	CC=/usr/bin/clang CXX=/usr/bin/clang++ tools/gn/bootstrap/bootstrap.py -s --no-clean
	mkdir -p buildtools/linux64
	mv out/Release/gn buildtools/linux64/gn
	echo "Finished gn compilation"
fi
## android_deps
if [ ! -d third_party/android_deps/repository ]; then
	echo "Need to get android_deps"
	mkdir -p third_party/android_deps
	cd tools/android/roll/android_deps
	./fetch_all.sh
	cd ../../../..
	echo "Got android_deps"
fi
## closure compiler
if [ ! -f third_party/closure_compiler/compiler/compiler.jar ]; then
	echo "Building closure_compiler"
	mkdir -p third_party/closure_compiler/compiler/
	cd third_party/closure_compiler/
	./roll_closure_compiler
	cd ../..
	echo "Finished closure_compiler"	
fi
#####


## Generated vars
RELEASE=$(< CFOSSRELEASE)
## re-use output directory for the intermediate built objects
OUTPUT="out/Release_${ARCH}"

## Build date, with fix for locale
## from base/build_time.cc
# BUILD_DATE is exactly "Mmm DD YYYY HH:MM:SS".
# See //build/write_build_date_header.py. "HH:MM:SS" is normally expected to
# be "05:00:00"
export LC_ALL=en_US.utf-8
BDATE="$(date +'%b %d %Y') 05:00:00"

## read all arguments from file, skip comments
GN_ARGS="$(sed 's~ *#.*$~~' GN_ARGS | grep -v ^$ | tr '\n' ' ')"

## Important step 1/2
gn gen "--args=android_default_version_code=\"${VER_CODE}\" android_default_version_name=\"$RELEASE\" override_build_date=\"$BDATE\" target_cpu=\"$ARCH\" $GN_ARGS" "$OUTPUT"

echo "gn gen is done!"

## concurrency level for ninja
CONC=$(nproc)
let CONC+=1

## Important step 2/2
ninja -j$CONC -C "$OUTPUT" ${NINJA_TARGET}
