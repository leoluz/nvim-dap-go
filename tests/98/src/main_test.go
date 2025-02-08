package main

import (
	"testing"

	"github.com/stretchr/testify/suite"
)

type SomeTestSuite struct {
	suite.Suite
}

func TestSuite(t *testing.T) {
	suite.Run(t, new(SomeTestSuite))
}

// func (st *SomeTestSuite) TestSomething() {
// 	st.Run("some test here", func() {
// 		st.Equal(2, 1)
// 	})
//
// 	st.Run("another test here", func() {
// 		st.Equal(3, 2)
// 	})
// }
