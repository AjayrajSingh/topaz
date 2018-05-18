// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fuchsia/fuchsia.dart' as fuchsia;
import 'package:lib.app.dart/app.dart';
import 'package:fidl/fidl.dart';
import 'package:fidl_modular/fidl.dart';

import 'package:path/path.dart' as path;

import 'src/data_handler.dart';
import 'src/ledger_debug_data_handler.dart';

const String _configDir = '/pkg/data';
const String _configFilename = 'dashboard.config';
const String _defaultWebrootPath = 'webroot';
const int _defaultPort = 4001;

const String _portPropertyName = 'port';
const String _webrootPropertyName = 'webroot';

int _port = _defaultPort;
String _webrootPath = _defaultWebrootPath;
Directory _webrootDirectory;

final Map<String, DataHandler> _dataHandlerMap = <String, DataHandler>{};

void _log(String msg) {
  print('[Ledger Dashboad] $msg');
}

/// An implementation of the [Lifecycle] interface.
class LifecycleImpl implements Lifecycle {
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();

  LifecycleImpl();

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  /// Implementation of the Lifecycle.Terminate() method.
  @override
  void terminate() {
    _log('LifecycleImpl.terminate()');
    _lifecycleBinding.close();
    fuchsia.exit(0);
  }
}

void main(List<String> args) {
  final ApplicationContext appContext =
      new ApplicationContext.fromStartupInfo();

  // Assemble the list of DataHandlers
  addDataHandler(new LedgerDebugDataHandler());

  // Initialize the DataHandlers
  _dataHandlerMap.forEach((String name, DataHandler handler) {
    handler.init(appContext);
  });

  final LifecycleImpl lifeCycleImpl = new LifecycleImpl();
  appContext.outgoingServices
    ..addServiceForName(
      lifeCycleImpl.bindLifecycle,
      Lifecycle.$serviceName,
    );

  appContext.close();

  // Read the config file from disk
  final File configFile = new File(path.join(_configDir, _configFilename));
  configFile.readAsString(encoding: ascii).then(parseConfigAndStart);
}

void addDataHandler(DataHandler handler) {
  _dataHandlerMap[handler.name] = handler;
}

void parseConfigAndStart(String configString) {
  // parse config file as JSON
  Map<String, dynamic> configMap = json.decode(configString);

  // port property
  if (configMap.containsKey(_portPropertyName))
    _port = configMap[_portPropertyName];

  // webroot property
  if (configMap.containsKey(_webrootPropertyName))
    _webrootPath = configMap[_webrootPropertyName];
  _webrootDirectory = new Directory(path.join(_configDir, _webrootPath));

  // Start the web server
  print('[INFO] Starting LEDGER Dashboard web server on port $_port...');
  HttpServer.bind(InternetAddress.anyIPv6, _port).then((HttpServer server) {
    server.listen(handleRequest);
    // ignore: always_specify_types
  }).catchError((error) {
    print('[WARN] LEDGER Dashboard bind failed... $error');
  });
}

void handleRequest(HttpRequest request) {
  // Identify websocket requests
  // Such requests will end with /ws/<service>/
  final RegExp websocketRequestPattern = new RegExp('/ws/([^/]+)/');
  final Match match =
      websocketRequestPattern.firstMatch(request.requestedUri.path);
  if (match != null) {
    WebSocketTransformer.upgrade(request).then((WebSocket socket) {
      final String serviceName = match.group(1);
      final DataHandler handler = _dataHandlerMap[serviceName];
      if (handler != null) {
        handler.handleNewWebSocket(socket);
      } else {
        send404(request.response);
      }
    });
  } else if (request.requestedUri.path.startsWith('/ws')) {
    send404(request.response);
  } else {
    // Identify requests requiring return of context data
    // Such requests will begin with /data/<service>/...
    final RegExp dataRequestPattern = new RegExp('/data/([^/]+)(/.*)');
    final Match match =
        dataRequestPattern.firstMatch(request.requestedUri.path);
    if (match != null) {
      final String serviceName =
          match.group(1); // first match group is the service name
      // print('Returning data for service ${serviceName}');

      // we are returning JSON
      request.response.headers.contentType =
          new ContentType('application', 'json', charset: 'utf-8');

      // If an appropriate handler can be found, ask it to respond
      final DataHandler handler = _dataHandlerMap[serviceName];
      if (handler?.handleRequest(match.group(2), request) ?? false) {
        return;
      }

      // Nothing handled the request, so respond with a 404
      send404(request.response);
    } else {
      // Find the referenced file
      // path.join does not work in this case, possibly because the request path
      // may start with a /, so using a simple string concatenation instead
      String requestPath =
          '${_webrootDirectory.path}/${request.requestedUri.path}';
      if (requestPath.endsWith('/')) {
        requestPath = '${requestPath}index.html';
      }
      final File requestFile = new File(requestPath);
      if (requestFile.existsSync()) {
        // Make sure the referenced file is within the webroot
        if (requestFile.uri.path.startsWith(_webrootDirectory.path)) {
          sendFile(requestFile, request.response);
          return;
        }
      } else {
        send404(request.response);
      }
    }
  }
}

Future<Null> sendFile(File requestFile, HttpResponse response) async {
  // Set the content type correctly based on the file name suffix
  // The content type is text/plain if the suffix isn't identified
  if (requestFile.path.endsWith('html')) {
    response.headers.contentType =
        new ContentType('text', 'html', charset: 'utf-8');
  } else if (requestFile.path.endsWith('json')) {
    response.headers.contentType =
        new ContentType('application', 'json', charset: 'utf-8');
  } else if (requestFile.path.endsWith('js')) {
    response.headers.contentType =
        new ContentType('application', 'javascript', charset: 'utf-8');
  } else if (requestFile.path.endsWith('css')) {
    response.headers.contentType =
        new ContentType('text', 'css', charset: 'utf-8');
  } else if (requestFile.path.endsWith('jpg') ||
      requestFile.path.endsWith('jpeg')) {
    response.headers.contentType = new ContentType('image', 'jpeg');
  } else if (requestFile.path.endsWith('png')) {
    response.headers.contentType = new ContentType('image', 'png');
  } else {
    response.headers.contentType =
        new ContentType('text', 'plain', charset: 'utf-8');
  }

  // Send the contents of the file
  await requestFile.openRead().pipe(response);

  return response.close();
}

void send404(HttpResponse response) {
  response
    ..statusCode = 404
    ..reasonPhrase = 'File not found.'
    ..close();
}
