// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package main

import (
	"flag"
	"log"
	"os"

	"fidl/compiler/backend/cmdline"
	"fidlgen_dart/backend"
)

func main() {
	flags := cmdline.BaseFlags()
	dartfmt := flag.String("dartfmt", "", "path to the dartfmt tool")
	flag.Parse()
	if !flag.Parsed() || !flags.Valid() {
		flag.PrintDefaults()
		os.Exit(1)
	}
	fidl := flags.FidlTypes()
	config := flags.Config()

	err := backend.NewFidlGenerator().GenerateBindings(fidl, &config, *dartfmt)
	if err != nil {
		log.Fatalf("Error running generator: %v", err)
	}
}
