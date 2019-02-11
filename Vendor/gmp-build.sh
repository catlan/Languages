#!/bin/bash

# This script downloads and builds Mac libgmp library

# Credits:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# https://gist.github.com/foozmeat/5154962
# Peter Steinberger, PSPDFKit GmbH, @steipete.
# Felix Schwarz, IOSPIRIT GmbH, @felix_schwarz.

set -e

usage ()
{
	echo "usage: $0 [iOS SDK version (defaults to latest)] [tvOS SDK version (defaults to latest)] [OS X minimum deployment target (defaults to 10.7)]"
	exit 127
}

if [ $1 -e "-h" ]; then
	usage
fi

if [ -z $1 ]; then
	IOS_SDK_VERSION="" #"9.1"
	IOS_MIN_SDK_VERSION="8.0"
	
	TVOS_SDK_VERSION="" #"9.0"
	TVOS_MIN_SDK_VERSION="9.0"
	
	OSX_DEPLOYMENT_TARGET="10.7"
else
	IOS_SDK_VERSION=$1
	TVOS_SDK_VERSION=$2
	OSX_DEPLOYMENT_TARGET=$3
fi

GMP_VERSION="gmp-6.1.2"
DEVELOPER=`xcode-select -print-path`

buildMac()
{
	ARCH=$1

	echo "Building ${GMP_VERSION} for ${ARCH}"

	TARGET="i386"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="x86_64"
	fi

	export CC="${BUILD_TOOLS}/usr/bin/gcc -mmacosx-version-min=${OSX_DEPLOYMENT_TARGET}"

	pushd . > /dev/null
	cd "${GMP_VERSION}"
	./configure --prefix="/tmp/${GMP_VERSION}-${ARCH}" &> "/tmp/${GMP_VERSION}-${ARCH}.log"
	make >> "/tmp/${GMP_VERSION}-${ARCH}.log" 2>&1
	make check >> "/tmp/${GMP_VERSION}-${ARCH}.log" 2>&1
	make install >> "/tmp/${GMP_VERSION}-${ARCH}.log" 2>&1
	make clean >> "/tmp/${GMP_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null
}

mkdir -p usr/lib
mkdir -p usr/include

rm -rf "/tmp/${GMP_VERSION}-*"
rm -rf "/tmp/${GMP_VERSION}-*.log"

rm -rf "${GMP_VERSION}"

if [ ! -e ${GMP_VERSION}.tar.bz2 ]; then
	echo "Downloading ${GMP_VERSION}.tar.bz2"
	curl -O https://gmplib.org/download/gmp/${GMP_VERSION}.tar.bz2
else
	echo "Using ${GMP_VERSION}.tar.bz2"
fi

echo "Unpacking gmp"
tar xfz "${GMP_VERSION}.tar.bz2"

buildMac "x86_64"

echo "Copying headers"
cp /tmp/${GMP_VERSION}-x86_64/include/* usr/include/

echo "Building Mac libraries"
lipo \
	"/tmp/${GMP_VERSION}-x86_64/lib/libgmp.a" \
	-create -output usr/lib/libgmp_Mac.a
cp -L "/tmp/${GMP_VERSION}-x86_64/lib/libgmp.dylib" usr/lib/libgmp_Mac.dylib
install_name_tool -id "@rpath/libgmp_Mac.dylib" usr/lib/libgmp_Mac.dylib

echo "Cleaning up"
rm -rf /tmp/${GMP_VERSION}-*
rm -rf ${GMP_VERSION}

echo "Done"