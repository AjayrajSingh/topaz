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
{{ .Name }}({{ template "Params" .Request }}{{ if .Request }}, {{ end }}void callback({{ template "Params" .Response }}))
  {{- else -}}
{{ .Name }}({{ template "Params" .Request }})
  {{- end -}}
{{ end -}}

{{- define "ResponseMethodSignature" -}}
{{ .Name }}({{ template "Params" .Response }})
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
// {{ .Name }}: {{ if .HasRequest }}({{ template "Params" .Request }}){{ end }}{{ if .HasResponse }} -> ({{ template "Params" .Response }}){{ end }}
const int {{ .OrdinalName }} = {{ .Ordinal }};
const $fidl.MethodType {{ .TypeSymbol }} = {{ .TypeExpr }};
{{- end }}

{{ range .Methods }}
  {{- if not .HasRequest }}
    {{- if .HasResponse }}
typedef void {{ .CallbackType }}({{ template "Params" .Response }});
    {{- end }}
  {{- end }}
{{- end }}

class {{ .ProxyName }} extends $fidl.Proxy<{{ .Name }}>
    implements {{ .Name }} {

  {{ .ProxyName }}() : super(new $fidl.ProxyController<{{ .Name }}>($serviceName: {{ .ServiceName }}, $interfaceName: r'{{ .Name }}')) {
    ctrl.onResponse = _handleResponse;
  }

  void _handleEvent($fidl.Message $message) {
    final $fidl.Decoder $decoder = new $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
{{- if not .HasRequest }}
  {{- if .HasResponse }}
      case {{ .OrdinalName }}:
        try {
          final Function $callback = {{ .Name }};
          if ($callback == null) {
            $message.closeHandles();
            return;
          }
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
          $decoder.claimMemory({{ .ResponseSize }});
          $callback(
      {{- range $index, $response := .Response }}
            $types[{{ $index }}].decode($decoder, 0),
      {{- end }}
          );
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          final String _name = {{ .TypeSymbol }}.name;
          ctrl.proxyError('Exception handling event $_name: $_e');
          ctrl.close();
          rethrow;
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
    final $fidl.Decoder $decoder = new $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
  {{- if .HasRequest }}
    {{- if .HasResponse }}
      case {{ .OrdinalName }}:
        try {
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
          $decoder.claimMemory({{ .ResponseSize }});
          $callback(
        {{- range $index, $response := .Response }}
            $types[{{ $index }}].decode($decoder, 0),
        {{- end }}
          );
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          final String _name = {{ .TypeSymbol }}.name;
          ctrl.proxyError('Exception handling method response $_name: $_e');
          ctrl.close();
          rethrow;
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

    final $fidl.Encoder $encoder = new $fidl.Encoder({{ .OrdinalName }});
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
      {{- if .Response }}
      $zonedCallback = (({{ template "Params" .Response }}) {
        $z.bindCallback(() {
          callback(
        {{- range .Response -}}
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
    final $fidl.Encoder $encoder = new $fidl.Encoder({{ .OrdinalName }});
      {{- if .Response }}
    $encoder.alloc({{ .ResponseSize }} - $fidl.kMessageHeaderSize);
    final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
      {{- end }}
      {{- range $index, $response := .Response }}
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

  final {{ .EventsName }} events = new {{ .EventsName }}();
{{- end }}

{{ range .Methods }}
  {{- if .HasRequest }}
    {{- if .HasResponse }}
  Function _{{ .Name }}Responder($fidl.MessageSink $respond, int $txid) {
    return ({{ template "Params" .Response }}) {
      final $fidl.Encoder $encoder = new $fidl.Encoder({{ .OrdinalName }});
      {{- if .Response }}
      $encoder.alloc({{ .ResponseSize }} - $fidl.kMessageHeaderSize);
      final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
      {{- end }}
      {{- range $index, $response := .Response }}
      $types[{{ $index }}].encode($encoder, {{ .Name }}, 0);
      {{- end }}
      $fidl.Message $message = $encoder.message;
      $message.txid = $txid;
      $respond($message);
    };
  }
    {{- end }}
  {{- end }}
{{- end }}

  @override
  void handleMessage($fidl.Message $message, $fidl.MessageSink $respond) {
    final $fidl.Decoder $decoder = new $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
  {{- if .HasRequest }}
      case {{ .OrdinalName }}:
        try {
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
          final String _name = {{ .TypeSymbol }}.name;
          print('Exception handling method call $_name: $_e');
          rethrow;
        }
        break;
  {{- end }}
{{- end }}
      default:
        throw new $fidl.FidlError('Unexpected message name');
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
Future<{{ .AsyncResponseType }}>
{{- else -}}
Future<void>
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
  {{- if .AsyncResponseClass -}}
    new {{ .AsyncResponseClass }}(
      {{- range $index, $response := .Response }}
        $types[{{ $index }}].decode($decoder, 0),
      {{- end -}}
    )
  {{- else -}}
    {{- if .Response -}}
      $types[0].decode($decoder, 0),
    {{- else -}}
      null
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
  {{- if .AsyncResponseClass -}}
    {{- range $index, $response := .Response }}
      $types[{{ $index }}].encode($encoder, $response.{{ .Name }}, 0);
    {{- end }}
  {{- else -}}
    {{- if .Response -}}
      $types[0].encode($encoder, $response, 0);
    {{- end -}}
  {{- end -}}
{{ end -}}

{{- define "InterfaceAsyncDeclaration" -}}

{{ range .Methods }}
// {{ .Name }}: {{ if .HasRequest }}({{ template "AsyncParams" .Request }}){{ end -}}
                {{- if .HasResponse }} -> ({{ template "AsyncParams" .Response }}){{ end }}
const int {{ .OrdinalName }} = {{ .Ordinal }};
const $fidl.MethodType {{ .TypeSymbol }} = {{ .TypeExpr }};
{{- end }}

{{- range .Methods }}
  {{- if .AsyncResponseClass }}
class {{ .AsyncResponseClass }} {
    {{- range .Response }}
  final {{ .Type.Decl }} {{ .Name }};
    {{- end }}
  {{ .AsyncResponseClass }}(
    {{- range .Response }}
      this.{{ .Name }},
    {{- end -}}
    );
}
  {{- end }}
{{- end }}

{{- range .Doc }}
///{{ . -}}
{{- end }}
abstract class {{ .Name }} {
  static const String $serviceName = {{ .ServiceName }};

{{- range .Methods }}
  {{- if .HasRequest }}
  {{- range .Doc }}
  ///{{ . -}}
  {{- end }}
  {{ template "AsyncReturn" . }} {{ .Name }}({{ template "AsyncParams" .Request }});
  {{- else }}
  {{- range .Doc }}
  ///{{ . -}}
  {{- end }}
  Stream<{{ .AsyncResponseType}}> get {{ .Name }};
  {{- end }}
{{- end }}
}

{{- range .Doc }}
///{{ . -}}
{{- end }}
class {{ .ProxyName }} extends $fidl.AsyncProxy<{{ .Name }}>
    implements {{ .Name }} {
  {{ .ProxyName }}() : super(new $fidl.AsyncProxyController<{{ .Name }}>($serviceName: {{ .ServiceName }}, $interfaceName: r'{{ .Name }}')) {
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

  void _handleEvent($fidl.Message $message) {
    final $fidl.Decoder $decoder = new $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
{{- if not .HasRequest }}
  {{- if .HasResponse }}
      case {{ .OrdinalName }}:
        try {
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
          $decoder.claimMemory({{ .ResponseSize }});
          _{{ .Name }}EventStreamController.add(
            {{- template "DecodeResponse" . -}}
          );
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          final String _name = {{ .TypeSymbol }}.name;
          ctrl.proxyError(new $fidl.FidlError('Exception handling event $_name: $_e'));
          ctrl.close();
          rethrow;
        }
        break;
  {{- end }}
{{- end }}
{{- end }}
      default:
        ctrl.proxyError(new $fidl.FidlError('Unexpected message ordinal: ${$message.ordinal}'));
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
    final Completer $completer = ctrl.getCompleter($txid);
    if ($completer == null) {
      $message.closeHandles();
      return;
    }
    final $fidl.Decoder $decoder = new $fidl.Decoder($message);
    switch ($message.ordinal) {
{{- range .Methods }}
  {{- if .HasRequest }}
    {{- if .HasResponse }}
      case {{ .OrdinalName }}:
        try {
          final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
          $decoder.claimMemory({{ .ResponseSize }});
          $completer.complete(
            {{- template "DecodeResponse" . -}}
          );
        // ignore: avoid_catches_without_on_clauses
        } catch(_e) {
          final String _name = {{ .TypeSymbol }}.name;
          ctrl.proxyError(new $fidl.FidlError('Exception handling method response $_name: $_e'));
          ctrl.close();
          rethrow;
        }
        break;
    {{- end }}
  {{- end }}
{{- end }}
      default:
        ctrl.proxyError(new $fidl.FidlError('Unexpected message ordinal: ${$message.ordinal}'));
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
        return new Future.error(new $fidl.FidlStateException('The proxy is closed.'));
      }

      final $fidl.Encoder $encoder = new $fidl.Encoder({{ .OrdinalName }});
      {{- if .Request }}
        $encoder.alloc({{ .RequestSize }} - $fidl.kMessageHeaderSize);
        final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.request;
      {{- end }}
      {{- range $index, $request := .Request }}
        $types[{{ $index }}].encode($encoder, {{ .Name }}, 0);
      {{- end }}

      {{- if .HasResponse }}
        final $completer = new Completer<{{ .AsyncResponseType }}>();
        ctrl.sendMessageWithResponse($encoder.message, $completer);
        return $completer.future;
      {{- else }}
        return new Future.sync(() {
          ctrl.sendMessage($encoder.message);
        });
      {{- end }}
    }
  {{ else }}
    final _{{ .Name }}EventStreamController = new StreamController<{{ .AsyncResponseType }}>.broadcast();
    {{- range .Doc }}
    ///{{ . -}}
    {{- end }}
    @override
    Stream<{{ .AsyncResponseType }}> get {{ .Name }} => _{{ .Name }}EventStreamController.stream;
  {{ end }}
{{- end }}
}

class {{ .BindingName }} extends $fidl.AsyncBinding<{{ .Name }}> {
  {{ .BindingName }}() : super(r"{{ .Name }}")
  {{- if .HasEvents }} {
    final List<StreamSubscription<dynamic>> $subscriptions = [];
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
              final $fidl.Encoder $encoder = new $fidl.Encoder({{ .OrdinalName }});
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
    final $fidl.Decoder $decoder = new $fidl.Decoder($message);
    switch ($message.ordinal) {
    {{- range .Methods }}
      {{- if .HasRequest }}
          case {{ .OrdinalName }}:
            try {
              final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.request;
              $decoder.claimMemory({{ .RequestSize }});
              final {{ template "AsyncReturn" . }} $future = impl.{{ .Name }}(
              {{- range $index, $request := .Request }}
                $types[{{ $index }}].decode($decoder, 0),
              {{- end }});

              {{- if .HasResponse }}
                $future.then(($response) {
                  final $fidl.Encoder $encoder = new $fidl.Encoder({{ .OrdinalName }});
                  {{- if .Response }}
                    $encoder.alloc({{ .ResponseSize }} - $fidl.kMessageHeaderSize);
                    final List<$fidl.MemberType> $types = {{ .TypeSymbol }}.response;
                    {{ template "EncodeResponse" . -}}
                  {{- end }}
                  $fidl.Message $responseMessage = $encoder.message;
                  $responseMessage.txid = $message.txid;
                  $respond($responseMessage);
                }, onError: (_e) {
                  close();
                  final String _name = {{ .TypeSymbol }}.name;
                  print('Exception handling method call $_name: $_e');
                });
              {{- end }}
            // ignore: avoid_catches_without_on_clauses
            } catch(_e) {
              close();
              final String _name = {{ .TypeSymbol }}.name;
              print('Exception handling method call $_name: $_e');
              rethrow;
            }
            break;
      {{- end }}
    {{- end }}
      default:
        throw new $fidl.FidlError('Unexpected message name');
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
    return Future.error(UnimplementedError());
  }
  {{- else }}
  Stream<{{ .AsyncResponseType}}> get {{ .Name }} {
    return Stream.fromFuture(Future.error(UnimplementedError()));
  }
  {{- end }}
{{- end }}

}

{{ end }}

`
