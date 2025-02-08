package tests

import (
	"fmt"
	"testing"
)

// https://github.com/leoluz/nvim-dap-go/pull/82
func TestWithSubTests(t *testing.T) {
	t.Run("subtest with function literal", func(t *testing.T) { t.Fail() })
	myFunc := func(t *testing.T) { t.FailNow() }
	t.Run("subtest with identifier", myFunc)
	t.Run("another subtest", func(t *testing.T) {
		fmt.Println("test")
		t.Fail()
	})
}
