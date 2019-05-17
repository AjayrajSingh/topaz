// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package backend

import (
	"fidl/compiler/backend/types"
	"fidlgen_dart/backend/ir"
	"fidlgen_dart/backend/templates"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"text/template"
)

func writeFile(outputFilename string,
	templateName string,
	tmpls *template.Template,
	tree ir.Root, dartfmt string) error {
	// Set up the output directory
	outputDirectory := filepath.Dir(outputFilename)
	if err := os.MkdirAll(outputDirectory, os.ModePerm); err != nil {
		return err
	}

	// Generate to a temporary file
	temporaryFile, err := ioutil.TempFile(outputDirectory, "fidlgen_tmp")
	if err != nil {
		return err
	}
	defer os.Remove(temporaryFile.Name())
	err = tmpls.ExecuteTemplate(temporaryFile, templateName, tree)
	if err != nil {
		return err
	}
	err = temporaryFile.Close()
	if err != nil {
		return err
	}

	// Run dartfmt over the file
	if dartfmt != "" {
		cmd := exec.Command(dartfmt, "--overwrite", temporaryFile.Name())
		cmd.Stderr = os.Stderr
		err = cmd.Run()
		if err != nil {
			return err
		}
	}

	// Rename the temporary file to the destination name
	return os.Rename(temporaryFile.Name(), outputFilename)
}

// GenerateFidl generates Dart bindings from FIDL types structures.
func GenerateFidl(fidl types.Root, config *types.Config, dartfmt string) error {
	tree := ir.Compile(fidl)

	tmpls := template.New("DartTemplates")
	template.Must(tmpls.Parse(templates.Const))
	template.Must(tmpls.Parse(templates.Enum))
	template.Must(tmpls.Parse(templates.Bits))
	template.Must(tmpls.Parse(templates.Interface))
	template.Must(tmpls.Parse(templates.Library))
	template.Must(tmpls.Parse(templates.Struct))
	template.Must(tmpls.Parse(templates.Table))
	template.Must(tmpls.Parse(templates.Union))
	template.Must(tmpls.Parse(templates.XUnion))

	err := writeFile(config.OutputBase+"/fidl.dart", "GenerateLibraryFile", tmpls, tree, dartfmt)
	if err != nil {
		return err
	}

	err = writeFile(config.OutputBase+"/fidl_async.dart", "GenerateAsyncFile", tmpls, tree, dartfmt)
	if err != nil {
		return err
	}

	return writeFile(config.OutputBase+"/fidl_test.dart", "GenerateTestFile", tmpls, tree, dartfmt)
}
