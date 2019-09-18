// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package backend

import (
	"io"
	"os"
	"path/filepath"
	"text/template"

	"fidl/compiler/backend/types"
	"fidlgen_dart/backend/ir"
	"fidlgen_dart/backend/templates"
)

type FidlGenerator struct {
	tmpls *template.Template
}

func NewFidlGenerator() *FidlGenerator {
	tmpls := template.New("DartTemplates")
	template.Must(tmpls.Parse(templates.Bits))
	template.Must(tmpls.Parse(templates.Const))
	template.Must(tmpls.Parse(templates.Enum))
	template.Must(tmpls.Parse(templates.Interface))
	template.Must(tmpls.Parse(templates.Library))
	template.Must(tmpls.Parse(templates.Struct))
	template.Must(tmpls.Parse(templates.Table))
	template.Must(tmpls.Parse(templates.Union))
	template.Must(tmpls.Parse(templates.XUnion))
	return &FidlGenerator{
		tmpls: tmpls,
	}
}

func (gen FidlGenerator) generateSyncLibrary(wr io.Writer, tree ir.Root) error {
	return gen.tmpls.ExecuteTemplate(wr, "GenerateLibraryFile", tree)
}

func (gen FidlGenerator) generateAsyncLibrary(wr io.Writer, tree ir.Root) error {
	return gen.tmpls.ExecuteTemplate(wr, "GenerateAsyncFile", tree)
}

func (gen FidlGenerator) generateTestFile(wr io.Writer, tree ir.Root) error {
	return gen.tmpls.ExecuteTemplate(wr, "GenerateTestFile", tree)
}

func writeFile(
	generate func(io.Writer, ir.Root) error, tree ir.Root,
	outputFilename string, dartfmt string) error {

	if err := os.MkdirAll(filepath.Dir(outputFilename), os.ModePerm); err != nil {
		return err
	}
	generated, err := os.Create(outputFilename)
	if err != nil {
		return err
	}
	defer generated.Close()

	generatedPipe, err := formatter{dartfmt}.FormatPipe(generated)
	if err != nil {
		return nil
	}

	if err := generate(generatedPipe, tree); err != nil {
		return err
	}
	return generatedPipe.Close()
}

// GenerateBindings generates Dart bindings from FIDL types structures.
func (gen FidlGenerator) GenerateBindings(fidl types.Root, config *types.Config, dartfmt string) error {
	tree := ir.Compile(fidl)

	if err := writeFile(gen.generateAsyncLibrary, tree, filepath.Join(config.OutputBase, "fidl_async.dart"), dartfmt); err != nil {
		return err
	}

	if err := writeFile(gen.generateTestFile, tree, filepath.Join(config.OutputBase, "fidl_test.dart"), dartfmt); err != nil {
		return err
	}

	return nil
}
