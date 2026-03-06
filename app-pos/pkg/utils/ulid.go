package utils

import (
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


