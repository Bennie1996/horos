#!/bin/sh

export PATH="$PATH:/opt/local/bin:/opt/local/sbin:/opt/homebrew/bin/"

path="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )/$(basename "${BASH_SOURCE[0]}")"
cd "$TARGET_NAME"; pwd

env=$(env|sort|grep -v 'LLBUILD_BUILD_ID=\|LLBUILD_LANE_ID=\|LLBUILD_TASK_ID=\|Apple_PubSub_Socket_Render=\|DISPLAY=\|SHLVL=\|SSH_AUTH_SOCK=\|SECURITYSESSIONID=')
hash="$(git describe --always --tags --dirty) $(md5 -q "$path")-$(md5 -qs "$env")"

set -e; set -o xtrace

source_dir="$PROJECT_DIR/$TARGET_NAME"
cmake_dir="$TARGET_TEMP_DIR/CMake"
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

command -v cmake >/dev/null 2>&1 || { echo >&2 "error: building $TARGET_NAME requires CMake. Please install CMake. Aborting."; exit 1; }
command -v pkg-config >/dev/null 2>&1 || { echo >&2 "error: building $TARGET_NAME requires pkg-config. Please install pkg-config. Aborting."; exit 1; }

mv "$cmake_dir" "$cmake_dir.tmp"
[ -d "$install_dir" ] && mv "$install_dir" "$install_dir.tmp"
rm -Rf "$cmake_dir.tmp" "$install_dir.tmp"
mkdir -p "$cmake_dir"

export CC=clang
export CXX=clang

args=("$source_dir")
cfs=($OTHER_CFLAGS)
cxxfs=($OTHER_CPLUSPLUSFLAGS)
ldfs=($OTHER_LDFLAGS)

args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET")
args+=(-DCMAKE_OSX_ARCHITECTURES="$ARCHS")

args+=(-DCMAKE_INSTALL_PREFIX="$TARGET_TEMP_DIR/Install")
args+=(-DGROK_INSTALL_INCLUDE_DIR="include/OpenJPEG")
args+=(-DGROK_INSTALL_LIB_DIR="lib")

args+=(-DBUILD_CODEC=ON)
args+=(-DBUILD_PLUGIN_LOADER=OFF)
args+=(-DBUILD_DOC=OFF)
args+=(-DBUILD_EXAMPLES=OFF)
args+=(-DBUILD_SHARED_LIBS=OFF)
args+=(-DBUILD_STATIC_LIBS=ON)
args+=(-DBUILD_TESTING=OFF)

args+=(-DCMAKE_IGNORE_PATH="/opt/local/include;/opt/local/lib")

if [ "$CONFIGURATION" = 'Debug' ]; then
    cxxfs+=( -g )
else
    cxxfs+=( -O2 )
fi

if [ ! -z "$CLANG_CXX_LIBRARY" ] && [ "$CLANG_CXX_LIBRARY" != 'compiler-default' ]; then
    cxxfs+=(-stdlib="$CLANG_CXX_LIBRARY")
    ldfs+=(-lc++)
fi

if [ ! -z "$CLANG_CXX_LANGUAGE_STANDARD" ]; then
    cxxfs+=(-std="$CLANG_CXX_LANGUAGE_STANDARD")
fi

if [ ${#cfs[@]} -ne 0 ]; then
    cfss="${cfs[@]}"
    args+=(-DCMAKE_C_FLAGS="$cfss")
fi
if [ ${#cxxfs[@]} -ne 0 ]; then
    cxxfss="${cxxfs[@]}"
    args+=(-DCMAKE_CXX_FLAGS="$cxxfss")
fi
if [ ${#ldfs[@]} -ne 0 ]; then
    ldfs="${ldfs[@]}"
    args+=(-DCMAKE_SHARED_LINKER_FLAGS="$ldfs")
    args+=(-DCMAKE_EXE_LINKER_FLAGS="$ldfs")
fi

cd "$cmake_dir"
cmake "${args[@]}"

echo "$hash" > "$cmake_dir/.cmakehash"
echo "$env" > "$cmake_dir/.cmakeenv"

exit 0

