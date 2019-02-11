#!/bin/bash

# This script downloads and builds Mac libffi library

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

VERSION="3.2.1"
LIBFFI="libffi-${VERSION}"
DEVELOPER=`xcode-select -print-path`

buildMac()
{
	ARCH=$1

	echo "Building ${LIBFFI} for ${ARCH}"

	TARGET="i386"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="x86_64"
	fi

	export CC="${BUILD_TOOLS}/usr/bin/clang -mmacosx-version-min=${OSX_DEPLOYMENT_TARGET}"

	pushd . > /dev/null
	cd "${LIBFFI}"
	./configure --prefix="/tmp/${LIBFFI}-${ARCH}" &> "/tmp/${LIBFFI}-${ARCH}.log"
	make >> "/tmp/${LIBFFI}-${ARCH}.log" 2>&1
	make install >> "/tmp/${LIBFFI}-${ARCH}.log" 2>&1
	make clean >> "/tmp/${LIBFFI}-${ARCH}.log" 2>&1
	popd > /dev/null
}

mkdir -p usr/lib
mkdir -p usr/include

rm -rf "/tmp/${LIBFFI}-*"
rm -rf "/tmp/${LIBFFI}-*.log"

rm -rf "${LIBFFI}"

if [ ! -e ${LIBFFI}.tar.gz ]; then
	echo "Downloading ${LIBFFI}.tar.gz"
	curl -O ftp://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz
else
	echo "Using ${LIBFFI}.tar.gz"
fi

echo "Unpacking libffi"
tar xfz "${LIBFFI}.tar.gz"

buildMac "x86_64"

echo "Copying headers"
cp /tmp/${LIBFFI}-x86_64/lib/${LIBFFI}/include/* usr/include/

echo "Building Mac libraries"
lipo \
	"/tmp/${LIBFFI}-x86_64/lib/libffi.a" \
	-create -output usr/lib/libffi_Mac.a
cp -L "/tmp/${LIBFFI}-x86_64/lib/libffi.dylib" usr/lib/libffi_Mac.dylib
install_name_tool -id "@rpath/libffi_Mac.dylib" usr/lib/libffi_Mac.dylib

echo "Cleaning up"
rm -rf /tmp/${LIBFFI}-*
rm -rf ${LIBFFI}

echo "Done"