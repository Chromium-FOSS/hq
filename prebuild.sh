#!/bin/bash

## define standard Android Tools locations
#export NDK=/opt/ndk-r16b
#export ANDROID_HOME=/opt/android-sdk

## symlink to local NDK/SDK
if [ ! -L third_party/android_ndk ]; then
	## NDK
	ln -s $NDK third_party/android_ndk
	## SDK parts
	ln -s $ANDROID_HOME/tools third_party/android_tools/sdk/tools
	ln -s $ANDROID_HOME/platform-tools third_party/android_tools/sdk/platform-tools
	ln -s $ANDROID_HOME/platforms third_party/android_tools/sdk/platforms
	ln -s $ANDROID_HOME/build-tools third_party/android_tools/sdk/build-tools
fi
