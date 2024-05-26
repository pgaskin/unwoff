// Command unwoff decompresses WOFF/WOFF2 fonts from stdin to stdout.
package main

import (
	"fmt"
	"io"
	"os"

	"github.com/pgaskin/unwoff"
)

func main() {
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	output, err := unwoff.Decompress(input)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	_, err = os.Stdout.Write(output)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}
