package utils

import (
	"crypto/rand"
	"math"
	mathrand "math/rand"
	"sync"
	"time"

	"github.com/oklog/ulid/v2"
)

var (
	entropy     = ulid.Monotonic(mathrand.New(mathrand.NewSource(time.Now().UnixNano())), 0)
	entropyLock sync.Mutex
)

// GenerateULID generates a new ULID string
func GenerateULID() string {
	entropyLock.Lock()
	defer entropyLock.Unlock()
	return ulid.MustNew(ulid.Timestamp(time.Now()), entropy).String()
}

// MustGenerateULID generates a ULID and panics on error (should never happen)
func MustGenerateULID() string {
	return GenerateULID()
}

// GenerateSecureULID generates a cryptographically secure ULID
func GenerateSecureULID() (string, error) {
	id, err := ulid.New(ulid.Timestamp(time.Now()), rand.Reader)
	if err != nil {
		return "", err
	}
	return id.String(), nil
}

// IsValidULID checks if a string is a valid ULID
func IsValidULID(s string) bool {
	if len(s) != 26 {
		return false
	}
	_, err := ulid.Parse(s)
	return err == nil
}

// ULIDTimestamp extracts the timestamp from a ULID string
func ULIDTimestamp(s string) (time.Time, error) {
	id, err := ulid.Parse(s)
	if err != nil {
		return time.Time{}, err
	}
	ms := id.Time()
	return time.Unix(int64(ms/1000), int64(ms%1000)*int64(math.Pow10(6))), nil
}
