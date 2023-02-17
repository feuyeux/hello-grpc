package main

import (
	"math/rand"
	"testing"
	"time"
)

func TestRand(t *testing.T) {
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	n := r.Intn(10)
	println(n)
}
