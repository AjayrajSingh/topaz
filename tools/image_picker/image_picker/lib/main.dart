// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:config_flutter/config.dart';
import 'package:flutter/material.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:widgets/image_picker.dart';

final ApplicationContext _context = new ApplicationContext.fromStartupInfo();
final GlobalKey<HomeScreenState> _kHomeKey = new GlobalKey<HomeScreenState>();
const String _kImagePickerDocRoot = 'image-picker-doc';
const String _kImagePickerQueryKey = 'image-picker-query';
ModuleImpl _module;

void _log(String msg) {
  print('[image_picker] $msg');
}

/// An implementation of the [LinkWatcher] interface.
class LinkWatcherImpl extends LinkWatcher {
  final LinkWatcherBinding _binding = new LinkWatcherBinding();

  /// Gets the [InterfaceHandle] for this [LinkWatcher] implementation.
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<LinkWatcher> getHandle() => _binding.wrap(this);

  /// Correctly close the Link Binding
  void close() => _binding.close();

  @override
  void notify(String json) {
    _log('LinkWatcherImpl::notify call');

    final dynamic doc = JSON.decode(json);
    if (doc is! Map ||
        doc[_kImagePickerDocRoot] is! Map ||
        doc[_kImagePickerDocRoot][_kImagePickerQueryKey] is! String) {
      _log('No image picker query key found in json.');
      return;
    }

    String queryString = doc[_kImagePickerDocRoot][_kImagePickerQueryKey];

    _log('queryString: $queryString');
    _kHomeKey.currentState.queryString = queryString;
  }
}

/// An implementation of the [Module] interface
class ModuleImpl extends Module {
  final ModuleBinding _binding = new ModuleBinding();

  /// The [LinkProxy] from which this module gets the youtube video id.
  final LinkProxy link = new LinkProxy();

  final LinkWatcherImpl _linkWatcher = new LinkWatcherImpl();

  /// Bind an [InterfaceRequest] for a [Module] interface to this object.
  void bind(InterfaceRequest<Module> request) {
    _binding.bind(this, request);
  }

  @override
  void initialize(
    InterfaceHandle<ModuleContext> moduleContextHandle,
    InterfaceHandle<Link> linkHandle,
    InterfaceHandle<ServiceProvider> incomingServicesHandle,
    InterfaceRequest<ServiceProvider> outgoingServices,
  ) {
    _log('ModuleImpl::initialize call');

    // Bind the link handle and register the link watcher.
    link.ctrl.bind(linkHandle);
    link.watchAll(_linkWatcher.getHandle());
  }

  @override
  void stop(void callback()) {
    _log('ModuleImpl::stop call');
    _linkWatcher.close();
    link.ctrl.close();
    callback();
  }
}

/// Main screen for this module.
class HomeScreen extends StatefulWidget {

  /// Creates a new instance of [HomeScreen].
  HomeScreen({Key key}) : super(key: key);

  @override
  HomeScreenState createState() => new HomeScreenState();
}

/// State class for the main screen widget.
class HomeScreenState extends State<HomeScreen> {
  String _apiKey;
  String _customSearchId;
  String _queryString;

  // Fetches the search key and search ID from config.json
  Future<Null> _readConfig() async {
    Config config = await Config.read('assets/config.json');
    String searchKey = config.get('google_search_key');
    String searchId = config.get('google_search_id');
    if (searchKey == null || searchId == null) {
      _log(
          '"google_search_key" and "google_search_id" must be specified in config.json.');
    } else {
      setState((){
        _apiKey = searchKey;
        _customSearchId = searchId;
      });
    }
  }

  /// Sets and updates(through setState) the query string for image search
  set queryString(String query) {
    setState(() {
      _queryString = query;
    });
  }

  @override
  void initState() {
    super.initState();
    _readConfig();
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      alignment: FractionalOffset.topCenter,
      constraints: const BoxConstraints.expand(),
      child: new Material(
        child: _customSearchId != null && _apiKey != null
            ? new GoogleSearchImagePicker(
                apiKey: _apiKey,
                customSearchId: _customSearchId,
                query: _queryString,
              )
            : new CircularProgressIndicator(),
      ),
    );
  }
}

/// Main entry point to the image_picker module.
void main() {
  _log('Module started with context: $_context');

  /// Add [ModuleImpl] to this application's outgoing ServiceProvider.
  _context.outgoingServices.addServiceForName(
    (InterfaceRequest<Module> request) {
      _log('Received binding request for Module');
      if (_module != null) {
        _log('Module interface can only be provided once. Rejecting request.');
        request.channel.close();
        return;
      }
      _module = new ModuleImpl()..bind(request);
    },
    Module.serviceName,
  );

  runApp(new MaterialApp(
    title: 'Image Picker',
    home: new HomeScreen(key: _kHomeKey),
    theme: new ThemeData(primarySwatch: Colors.blue),
    debugShowCheckedModeBanner: false,
  ));
}
