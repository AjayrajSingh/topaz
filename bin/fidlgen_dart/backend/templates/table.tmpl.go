// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package templates

// Table is the template for struct declarations.
const Table = `
{{- define "TableDeclaration" -}}
{{- range .Doc }}
///{{ . -}}
{{- end }}
class {{ .Name }} extends $fidl.Table {
  const {{ .Name }}({{- if len .Members }}{
{{- range .Members }}
    this.{{ .Name }}{{ if .DefaultValue }}: {{ .DefaultValue }}{{ end }},
{{- end }}
  }{{ end -}});

  {{ .Name }}._(Map<int, dynamic> argv)
    {{- if len .Members }}:
{{- range $index, $member := .Members -}}
  {{- if $index }},
      {{ else }} {{ end -}}
    {{ .Name }} = argv[{{ .Ordinal }}]
{{- end }}{{- end }};

{{- range .Members }}
  {{- range .Doc }}
  ///{{ . -}}
  {{- end }}
  final {{ .Type.Decl }} {{ .Name }};
{{- end }}

  @override
  Map<int, dynamic> get $fields {
    return {
  {{- range .Members }}
    {{ .Ordinal }}: {{ .Name }},
  {{- end }}
    };
  }

  static {{ .Name }} _ctor(Map<int, dynamic> argv) => {{ .Name }}._(argv);
}

// See FIDL-308:
// ignore: recursive_compile_time_constant
const $fidl.TableType<{{ .Name }}> {{ .TypeSymbol }} = {{ .TypeExpr }};
{{ end }}
`
