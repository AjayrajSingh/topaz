// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package templates

// Interface is the template for interface declarations.
const Interface = `
{{- define "Params" -}}
  {{- range $index, $param := . -}}
    {{- if $index }}, {{ end -}}{{ $param.Type.Decl }} {{ $param.Name }}
  {{- end -}}
{{ end }}

{{- define "RequestMethodSignature" -}}
  {{- if .HasResponse -}}
{{ .Name }}({{ template "Params" .Request }}{{ if .Request }}, {{ end }}void callback({{ template "Params" .Response.WireParameters }}))
  {{- else -}}
{{ .Name }}({{ template "Params" .Request }})
  {{- end -}}
{{ end -}}

{{- define "ResponseMethodSignature" -}}
{{ .Name }}({{ template "Params" .Response.WireParameters }})
{{ end -}}

{{- define "InterfaceDeclaration" -}}
abstract class {{ .Name }} {
  static const String $serviceName = {{ .ServiceName }};

{{- range .Methods }}
  {{- if .HasRequest }}
  void {{ template "RequestMethodSignature" . }};
  {{- end }}
{{- end }}
}

{{ range .Methods }}
// {{ .Name }}: {{ if .HasRequest }}({{ template "Params" .Request }}){{ end }}{{ if .HasResponse }} -> ({{ template "Params" .Response.WireParameters }}){{ end }}
const int {{ .OrdinalName }} = {{ .Ordinal }};
const $fidl.MethodType {{ .TypeSymbol }} = {{ .TypeExpr }};
{{- end }}

{{ range .Methods }}
  {{- if not .HasRequest }}
    {{- if .HasResponse }}
typedef void {{ .CallbackType }}({{ template "Params" .Response.WireParameters }});
    {{- end }}
  {{- end }}
{{- end }}

class {{ .ProxyName }} extends $fidl.Proxy<{{ .Name }}>
    implements {{ .Name }} {

  {{ .ProxyName }}() : super($fidl.ProxyController<{{ .Name }}>($serviceName: {{ .ServiceName }}, $interfaceName: r'{{ .Name }}')) {
    ctrl.onResponse = _handleResponse;
  }

  void _handleEvent($fidl.Message $message) {
    final $fidl.Decoder $decoder = $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
{{- if not .HasRequest }}
  {{- if .HasResponse }}
      case {{ .OrdinalName }}:
        final String _name = {{ .TypeSymbol }}.name;
        try {
          Timeline.startSync(_name);
          final Function $callback = {{ .Name }};
          if ($callback == null) {
            $message.closeHandles();
            return;
          }
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
          $decoder.claimMemory({{ .ResponseSize }});
          $callback(
      {{- range $index, $response := .Response.WireParameters }}
            $types[{{ $index }}].decode($decoder, 0),
      {{- end }}
          );
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          ctrl.proxyError('Exception handling event $_name: $_e');
          ctrl.close();
          rethrow;
        } finally {
          Timeline.finishSync();
        }
        break;
  {{- end }}
{{- end }}
{{- end }}
      default:
        ctrl.proxyError('Unexpected message ordinal: ${$message.ordinal}');
        ctrl.close();
        break;
    }
  }

  void _handleResponse($fidl.Message $message) {
    final int $txid = $message.txid;
    if ($txid == 0) {
      _handleEvent($message);
      return;
    }
    final Function $callback = ctrl.getCallback($txid);
    if ($callback == null) {
      $message.closeHandles();
      return;
    }
    final $fidl.Decoder $decoder = $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
  {{- if .HasRequest }}
    {{- if .HasResponse }}
      case {{ .OrdinalName }}:
        final String _name = {{ .TypeSymbol }}.name;
        try {
          Timeline.startSync(_name);
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
          $decoder.claimMemory({{ .ResponseSize }});
          $callback(
        {{- range $index, $response := .Response.WireParameters }}
            $types[{{ $index }}].decode($decoder, 0),
        {{- end }}
          );
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          ctrl.proxyError('Exception handling method response $_name: $_e');
          ctrl.close();
          rethrow;
        } finally {
          Timeline.finishSync();
        }
        break;
    {{- end }}
  {{- end }}
{{- end }}
      default:
        ctrl.proxyError('Unexpected message ordinal: ${$message.ordinal}');
        ctrl.close();
        break;
    }
  }

{{- range .Methods }}
  {{- if .HasRequest }}
  @override
  void {{ template "RequestMethodSignature" . }} {
    if (!ctrl.isBound) {
      ctrl.proxyError('The proxy is closed.');
      return;
    }

    final $fidl.Encoder $encoder = $fidl.Encoder();
    $encoder.encodeMessageHeader({{ .OrdinalName }}, 0);
    {{- if .Request }}
    $encoder.alloc({{ .RequestSize }} - $fidl.kMessageHeaderSize);
    final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.request;
    {{- end }}
    {{- range $index, $request := .Request }}
    $types[{{ $index }}].encode($encoder, {{ .Name }}, 0);
    {{- end }}

    {{- if .HasResponse }}
    Function $zonedCallback;
    if ((callback == null) || identical(Zone.current, Zone.root)) {
      $zonedCallback = callback;
    } else {
      Zone $z = Zone.current;
      {{- if .Response.WireParameters }}
      $zonedCallback = (({{ template "Params" .Response.WireParameters }}) {
        $z.bindCallback(() {
          callback(
        {{- range .Response.WireParameters -}}
            {{ .Name }},
        {{- end -}}
          );
        })();
      });
      {{- else }}
      $zonedCallback = $z.bindCallback(callback);
      {{- end }}
    }
    ctrl.sendMessageWithResponse($encoder.message, $zonedCallback);
    {{- else }}
    ctrl.sendMessage($encoder.message);
    {{- end }}
  }
  {{- else if .HasResponse }}
  {{ .CallbackType }} {{ .Name }};
  {{- end }}
{{- end }}
}

{{- if .HasEvents }}

class {{ .EventsName }} {
  $fidl.Binding<{{ .Name }}> _binding;

{{- range .Methods }}
  {{- if not .HasRequest }}
    {{- if .HasResponse }}
  void {{ template "ResponseMethodSignature" . }} {
    final $fidl.Encoder $encoder = $fidl.Encoder();
    $encoder.encodeMessageHeader({{ .OrdinalName }}, 0);
      {{- if .Response.WireParameters }}
    $encoder.alloc({{ .ResponseSize }} - $fidl.kMessageHeaderSize);
    final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
      {{- end }}
      {{- range $index, $response := .Response.WireParameters }}
    $types[{{ $index }}].encode($encoder, {{ .Name }}, 0);
      {{- end }}
    _binding.sendMessage($encoder.message);
  }
    {{- end }}
  {{- end }}
{{- end }}
}

{{- end }}

class {{ .BindingName }} extends $fidl.Binding<{{ .Name }}> {
{{- if .HasEvents }}
  {{ .BindingName }}() {
    events._binding = this;
  }

  final {{ .EventsName }} events = {{ .EventsName }}();
{{- end }}

{{ range .Methods }}
  {{- if .HasRequest }}
    {{- if .HasResponse }}
  Function _{{ .Name }}Responder($fidl.MessageSink $respond, int $txid) {
    return ({{ template "Params" .Response.WireParameters }}) {
      final $fidl.Encoder $encoder = $fidl.Encoder();
      $encoder.encodeMessageHeader({{ .OrdinalName }}, $txid);
      {{- if .Response.WireParameters }}
      $encoder.alloc({{ .ResponseSize }} - $fidl.kMessageHeaderSize);
      final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
      {{- end }}
      {{- range $index, $response := .Response.WireParameters }}
      $types[{{ $index }}].encode($encoder, {{ .Name }}, 0);
      {{- end }}
      $respond($encoder.message);
    };
  }
    {{- end }}
  {{- end }}
{{- end }}

  @override
  void handleMessage($fidl.Message $message, $fidl.MessageSink $respond) {
    final $fidl.Decoder $decoder = $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
  {{- if .HasRequest }}
      case {{ .OrdinalName }}:
        final String _name = {{ .TypeSymbol }}.name;
        try {
          Timeline.startSync(_name);
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.request;
          $decoder.claimMemory({{ .RequestSize }});
          impl.{{ .Name }}(
      {{- range $index, $request := .Request }}
            $types[{{ $index }}].decode($decoder, 0),
      {{- end }}
      {{- if .HasResponse }}
            _{{ .Name }}Responder($respond, $message.txid),
      {{- end }}
          );
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          close();
          print('Exception handling method call $_name: $_e');
          rethrow;
        } finally {
          Timeline.finishSync();
        }
        break;
  {{- end }}
{{- end }}
      default:
        throw $fidl.FidlError(r'Unexpected message name for {{ .BindingName }}');
    }
  }
}

{{ end }}




{{/*

  New-style Futures-oriented bindings:

*/}}


{{/* Generate a parameter list (eg "int foo, String baz") with AsyncDecl types */}}
{{- define "AsyncParams" -}}
  {{- range $index, $param := . -}}
    {{- if $index }}, {{ end -}}{{ $param.Type.Decl }} {{ $param.Name }}
  {{- end -}}
{{ end }}


{{/* Generate a parameter list (eg "int foo, String baz") with SyncDecl types */}}
{{- define "SyncParams" -}}
  {{- range $index, $param := . -}}
    {{- if $index }}, {{ end -}}{{ $param.Type.SyncDecl }} {{ $param.Name }}
  {{- end -}}
{{ end }}


{{- define "AsyncReturn" -}}
{{- if .HasResponse -}}
$async.Future<{{ .AsyncResponseType }}>
{{- else -}}
$async.Future<void>
{{- end -}}
{{- end -}}

{{- define "ForwardParams" -}}
{{ range $index, $param := . }}{{ if $index }}, {{ end }}{{ $param.Name }}{{ end }}
{{- end -}}




{{/*
  Decode a method response message.
  The current object is the method (ir.Method).
  The Dart local variables are:
    List<$fidl.MemberType> $types - the table for the response.
    $fidl.Decoder $decoder - the decoder for the message.
  This template expands to an expression so it can be assigned or passed as an argument.
*/}}
{{- define "DecodeResponse" -}}
  {{- if .Response.HasError }}
    $types[0].decode($decoder, 0)
  {{- else }}
    {{- if .AsyncResponseClass -}}
      {{ .AsyncResponseClass }}(
        {{- range $index, $response := .Response.WireParameters }}
          $types[{{ $index }}].decode($decoder, 0),
        {{- end -}}
      )
    {{- else -}}
      {{- if .Response.WireParameters -}}
        $types[0].decode($decoder, 0)
      {{- else -}}
        null
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{ end -}}


{{/*
  Encode a method response message.
  The current object is the method (ir.Method).
  The Dart local variables are:
    List<$fidl.MemberType> $types - the table for the response.
    $fidl.Encoder $encoder - the encoder for the message.
    $response - the Dart response type.
  This template expands to a statement.
*/}}
{{- define "EncodeResponse" -}}
  {{- if (and .AsyncResponseClass (not .Response.HasError)) -}}
    {{- range $index, $response := .Response.WireParameters }}
      $types[{{ $index }}].encode($encoder, $response.{{ .Name }}, 0);
    {{- end }}
  {{- else -}}
    {{- if .Response.WireParameters -}}
      $types[0].encode($encoder, $response, 0);
    {{- end -}}
  {{- end -}}
{{ end -}}

{{- define "InterfaceAsyncDeclaration" -}}

{{ range .Methods }}
// {{ .Name }}: {{ if .HasRequest }}({{ template "AsyncParams" .Request }}){{ end -}}
                {{- if .HasResponse }} -> ({{ template "AsyncParams" .Response.MethodParameters }}){{ end }}
const int {{ .OrdinalName }} = {{ .Ordinal }};
const $fidl.MethodType {{ .TypeSymbol }} = {{ .TypeExpr }};
{{- end }}

{{- range .Methods }}
  {{- if .AsyncResponseClass }}
class {{ .AsyncResponseClass }} {
    {{- range .Response.MethodParameters }}
  final {{ .Type.Decl }} {{ .Name }};
    {{- end }}
  {{ .AsyncResponseClass }}(
    {{- range .Response.MethodParameters }}
      this.{{ .Name }},
    {{- end -}}
    );
}
  {{- end }}
{{- end }}


{{- range .Doc }}
///{{ . -}}
{{- end }}
abstract class {{ .Name }} extends $fidl.Service {
  static const String $serviceName = {{ .ServiceName }};
  @override
  $fidl.ServiceData get $serviceData => {{ .ServiceData }}();

{{- range .Methods }}
  {{- if .HasRequest }}
    {{- range .Doc }}
    ///{{ . -}}
    {{- end }}
    {{ template "AsyncReturn" . }} {{ .Name }}({{ template "AsyncParams" .Request }})
    {{- if .Transitional }}
      { return $async.Future.error(UnimplementedError()); }
    {{- else }}
      ;
    {{- end }}
  {{- else }}
    {{- range .Doc }}
    ///{{ . -}}
    {{- end }}
    $async.Stream<{{ .AsyncResponseType}}> get {{ .Name }}
    {{- if .Transitional }}
      { return $async.Stream.empty(); }
    {{- else }}
      ;
    {{- end }}
  {{- end }}
{{- end }}
}

class {{ .ServiceData }} implements $fidl.ServiceData<{{ .Name }}> {

  const {{ .ServiceData }}();

  @override
  String getName() {
    return {{ .Name }}.$serviceName;
  }

  @override
  $fidl.AsyncBinding getBinding() {
    return {{ .BindingName }}();
  }
}

{{- range .Doc }}
///{{ . -}}
{{- end }}
class {{ .ProxyName }} extends $fidl.AsyncProxy<{{ .Name }}>
    implements {{ .Name }} {
  {{ .ProxyName }}() : super($fidl.AsyncProxyController<{{ .Name }}>($serviceName: {{ .ServiceName }}, $interfaceName: r'{{ .Name }}')) {
    ctrl.onResponse = _handleResponse;

    {{- if .HasEvents }}
      ctrl.whenClosed.then((_) {
        {{- range .Methods }}
          {{- if not .HasRequest }}
            {{- if .HasResponse }}
              _{{ .Name }}EventStreamController.close();
            {{- end }}
          {{- end }}
        {{- end }}
      }, onError: (_) { });
    {{- end }}

  }

  @override
  $fidl.ServiceData get $serviceData => {{ .ServiceData }}();

  void _handleEvent($fidl.Message $message) {
    final $fidl.Decoder $decoder = $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
{{- if not .HasRequest }}
  {{- if .HasResponse }}
      case {{ .OrdinalName }}:
        final String _name = {{ .TypeSymbol }}.name;
        try {
          Timeline.startSync(_name);
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
          $decoder.claimMemory({{ .ResponseSize }});
          _{{ .Name }}EventStreamController.add(
            {{- template "DecodeResponse" . -}}
          );
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          ctrl.proxyError($fidl.FidlError('Exception handling event $_name: $_e'));
          ctrl.close();
          rethrow;
        } finally {
          Timeline.finishSync();
        }
        break;
  {{- end }}
{{- end }}
{{- end }}
      default:
        ctrl.proxyError($fidl.FidlError('Unexpected message ordinal: ${$message.ordinal}'));
        ctrl.close();
        break;
    }
  }

  void _handleResponse($fidl.Message $message) {
    final int $txid = $message.txid;
    if ($txid == 0) {
      _handleEvent($message);
      return;
    }
    final $async.Completer $completer = ctrl.getCompleter($txid);
    if ($completer == null) {
      $message.closeHandles();
      return;
    }
    final $fidl.Decoder $decoder = $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
  {{- if .HasRequest }}
    {{- if .HasResponse }}
      case {{ .OrdinalName }}:
        final String _name = {{ .TypeSymbol }}.name;
        try {
          Timeline.startSync(_name);
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
          $decoder.claimMemory({{ .ResponseSize }});
          // ignore: prefer_const_declarations
          final $response = {{- template "DecodeResponse" . -}};
          {{ if .Response.HasError }}
            if ($response.tag == {{ .Response.ResultType.TagName }}.response) {
              {{ if .AsyncResponseClass }}
                $completer.complete(
                  {{ .AsyncResponseClass }}(
                  {{ range $param := .Response.MethodParameters }}
                    $response.response.{{ $param.Name }},
                  {{ end }}
                  ));
              {{ else }}
                {{ if (eq .AsyncResponseType "void") }}
                  $completer.complete(null);
                {{ else }}
                  $completer.complete($response.response.{{ (index .Response.MethodParameters 0).Name }});
                {{ end }}
              {{ end }}
            } else {
              $completer.completeError($fidl.MethodException($response.err));
            }
          {{ else }}
            $completer.complete($response);
          {{ end }}
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          ctrl.proxyError($fidl.FidlError('Exception handling method response $_name: $_e'));
          ctrl.close();
          rethrow;
        } finally {
          Timeline.finishSync();
        }
        break;
    {{- end }}
  {{- end }}
{{- end }}
      default:
        ctrl.proxyError($fidl.FidlError('Unexpected message ordinal: ${$message.ordinal}'));
        ctrl.close();
        break;
    }
  }

{{- range .Methods }}
  {{- if .HasRequest }}
    {{- range .Doc }}
    ///{{ . -}}
    {{- end }}
    @override
    {{ template "AsyncReturn" . }} {{ .Name }}({{ template "AsyncParams" .Request }}) async {
      if (!ctrl.isBound) {
        return $async.Future.error($fidl.FidlStateException('Proxy<${ctrl.$interfaceName}> is closed.'), StackTrace.current);
      }

      final $fidl.Encoder $encoder = $fidl.Encoder();
      $encoder.encodeMessageHeader({{ .OrdinalName }}, 0);
      {{- if .Request }}
        $encoder.alloc({{ .RequestSize }} - $fidl.kMessageHeaderSize);
        final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.request;
      {{- end }}
      {{- range $index, $request := .Request }}
        $types[{{ $index }}].encode($encoder, {{ .Name }}, 0);
      {{- end }}

      {{- if .HasResponse }}
        final $completer = $async.Completer<{{ .AsyncResponseType }}>();
        ctrl.sendMessageWithResponse($encoder.message, $completer);
        return $completer.future;
      {{- else }}
        return $async.Future.sync(() {
          ctrl.sendMessage($encoder.message);
        });
      {{- end }}
    }
  {{ else }}
    final _{{ .Name }}EventStreamController = $async.StreamController<{{ .AsyncResponseType }}>.broadcast();
    {{- range .Doc }}
    ///{{ . -}}
    {{- end }}
    @override
    $async.Stream<{{ .AsyncResponseType }}> get {{ .Name }} => _{{ .Name }}EventStreamController.stream;
  {{ end }}
{{- end }}
}

class {{ .BindingName }} extends $fidl.AsyncBinding<{{ .Name }}> {
  {{ .BindingName }}() : super(r"{{ .Name }}")
  {{- if .HasEvents }} {
    final List<$async.StreamSubscription<dynamic>> $subscriptions = [];
    void $unsubscribe() {
      for (final $sub in $subscriptions) {
        $sub.cancel();
      }
      $subscriptions.clear();
    }
    whenBound.then((_) {
      {{- range .Methods }}
        {{- if not .HasRequest }}
          if (impl.{{ .Name }} != null) {
            $subscriptions.add(impl.{{ .Name }}.listen(($response) {
              final $fidl.Encoder $encoder = $fidl.Encoder();
              $encoder.encodeMessageHeader({{ .OrdinalName }}, 0);
              $encoder.alloc({{ .ResponseSize }} - $fidl.kMessageHeaderSize);
              final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
              {{ template "EncodeResponse" . }}
              sendMessage($encoder.message);
            }));
          }
        {{- end }}
      {{- end }}
    });
    whenClosed.then((_) => $unsubscribe());
  }
  {{- else -}}
    ;
  {{- end }}

  @override
  void handleMessage($fidl.Message $message, $fidl.MessageSink $respond) {
    final $fidl.Decoder $decoder = $fidl.Decoder($message);
    switch ($message.ordinal) {
    {{- range .Methods }}
      {{- if .HasRequest }}
          case {{ .OrdinalName }}:
            final String _name = {{ .TypeSymbol }}.name;
            try {
              Timeline.startSync(_name);
              final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.request;
              $decoder.claimMemory({{ .RequestSize }});
              final {{ template "AsyncReturn" . }} $future = impl.{{ .Name }}(
              {{- range $index, $request := .Request }}
                $types[{{ $index }}].decode($decoder, 0),
              {{- end }});

              {{- if .HasResponse }}
                $future
                {{ if .Response.HasError }}
                .then(($responseValue) {
                  {{ if .AsyncResponseClass }}
                    return {{ .Response.ResultType.Name }}.withResponse(
                      {{ .Response.ValueType.Decl }}(
                      {{ range $param := .Response.MethodParameters }}
                        {{ $param.Name }}: $responseValue.{{ $param.Name }},
                      {{ end }}
                      ));
                  {{ else }}
                    return {{ .Response.ResultType.Name }}.withResponse(
                      {{ .Response.ValueType.Decl }}(
                        {{ if (ne .AsyncResponseType "void") }}
                          {{ (index .Response.MethodParameters 0).Name }}: $responseValue
                        {{ end }}
                        ));
                  {{ end }}
                }, onError: ($error) {
                  if ($error is $fidl.MethodException) {
                    return {{ .Response.ResultType.Name }}.withErr($error.value);
                  } else {
                    return Future.error($error);
                  }
                })
                {{ end }}
                .then(($response) {
                  final $fidl.Encoder $encoder = $fidl.Encoder();
                  $encoder.encodeMessageHeader({{ .OrdinalName }}, $message.txid);
                  {{- if .Response.WireParameters }}
                    $encoder.alloc({{ .ResponseSize }} - $fidl.kMessageHeaderSize);
                    final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
                    {{ template "EncodeResponse" . -}}
                  {{- end }}
                  $respond($encoder.message);
                }, onError: (_e) {
                  close();
                  print('Exception handling method call $_name: $_e');
                });
              {{- end }}
            // ignore: avoid_catches_without_on_clauses
            } catch(_e) {
              close();
              print('Exception handling method call $_name: $_e');
              rethrow;
            } finally {
              Timeline.finishSync();
            }
            break;
      {{- end }}
    {{- end }}
      default:
        throw $fidl.FidlError(r'Unexpected message name for {{ .BindingName }}');
    }
  }
}

{{ end }}



{{- define "InterfaceTestDeclaration" -}}

class {{ .Name }}$TestBase extends {{ .Name }} {
  {{- range .Methods }}
  @override
  {{- if .HasRequest }}
  {{ template "AsyncReturn" . }} {{ .Name }}({{ template "AsyncParams" .Request }}) {
    return $async.Future.error(UnimplementedError());
  }
  {{- else }}
  $async.Stream<{{ .AsyncResponseType}}> get {{ .Name }} {
    return $async.Stream.fromFuture($async.Future.error(UnimplementedError()));
  }
  {{- end }}
{{- end }}

}

{{ end }}

`
