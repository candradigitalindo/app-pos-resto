package main

import (
	"fmt"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	pin := "1234"
	
	// Hash in database for admin
	hash1 := "$2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn."
	err1 := bcrypt.CompareHashAndPassword([]byte(hash1), []byte(pin))
	fmt.Printf("Admin hash matches '1234': %v\n", err1 == nil)

	// Hash in database for waiter
	hash2 := "$2a$10$y6H06HDmvJTIRuI0rTYQrOyCvSBfRbPD/gzt.TkZlgL40wQmPKT1q"
	err2 := bcrypt.CompareHashAndPassword([]byte(hash2), []byte(pin))
	fmt.Printf("Waiter hash matches '1234': %v\n", err2 == nil)
	
	// Check what '1234' actually hashes to (it's random salt, so check multiple)
	newHash, _ := bcrypt.GenerateFromPassword([]byte(pin), 10)
	fmt.Printf("New hash for '1234': %s\n", string(newHash))
}
