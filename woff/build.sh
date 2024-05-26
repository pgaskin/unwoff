#!/bin/bash
set -euo pipefail

cd "$(set -e; dirname "$0")"

tmp="$(set -e; mktemp -d)"
trap "rm -rf $tmp" EXIT

cat << 'EOF' > "$tmp/main.c"
#include <stdint.h>
#include <stdlib.h>
#include <woff.h>

__attribute__((visibility("default")))
uint8_t *woff_malloc(const uint32_t len) {
    return (uint8_t*)(malloc(len));
}

__attribute__((visibility("default")))
uint8_t *woff_decompress(const uint8_t *woff, uint32_t woff_len) {
    uint32_t status;

    const uint32_t ttf_len = woffGetDecodedSize(woff, woff_len, &status);
    if (!ttf_len) return NULL;

    uint8_t *out = (uint8_t*)(malloc(ttf_len + sizeof(ttf_len)));
    uint8_t *ttf = out + sizeof(ttf_len);

    uint32_t actual;
    woffDecodeToBuffer(woff, woff_len, ttf, ttf_len, &actual, &status);
    if (WOFF_FAILURE(status)) return NULL;

    *(uint32_t*)(out) = actual;
    return out;
}
EOF

git init "$tmp/woff-tools"
git -C "$tmp/woff-tools" fetch https://github.com/samboy/WOFF dcdc1ed769fb61fb1fdf79c922b93c8c65d3d875
git -C "$tmp/woff-tools" checkout FETCH_HEAD
git init "$tmp/libz"
git -C "$tmp/libz" fetch https://gitlab.com/sortix/libz 752c1630421502d6c837506d810f7918ac8cdd27
git -C "$tmp/libz" checkout FETCH_HEAD

docker run --rm -i -v "$tmp:/src" -w /src -u $(id -u):$(id -g) ghcr.io/webassembly/wasi-sdk:wasi-sdk-22@sha256:a508461a49ebde247a83ae605544896a3ef78d983d7a99544b8dc3c04ff2b211 sh -euxc '

CFLAGS="$CFLAGS -Wall -Oz"
CXXFLAGS="$CXXFLAGS -Wall -Oz -fno-exceptions"

$CC $CFLAGS -c -std=c11 -I./libz -DZ_INSIDE_LIBZ -D_GNU_SOURCE -Wno-incompatible-pointer-types-discards-qualifiers \
 ./libz/adler32.c \
 ./libz/compress.c \
 ./libz/crc32.c \
 ./libz/deflate.c \
 ./libz/gzclose.c \
 ./libz/gzlib.c \
 ./libz/gzread.c \
 ./libz/gzwrite.c \
 ./libz/infback.c \
 ./libz/inffast.c \
 ./libz/inflate.c \
 ./libz/inftrees.c \
 ./libz/trees.c \
 ./libz/uncompr.c \
 ./libz/zutil.c

$CC $CFLAGS -c -std=gnu11 -isystem./libz -Wno-unused-variable ./woff-tools/woff.c

$CC $CFLAGS -c -std=gnu11 -isystem./woff-tools ./main.c
$CC $CXXFLAGS -Wl,--no-entry -Wl,--export-dynamic *.o -nostartfiles -o woff.wasm

'

install "$tmp/woff.wasm" .
