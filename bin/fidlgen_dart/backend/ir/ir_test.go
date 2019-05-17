// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package ir

import (
	"testing"

	"fidl/compiler/backend/types"
)

func makeLiteralConstant(value string) types.Constant {
	return types.Constant{
		Kind: types.LiteralConstant,
		Literal: types.Literal{
			Kind:  types.NumericLiteral,
			Value: value,
		},
	}
}

func TestCompileConstant(t *testing.T) {
	var c compiler
	cases := []struct {
		input    types.Constant
		expected string
	}{
		{
			input:    makeLiteralConstant("10"),
			expected: "0xa",
		},
		{
			input:    makeLiteralConstant("-1"),
			expected: "-1",
		},
		{
			input:    makeLiteralConstant("0xA"),
			expected: "0xA",
		},
		{
			input:    makeLiteralConstant("1.23"),
			expected: "1.23",
		},
	}
	for _, ex := range cases {
		actual := c.compileConstant(ex.input, nil)
		if ex.expected != actual {
			t.Errorf("%v: expected %s, actual %s", ex.input, ex.expected, actual)
		}
	}
}
