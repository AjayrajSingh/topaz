// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package templates

// Union is the template for union declarations.
const Union = `
{{- define "UnionDeclaration" -}}
enum {{ .TagName }} {
{{- range .Members }}
  {{ .Tag }},
{{- end }}
}

{{- range .Doc }}
///{{ . -}}
{{- end }}
class {{ .Name }} extends $fidl.Union {
{{- range .Members }}

  const {{ $.Name }}.with{{ .CtorName }}({{ .Type.Decl }} value)
    : _data = value, _tag = {{ $.TagName }}.{{ .Tag }};
{{- end }}

  {{ .Name }}._({{ .TagName }} tag, Object data) : _tag = tag, _data = data;

  final {{ .TagName }} _tag;
  final _data;

{{- range .Members }}
  {{ .Type.Decl }} get {{ .Name }} {
    if (_tag != {{ $.TagName }}.{{ .Tag }}) {
      return null;
    }
    return _data;
  }
{{- end }}

  @override
  String toString() {
    switch (_tag) {
{{- range .Members }}
      case {{ $.TagName }}.{{ .Tag }}:
        return r'{{ $.Name }}.{{ .Name }}(${{ .Name }})';
{{- end }}
      default:
        return null;
    }
  }

  {{- range .Doc }}
  ///{{ . -}}
  {{- end }}

  {{ .TagName }} get $tag => _tag;
  // TODO: remove, see: FIDL-587
  {{ .TagName }} get tag => _tag;

  @override
  int get $index => _tag.index;

  @override
  Object get $data => _data;

  static {{ .Name }} _ctor(int index, Object data) {
    return {{ .Name }}._({{ .TagName }}.values[index], data);
  }
}

// See FIDL-308:
// ignore: recursive_compile_time_constant
const $fidl.UnionType<{{ .Name }}> {{ .TypeSymbol }} = {{ .TypeExpr }};
{{ end }}
`
