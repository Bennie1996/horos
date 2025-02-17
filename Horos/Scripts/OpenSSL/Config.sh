#!/bin/sh

export PATH="$PATH:/opt/local/bin:/opt/local/sbin:/opt/homebrew/bin/"

path="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )/$(basename "${BASH_SOURCE[0]}")"
cd "$TARGET_NAME"; pwd

env=$(env|sort|grep -v 'LLBUILD_BUILD_ID=\|LLBUILD_LANE_ID=\|LLBUILD_TASK_ID=\|Apple_PubSub_Socket_Render=\|DISPLAY=\|SHLVL=\|SSH_AUTH_SOCK=\|SECURITYSESSIONID=')
hash="$(git describe --always --tags --dirty) $(md5 -q "$path")-$(md5 -qs "$env")"

set -e; set -o xtrace

source_dir="$PROJECT_DIR/$TARGET_NAME"
cmake_dir="$TARGET_TEMP_DIR/Config"
install_dir="$TARGET_TEMP_DIR/Install"

mkdir -p "$cmake_dir"; cd "$cmake_dir"
if [ -e Makefile -a -f .cmakehash ] && [ "$(cat '.cmakehash')" = "$hash" ]; then
    exit 0
fi

if [ -e ".cmakeenv" ]; then
echo "Rebuilding.."
cat '.cmakeenv'
echo "$env"
fi


command -v pkg-config >/dev/null 2>&1 || { echo >&2 "error: building $TARGET_NAME requires pkg-config. Please install pkg-config. Aborting."; exit 1; }

mv "$cmake_dir" "$cmake_dir.tmp"
[ -d "$install_dir" ] && mv "$install_dir" "$install_dir.tmp"
rm -Rf "$cmake_dir.tmp" "$install_dir.tmp"
mkdir -p "$cmake_dir"

cd "$cmake_dir"
rsync -a --delete "$source_dir/" .

export CC=clang
export CXX=clang

config_args=( --prefix="$TARGET_TEMP_DIR/Install" --openssldir="$TARGET_TEMP_DIR/Install" -w -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET )
configure_args=( --prefix="$TARGET_TEMP_DIR/Install" --openssldir="$TARGET_TEMP_DIR/Install" -w -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET )
#cfs=($OTHER_CFLAGS)
#cxxfs=($OTHER_CPLUSPLUSFLAGS)

#args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET")
#args+=(-DCMAKE_OSX_ARCHITECTURES="$ARCHS")

if [ "$CONFIGURATION" = 'Debug' ]; then
    config_args+=( -d )
#    args+=('debug-darwin64-x86_64-cc')
#else
#    args+=('darwin64-x86_64-cc')
fi

#cfs+=(-Wno-sometimes-uninitialized)
#cxxfs+=(-Wno-sometimes-uninitialized)

#if [ ! -z "$CLANG_CXX_LIBRARY" ] && [ "$CLANG_CXX_LIBRARY" != 'compiler-default' ]; then
#    cxxfs+=(-stdlib="$CLANG_CXX_LIBRARY")
#fi
#
#if [ ! -z "$CLANG_CXX_LANGUAGE_STANDARD" ]; then
#    cxxfs+=(-std="$CLANG_CXX_LANGUAGE_STANDARD")
#fi

#if [ ${#cfs[@]} -ne 0 ]; then
#    cfss="${cfs[@]}"
#    configure_args+=(-DCMAKE_C_FLAGS="$cfss")
#fi
#if [ ${#cxxfs[@]} -ne 0 ]; then
#    cxxfss="${cxxfs[@]}"
#    configure_args+=(-DCMAKE_CXX_FLAGS="$cxxfss")
#fi

cd "$cmake_dir"
./config "${config_args[@]}"

if [ "$CONFIGURATION" = 'Debug' ]; then
    ./Configure "${configure_args[@]}" debug-darwin64-$ARCHS-cc no-shared no-engine no-tests
else
    ./Configure "${configure_args[@]}" darwin64-$ARCHS-cc no-shared no-engine no-tests
fi

echo "$hash" > "$cmake_dir/.cmakehash"
echo "$env" > "$cmake_dir/.cmakeenv"

exit 0
