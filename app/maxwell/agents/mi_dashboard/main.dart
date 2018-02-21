// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lib.app.dart/app.dart';
import 'package:path/path.dart' as path;

import 'src/action_log.dart';
import 'src/context.dart';
import 'src/data_handler.dart';
import 'src/proposal_subscribers.dart';

// ignore_for_file: public_member_api_docs

const String _configDir = '/pkg/data/';
const String _configFilename = 'dashboard.config';
const String _defaultWebrootPath = 'webroot';
const int _defaultPort = 4000;

const String _portPropertyName = 'port';
const String _webrootPropertyName = 'webroot';

int _port = _defaultPort;
String _webrootPath = _defaultWebrootPath;
Directory _webrootDirectory;

final List<WebSocket> _activeWebsockets = <WebSocket>[];

// SendWebSocketMessage type.
void _sendMessage(String message) {
  if (_activeWebsockets.isNotEmpty) {
    for (final WebSocket socket in _activeWebsockets) {
      socket.add(message);
    }
  }
}

final Map<String, DataHandler> _dataHandlerMap = <String, DataHandler>{};

void main(List<String> args) {
  final ApplicationContext appContext =
      new ApplicationContext.fromStartupInfo();

  // Assemble the list of DataHandlers
  addDataHandler(new ActionLogDataHandler());
  addDataHandler(new ContextDataHandler());
  addDataHandler(new ProposalSubscribersDataHandler());

  // Initialize the DataHandlers
  _dataHandlerMap.forEach((String name, DataHandler handler) {
    handler.init(appContext, _sendMessage);
  });

  appContext.close();

  // Read the config file from disk
  final File configFile = new File(path.join(_configDir, _configFilename));
  configFile.readAsString(encoding: ASCII).then(parseConfigAndStart);
}

void addDataHandler(DataHandler handler) {
  _dataHandlerMap[handler.name] = handler;
}

void parseConfigAndStart(String configString) {
  // parse config file as JSON
  Map<String, dynamic> configMap = JSON.decode(configString);

  // port property
  if (configMap.containsKey(_portPropertyName))
    _port = configMap[_portPropertyName];

  // webroot property
  if (configMap.containsKey(_webrootPropertyName))
    _webrootPath = configMap[_webrootPropertyName];
  _webrootDirectory = new Directory(path.join(_configDir, _webrootPath));

  // Start the web server
  print('[INFO] Starting MI Dashboard web server on port $_port...');
  HttpServer.bind(InternetAddress.ANY_IP_V6, _port).then((HttpServer server) {
    server.listen(handleRequest);
  }).catchError((Object error) {
    print('[WARN] MI Dashboard bind failed...${error.toString()}');
  });
}

void handleRequest(HttpRequest request) {
  // Identify websocket requests
  if (request.requestedUri.path.startsWith('/ws')) {
    WebSocketTransformer.upgrade(request).then((WebSocket socket) {
      _activeWebsockets.add(socket);
      socket.listen(handleWebsocketRequest, onDone: () {
        handleWebsocketClose(socket);
      });
      // Alert all DataHandlers
      _dataHandlerMap.forEach((String name, DataHandler handler) {
        handler.handleNewWebSocket(socket);
      });
    });
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
      requestFile.exists().then((bool exists) {
        if (exists) {
          // Make sure the referenced file is within the webroot
          if (requestFile.uri.path.startsWith(_webrootDirectory.path)) {
            sendFile(requestFile, request.response);
            return;
          }
        } else {
          send404(request.response);
        }
      });
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

// ignore: avoid_annotating_with_dynamic
void handleWebsocketRequest(dynamic event) {
  print('[INFO] websocket event was received!');
}

void handleWebsocketClose(WebSocket socket) {
  print('[INFO] Websocket closed (${_activeWebsockets.indexOf(socket)})');
  _activeWebsockets.remove(socket);
}
