package common

import (
	"fmt"
	"github.com/stretchr/testify/assert"
	"strconv"
	"testing"
)

func TestGetAnswerMap(t *testing.T) {
	hello := GetHelloList()[1]
	ans := GetAnswerMap()[hello]
	assert.Equal(t, "Merci beaucoup", ans)
	println(ans)
}

func TestRand(t *testing.T) {
	id := RandomId(5)
	index, _ := strconv.Atoi(id)
	fmt.Printf("%s,%d", id, index)
}
