#!/bin/bash
# Cross-compile dependencies for Nintendo Switch (kys-cpp)
# Usage: bash tools/switch/setup_switch_deps.sh
set -e

DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
DEVKITA64="$DEVKITPRO/devkitA64"
# Use local prefix if portlibs is not writable
if [ -w "$DEVKITPRO/portlibs/switch/lib" ]; then
    PREFIX="$DEVKITPRO/portlibs/switch"
else
    PREFIX="$(cd "$(dirname "$0")/../.." && pwd)/local/switch"
    mkdir -p "$PREFIX/lib" "$PREFIX/include"
    echo "NOTE: portlibs not writable, installing to $PREFIX"
fi
BUILDDIR="$(pwd)/build-switch-deps"

CC="$DEVKITA64/bin/aarch64-none-elf-gcc"
CXX="$DEVKITA64/bin/aarch64-none-elf-g++"
AR="$DEVKITA64/bin/aarch64-none-elf-ar"
RANLIB="$DEVKITA64/bin/aarch64-none-elf-ranlib"

COMMON_CFLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE -I$PREFIX/include -I$DEVKITPRO/libnx/include"

mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

echo "=== Building Lua 5.4 ==="
if [ ! -f "$PREFIX/lib/liblua.a" ]; then
    LUA_VER="5.4.7"
    if [ ! -d "lua-$LUA_VER" ]; then
        curl -L "https://www.lua.org/ftp/lua-$LUA_VER.tar.gz" | tar xz
    fi
    cd "lua-$LUA_VER"
    make clean 2>/dev/null || true
    make generic \
        CC="$CC" \
        AR="$AR rcu" \
        RANLIB="$RANLIB" \
        MYCFLAGS="$COMMON_CFLAGS" \
        MYLDFLAGS="" \
        -j$(sysctl -n hw.ncpu 2>/dev/null || nproc)
    cp src/liblua.a "$PREFIX/lib/"
    cp src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp "$PREFIX/include/"
    cd ..
    echo "Lua 5.4 installed."
else
    echo "Lua 5.4 already installed, skipping."
fi

echo "=== Building sqlite3 ==="
if [ ! -f "$PREFIX/lib/libsqlite3.a" ]; then
    SQLITE_VER="3490100"
    if [ ! -d "sqlite-amalgamation-$SQLITE_VER" ]; then
        curl -L "https://www.sqlite.org/2025/sqlite-amalgamation-$SQLITE_VER.zip" -o sqlite.zip
        unzip -o sqlite.zip
        rm sqlite.zip
    fi
    cd "sqlite-amalgamation-$SQLITE_VER"
    # Create shim for missing POSIX functions (fchown, geteuid)
    cat > switch_shim.c << 'SHIM_EOF'
#include <sys/types.h>
int fchown(int fd, uid_t owner, gid_t group) { (void)fd; (void)owner; (void)group; return 0; }
uid_t geteuid(void) { return 0; }
SHIM_EOF
    $CC $COMMON_CFLAGS -O2 -DSQLITE_OS_UNIX \
        -DSQLITE_OMIT_WAL -DSQLITE_OMIT_LOAD_EXTENSION \
        -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_POSIX_FALLOCATE \
        -c sqlite3.c -o sqlite3.o
    $CC $COMMON_CFLAGS -O2 -c switch_shim.c -o switch_shim.o
    $AR rcu libsqlite3.a sqlite3.o switch_shim.o
    $RANLIB libsqlite3.a
    cp libsqlite3.a "$PREFIX/lib/"
    cp sqlite3.h sqlite3ext.h "$PREFIX/include/"
    cd ..
    echo "sqlite3 installed."
else
    echo "sqlite3 already installed, skipping."
fi

echo "=== Building yaml-cpp ==="
if [ ! -f "$PREFIX/lib/libyaml-cpp.a" ]; then
    YAMLCPP_VER="0.8.0"
    if [ ! -d "yaml-cpp-$YAMLCPP_VER" ]; then
        curl -L "https://github.com/jbeder/yaml-cpp/archive/refs/tags/$YAMLCPP_VER.tar.gz" | tar xz
    fi
    mkdir -p "yaml-cpp-$YAMLCPP_VER/build-switch"
    cd "yaml-cpp-$YAMLCPP_VER/build-switch"
    cmake .. \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_SYSTEM_NAME=Generic \
        -DCMAKE_C_COMPILER="$CC" \
        -DCMAKE_CXX_COMPILER="$CXX" \
        -DCMAKE_AR="$AR" \
        -DCMAKE_RANLIB="$RANLIB" \
        -DCMAKE_C_FLAGS="$COMMON_CFLAGS" \
        -DCMAKE_CXX_FLAGS="$COMMON_CFLAGS -std=c++17" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DYAML_CPP_BUILD_TOOLS=OFF \
        -DYAML_CPP_BUILD_TESTS=OFF \
        -DYAML_CPP_BUILD_CONTRIB=OFF \
        -DBUILD_SHARED_LIBS=OFF
    make -j$(sysctl -n hw.ncpu 2>/dev/null || nproc)
    make install
    cd ../..
    echo "yaml-cpp installed."
else
    echo "yaml-cpp already installed, skipping."
fi

echo "=== Building libiconv ==="
if [ ! -f "$PREFIX/lib/libiconv.a" ]; then
    ICONV_VER="1.17"
    if [ ! -d "libiconv-$ICONV_VER" ]; then
        curl -L "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-$ICONV_VER.tar.gz" | tar xz
    fi
    cd "libiconv-$ICONV_VER"
    # Patch K&R mbrtowc declaration that conflicts with newlib
    if [ -f lib/loop_wchar.h ]; then
        sed -i.bak 's/  extern size_t mbrtowc ();/  \/\/ extern size_t mbrtowc (); \/\/ patched for newlib/' lib/loop_wchar.h 2>/dev/null || true
    fi
    # Try configure first
    ./configure \
        --host=aarch64-none-elf \
        --prefix="$PREFIX" \
        --enable-static \
        --disable-shared \
        CC="$CC" \
        CFLAGS="$COMMON_CFLAGS -O2" \
        --disable-nls \
        2>/dev/null || {
        echo "configure failed, trying manual build..."
        # Manual fallback: compile the core iconv library
        cd lib
        $CC $COMMON_CFLAGS -O2 -I../include -I. -I../srclib \
            -DLIBDIR=\"\" -DBUILDING_LIBICONV \
            -c iconv.c -o iconv.o 2>/dev/null || true
        cd ..
    }
    if [ -f Makefile ]; then
        make -j$(sysctl -n hw.ncpu 2>/dev/null || nproc) 2>/dev/null || true
        make install 2>/dev/null || true
    fi
    # Verify installation
    if [ ! -f "$PREFIX/lib/libiconv.a" ]; then
        echo "WARNING: libiconv build failed. You may need to build it manually."
    else
        echo "libiconv installed."
    fi
    cd ..
else
    echo "libiconv already installed, skipping."
fi

echo ""
echo "=== All dependencies built ==="
echo "Installed to: $PREFIX"
ls -la "$PREFIX/lib/liblua.a" "$PREFIX/lib/libsqlite3.a" "$PREFIX/lib/libyaml-cpp.a" "$PREFIX/lib/libiconv.a" 2>/dev/null || true
