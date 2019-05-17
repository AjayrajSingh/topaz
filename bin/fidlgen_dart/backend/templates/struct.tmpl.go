// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package templates

// Struct is the template for struct declarations.
const Struct = `
{{- define "StructDeclaration" -}}
{{- range .Doc }}
///{{ . -}}
{{- end }}
class {{ .Name }} extends $fidl.Struct {
  const {{ .Name }}({
{{- range .Members }}
    {{ if not .Type.Nullable }}{{ if not .DefaultValue }}@required {{ end }}{{ end -}}
    this.{{ .Name }}{{ if .DefaultValue }}: {{ .DefaultValue }}{{ end }},
{{- end }}
  });
  {{ .Name }}.clone({{ .Name }} $orig, {
{{- range .Members }}
  {{ .Type.Decl }} {{ .Name }},
{{- end }}
  }) : this(
    {{- range .Members }}
      {{ .Name }}: {{ .Name }} ?? $orig.{{ .Name }},
    {{- end }}
    );


  {{ if .HasNullableField }}
    {{ .Name }}.cloneWithout({{ .Name }} $orig, {
      {{- range .Members }}
        {{ if .Type.Nullable }}bool {{ .Name }},{{ end }}
      {{- end }}
    }) : this(
      {{- range .Members }}
        {{ if .Type.Nullable }}
          {{ .Name }}: {{ .Name }} ? null : $orig.{{ .Name }},
        {{ else }}
          {{ .Name }}: $orig.{{ .Name }},
        {{ end }}
      {{- end }}
      );
  {{ end }}

  {{ .Name }}._(List<Object> argv)
    :
{{- range $index, $member := .Members -}}
  {{- if $index }},
      {{ else }} {{ end -}}
    {{ .Name }} = argv[{{ $index }}]
{{- end }};

{{- range .Members }}
  {{- range .Doc }}
  ///{{ . -}}
  {{- end }}
  final {{ .Type.Decl }} {{ .Name }};
{{- end }}

  @override
  List<Object> get $fields {
    return <Object>[
  {{- range .Members }}
      {{ .Name }},
  {{- end }}
    ];
  }

  @override
  String toString() {
    // ignore: prefer_interpolation_to_compose_strings
    return r'{{ .Name }}' r'(
{{- range $index, $member := .Members -}}
      {{- if $index }}, {{ end -}}{{ $member.Name  }}: ' + {{ $member.Name }}.toString() + r'
{{- end -}}
    )';
  }

  static {{ .Name }} _ctor(List<Object> argv) => {{ .Name }}._(argv);
}

// See FIDL-308:
// ignore: recursive_compile_time_constant
const $fidl.StructType<{{ .Name }}> {{ .TypeSymbol }} = {{ .TypeExpr }};
{{ end }}
`
