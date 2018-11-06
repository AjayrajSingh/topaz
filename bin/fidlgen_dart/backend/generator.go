// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package backend

import (
	"fidl/compiler/backend/types"
	"fidlgen_dart/backend/ir"
	"fidlgen_dart/backend/templates"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"text/template"
)

func writeFile(outputFilename string,
	templateName string,
	tmpls *template.Template,
	tree ir.Root, dartfmt string) error {
	if err := os.MkdirAll(filepath.Dir(outputFilename), os.ModePerm); err != nil {
		return err
	}
	generated, err := os.Create(outputFilename)
	if err != nil {
		return err
	}
	defer generated.Close()
	var f io.WriteCloser = generated

	if dartfmt != "" {
		// Pipe output via supplied dartfmt command.
		cmd := exec.Command(dartfmt)
		cmd.Stdout = generated
		cmd.Stderr = nil
		f, err = cmd.StdinPipe()
		if err != nil {
			return err
		}
		err = cmd.Start()
		if err != nil {
			return err
		}

		defer cmd.Wait()
	}

	err = tmpls.ExecuteTemplate(f, templateName, tree)
	if err != nil {
		return err
	}
	return f.Close()
}

// GenerateFidl generates Dart bindings from FIDL types structures.
func GenerateFidl(fidl types.Root, config *types.Config, dartfmt string) error {
	tree := ir.Compile(fidl)

	tmpls := template.New("DartTemplates")
	template.Must(tmpls.Parse(templates.Const))
	template.Must(tmpls.Parse(templates.Enum))
	template.Must(tmpls.Parse(templates.Interface))
	template.Must(tmpls.Parse(templates.Library))
	template.Must(tmpls.Parse(templates.Struct))
	template.Must(tmpls.Parse(templates.Union))

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
