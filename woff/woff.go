package woff

import (
	"bytes"
	"context"
	_ "embed"
	"fmt"
	"slices"
	"sync"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/imports/wasi_snapshot_preview1"
)

//go:generate bash build.sh
//go:embed woff.wasm
var wasm []byte

var (
	compile sync.Once
	runtime wazero.Runtime
	module  wazero.CompiledModule
)

func Compile() {
	compile.Do(func() {
		ctx := context.Background()
		runtime = wazero.NewRuntime(ctx)

		_, err := wasi_snapshot_preview1.Instantiate(ctx, runtime)
		if err != nil {
			panic(fmt.Errorf("woff: failed to instantiate wasi runtime: %w", err))
		}

		module, err = runtime.CompileModule(ctx, wasm)
		if err != nil {
			panic(fmt.Errorf("woff: failed to compile module: %w", err))
		}
	})

}

func Decompress(woff []byte) ([]byte, error) {
	Compile()

	ctx := context.Background()

	instance, err := runtime.InstantiateModule(ctx, module, wazero.NewModuleConfig().WithName(""))
	if err != nil {
		return nil, err
	}
	defer instance.Close(ctx)

	ret, err := instance.ExportedFunction("woff_malloc").Call(ctx, uint64(len(woff)))
	if err != nil {
		return nil, err
	}
	if len(ret) != 1 {
		panic("wtf")
	}
	addr := uint32(ret[0])

	if !instance.Memory().Write(addr, woff) {
		panic("wtf")
	}

	ret, err = instance.ExportedFunction("woff_decompress").Call(ctx, uint64(addr), uint64(len(woff)))
	if err != nil {
		return nil, err
	}
	if len(ret) != 1 {
		panic("wtf")
	}
	addr = uint32(ret[0])

	if addr == 0 {
		return nil, fmt.Errorf("failed to decompress woff")
	}

	sz, ok := instance.Memory().ReadUint32Le(addr)
	if !ok {
		panic("wtf")
	}

	ttf, ok := instance.Memory().Read(addr+4, sz)
	if !ok {
		panic("wtf")
	}
	return slices.Clone(ttf), nil
}

func Is(woff2 []byte) bool {
	return bytes.HasPrefix(woff2, []byte{'w', 'O', 'F', 'F'})
}
