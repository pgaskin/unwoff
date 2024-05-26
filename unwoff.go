// Package unwoff decompresses WOFF/WOFF2 fonts.
package unwoff

import (
	"errors"

	"github.com/pgaskin/unwoff/woff"
	"github.com/pgaskin/unwoff/woff2"
)

// ErrNotWOFF is returned if the font is not a WOFF/WOFF2.
var ErrNotWOFF = errors.New("not a WOFF/WOFF2 font")

// Decompress attempts to decompress the provided WOFF/WOFF2 font.
func Decompress(font []byte) ([]byte, error) {
	switch {
	case woff.Is(font):
		return woff.Decompress(font)
	case woff2.Is(font):
		return woff2.Decompress(font)
	default:
		return nil, ErrNotWOFF
	}
}
