#!/bin/bash
set -euo pipefail

cd "$(set -e; dirname "$0")"

tmp="$(set -e; mktemp -d)"
trap "rm -rf $tmp" EXIT

cat << 'EOF' > "$tmp/main.cc"
#include <woff2/decode.h>

__attribute__((visibility("default")))
extern "C" uint8_t *woff2_malloc(const uint32_t len) {
    return static_cast<uint8_t*>(operator new(len));
}

__attribute__((visibility("default")))
extern "C" uint8_t *woff2_decompress(const uint8_t *woff, uint32_t woff_len) {
    const uint32_t ttf_len = woff2::ComputeWOFF2FinalSize(woff, woff_len);
    if (!ttf_len) return nullptr;

    uint8_t *out = static_cast<uint8_t*>(operator new(ttf_len + sizeof(ttf_len)));
    uint8_t *ttf = out + sizeof(ttf_len);
    *reinterpret_cast<uint32_t*>(out) = ttf_len;

    woff2::WOFF2MemoryOut ttf_out(ttf, ttf_len);
    return woff2::ConvertWOFF2ToTTF(woff, woff_len, &ttf_out) ? out : nullptr;
}
EOF

git init "$tmp/woff2"
git -C "$tmp/woff2" fetch https://github.com/google/woff2 0f4d304faa1c62994536dc73510305c7357da8d4
git -C "$tmp/woff2" checkout FETCH_HEAD
git -C "$tmp/woff2" submodule update --init "$tmp/woff2/brotli"

docker run --rm -i -v "$tmp:/src" -w /src -u $(id -u):$(id -g) ghcr.io/webassembly/wasi-sdk:wasi-sdk-22@sha256:a508461a49ebde247a83ae605544896a3ef78d983d7a99544b8dc3c04ff2b211 sh -euxc '

CFLAGS="$CFLAGS -Wall -Oz"
CXXFLAGS="$CXXFLAGS -Wall -Oz -fno-exceptions"

$CC $CFLAGS -c -std=c11 -I./woff2/brotli/c/include \
 ./woff2/brotli/c/common/dictionary.c \
 ./woff2/brotli/c/common/transform.c \
 ./woff2/brotli/c/dec/bit_reader.c \
 ./woff2/brotli/c/dec/decode.c \
 ./woff2/brotli/c/dec/huffman.c \
 ./woff2/brotli/c/dec/state.c

$CXX $CXXFLAGS -c -std=c++11 -isystem./woff2/brotli/c/include -I./woff2/include -Wno-unused-variable -Wno-unused-const-variable \
 ./woff2/src/table_tags.cc \
 ./woff2/src/variable_length.cc \
 ./woff2/src/woff2_common.cc \
 ./woff2/src/woff2_dec.cc \
 ./woff2/src/woff2_out.cc

$CXX $CXXFLAGS -c -std=c++11 -isystem./woff2/brotli/c/include -isystem./woff2/include ./main.cc
$CXX $CXXFLAGS -Wl,--no-entry -Wl,--export-dynamic *.o -nostartfiles -o woff2.wasm

'

install "$tmp/woff2.wasm" .
