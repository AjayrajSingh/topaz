// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:fuchsia.fidl.music_configuration/music_configuration.dart';

import 'modular/artist_module_model.dart';
import 'modular/artist_module_screen.dart';
import 'run_mod.dart';

const String _kSpotifyClientSecretKey = 'spotify_client_secret';
const String _kSppotifyClientIdKey = 'spotify_client_id';

ModuleDriver _driver;

void main() {
  setupLogger();

  _driver = new ModuleDriver()..start();

  Completer<Widget> initializedModuleView = runModuleScaffoldAsync();

  _connectToConfigAgent().then(_fetchConfigKeys).then(_buildModuleWidget).then(
      initializedModuleView.complete,
      onError: initializedModuleView.completeError);
}

Future<MusicConfigurationProviderProxy> _connectToConfigAgent() async {
  final MusicConfigurationProviderProxy configProxy =
      new MusicConfigurationProviderProxy();

  await _driver.connectToAgentServiceWithProxy(
    'music_configuration_agent',
    configProxy,
  );

  return configProxy;
}

Future<Map<String, String>> _fetchConfigKeys(
    MusicConfigurationProviderProxy proxy) async {
  List<String> values = await Future.wait(
    <Future<String>>[
      _getApiKey(
        proxy: proxy,
        key: _kSppotifyClientIdKey,
      ),
      _getApiKey(
        proxy: proxy,
        key: _kSpotifyClientSecretKey,
      ),
    ],
  );

  return <String, String>{
    _kSppotifyClientIdKey: values[0],
    _kSpotifyClientSecretKey: values[1],
  };
}

Widget _buildModuleWidget(Map<String, String> keys) {
  String spotifyClientId = keys[_kSppotifyClientIdKey];
  String spotifyClientSecret = keys[_kSpotifyClientSecretKey];

  ArtistModuleModel model = new ArtistModuleModel(
    clientId: spotifyClientId,
    clientSecret: spotifyClientSecret,
  );

  ModuleWidget<ArtistModuleModel> moduleWidget =
      new ModuleWidget<ArtistModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: model,
    child: const ArtistModuleScreen(),
  )..advertise();

  return moduleWidget;
}

Future<String> _getApiKey({
  String key,
  MusicConfigurationProviderProxy proxy,
}) async {
  Completer<String> c = new Completer<String>();
  proxy.get(key, c.complete);
  return c.future;
}
