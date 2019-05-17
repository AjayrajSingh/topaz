// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package templates

// Bits is the template for bits declarations.
const Bits = `
{{- define "BitsDeclaration" -}}
{{- range .Doc }}
///{{ . -}}
{{- end }}
class {{ .Name }} extends $fidl.Bits {
{{- range .Members }}
  {{- range .Doc }}
  ///{{ . -}}
  {{- end }}
  static const {{ $.Name }} {{ .Name }} = {{ $.Name }}._({{ .Value }});
{{- end }}
  static const {{ .Name }} $none = {{ .Name }}._(0);

  const {{ .Name }}._(this.$value);

  {{ .Name }} operator |({{ .Name }} other) {
    return {{ .Name }}._($value | other.$value);
  }

  {{ .Name }} operator &({{ .Name }} other) {
    return {{ .Name }}._($value & other.$value);
  }

  @override
  final int $value;

  @override
  String toString() {
    if ($value == null) {
      return null;
    }
    List<String> parts = [];
{{- range .Members }}
    if ($value & {{ .Value }} != 0) {
      parts.add(r'{{ $.Name }}.{{ .Name }}');
	}
{{- end }}
    if (parts.isEmpty) {
      return r'{{ $.Name }}.$none';
    } else {
      return parts.join(" | ");
    }
  }

  static {{ .Name }} _ctor(int v) => {{ .Name }}._(v);
}

const $fidl.BitsType<{{ .Name }}> {{ .TypeSymbol }} = {{ .TypeExpr }};
{{ end }}
`
