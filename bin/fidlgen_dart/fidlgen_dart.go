package main

import (
	"fidl/compiler/backend/cmdline"
	"fidlgen_dart/backend"
	"flag"
	"log"
	"os"
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

	err := backend.GenerateFidl(fidl, &config, *dartfmt)
	if err != nil {
		log.Fatalf("Error running generator: %v", err)
	}
}
