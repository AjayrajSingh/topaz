// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package templates

// Enum is the template for enum declarations.
const Enum = `
{{- define "EnumDeclaration" -}}
{{- range .Doc }}
///{{ . -}}
{{- end }}
class {{ .Name }} extends $fidl.Enum {
  factory {{ .Name }}(int _v) {
    switch (_v) {
{{- range .Members }}
      case {{ .Value }}:
        return {{ .Name }};
{{- end }}
      default:
        return null;
    }
  }

{{- range .Members }}
  {{- range .Doc }}
  ///{{ . -}}
  {{- end }}
  static const {{ $.Name }} {{ .Name }} = {{ $.Name }}._({{ .Value }});
{{- end }}

  const {{ .Name }}._(this.$value);

  @override
  final int $value;

  static const Map<String, {{ .Name }}> $valuesMap = {
  {{- range .Members }}
    r'{{ .Name }}': {{ .Name }},
  {{- end }}
  };

  static const List<{{ .Name }}> $values = [
    {{- range .Members }}
    {{ .Name }},
    {{- end }}
  ];

  // TODO: remove, see: FIDL-587
  static const List<{{ .Name }}> values = {{ .Name }}.$values;

  static {{ .Name }} $valueOf(String name) => $valuesMap[name];

  @override
  String toString() {
    switch ($value) {
  {{- range .Members }}
      case {{ .Value }}:
        return r'{{ $.Name }}.{{ .Name }}';
  {{- end }}
      default:
        return null;
    }
  }

  static {{ .Name }} _ctor(int v) => {{ .Name }}(v);
}

const $fidl.EnumType<{{ .Name }}> {{ .TypeSymbol }} = {{ .TypeExpr }};
{{ end }}
`
