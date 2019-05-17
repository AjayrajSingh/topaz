// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:fidl_fuchsia_media/fidl_async.dart' as media;
import 'package:fidl_fuchsia_media_playback/fidl_async.dart' as playback;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_services/services.dart';
import 'package:lib.mediaplayer.flutter/media_player.dart';
import 'package:lib.mediaplayer.flutter/media_player_controller.dart';

import 'asset.dart';
import 'config.dart';

final _context = StartupContext.fromStartupInfo();
final MediaPlayerController _controller =
    MediaPlayerController(_context.incoming);

const List<String> _configFileNames = <String>[
  '/data/mediaplayer_flutter.config',
  '/pkg/data/mediaplayer_flutter.config',
];

List<Asset> _assets = <Asset>[];
Asset _assetToPlay;
Asset _leafAssetToPlay;
int _playlistIndex;

Future<Null> _readConfig() async {
  for (String fileName in _configFileNames) {
    try {
      _assets = await readConfig(fileName);
      return;
      // ignore: avoid_catching_errors
    } on ArgumentError {
      // File doesn't exist. Continue.
    } on FormatException catch (e) {
      print('Failed to parse config $fileName: $e');
      io.exit(0);
      return;
    }
  }

  print('No config file found');
  io.exit(0);
}

/// Plays the specified asset.
void _play(Asset asset) {
  assert(asset != null);

  _assetToPlay = asset;
  _playlistIndex = 0;

  if (_assetToPlay.children != null) {
    assert(_assetToPlay.children.isNotEmpty);
    _playLeafAsset(_assetToPlay.children[0]);
  } else {
    _playLeafAsset(_assetToPlay);
  }
}

/// If [_leafAssetToPlay] is looped, this method seeks to the beginning of the
/// asset and returns true. If [_assetToPlay] is a playlist and hasn't been
/// played through (or is looped), this method plays the next asset in
/// [_assetToPlay] and returns true. Returns false otherwise.
bool _playNext() {
  if (_leafAssetToPlay.loop) {
    // Looping leaf asset. Seek to the beginning.
    _controller.seek(Duration.zero);
    return true;
  }

  if (_assetToPlay == null || _assetToPlay.children == null) {
    return false;
  }

  if (_assetToPlay.children.length <= ++_playlistIndex) {
    if (!_assetToPlay.loop) {
      return false;
    }

    // Looping playlist. Start over.
    _playlistIndex = 0;
  }

  _playLeafAsset(_assetToPlay.children[_playlistIndex]);

  return true;
}

void _playLeafAsset(Asset asset) {
  assert(asset.type != AssetType.playlist);

  _leafAssetToPlay = asset;

  if (_controller.problem?.type == playback.problemConnectionFailed) {
    _controller.close();
  }

  _controller
    ..open(_leafAssetToPlay.uri)
    ..play();
}

/// Screen for asset playback.
class _PlaybackScreen extends StatefulWidget {
  const _PlaybackScreen({Key key}) : super(key: key);

  @override
  _PlaybackScreenState createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<_PlaybackScreen> {
  @override
  void initState() {
    _controller.addListener(_handleControllerChanged);
    super.initState();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  /// Handles change notifications from the controller.
  void _handleControllerChanged() {
    setState(() {
      if (_controller.ended) {
        _playNext();
      }
    });
  }

  /// Adds a label to list [to] if [label] isn't null.
  void _addLabel(String label, Color color, double fontSize, List<Widget> to) {
    if (label == null) {
      return;
    }

    to.add(Container(
      margin: EdgeInsets.only(left: 10.0),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
    ));
  }

  /// Adds a problem description to list [to] if there is a problem.
  void _addProblem(List<Widget> to) {
    playback.Problem problem = _controller.problem;
    if (problem != null) {
      String text;

      if (problem.details != null && problem.details.isNotEmpty) {
        text = problem.details;
      } else {
        switch (problem.type) {
          case playback.problemInternal:
            text = 'Internal error';
            break;
          case playback.problemAssetNotFound:
            text = 'The requested content was not found';
            break;
          case playback.problemContainerNotSupported:
            text = 'The requested content uses an unsupported container format';
            break;
          case playback.problemAudioEncodingNotSupported:
            text = 'The requested content uses an unsupported audio encoding';
            break;
          case playback.problemVideoEncodingNotSupported:
            text = 'The requested content uses an unsupported video encoding';
            break;
          case playback.problemConnectionFailed:
            text = 'Connection to player failed';
            break;
          default:
            text = 'Unrecognized problem type ${problem.type}';
            break;
        }
      }

      _addLabel(text, Colors.white, 20.0, to);

      if (_leafAssetToPlay != null && _leafAssetToPlay.uri != null) {
        _addLabel(_leafAssetToPlay.uri.toString(), Colors.grey[800], 15.0, to);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> columnChildren = <Widget>[
      MediaPlayer(_controller),
    ];

    Map<String, String> metadata = _controller.metadata;
    if (metadata != null) {
      _addLabel(
          metadata[media.metadataLabelTitle] ??
              _leafAssetToPlay.title ??
              '(untitled)',
          Colors.white,
          20.0,
          columnChildren);
      _addLabel(metadata[media.metadataLabelArtist] ?? _leafAssetToPlay.artist,
          Colors.grey[600], 15.0, columnChildren);
      _addLabel(metadata[media.metadataLabelAlbum] ?? _leafAssetToPlay.album,
          Colors.grey[800], 15.0, columnChildren);
    }

    _addProblem(columnChildren);

    return Material(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0.0,
            right: 0.0,
            top: 0.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columnChildren,
            ),
          ),
          Positioned(
            right: 0.0,
            top: 0.0,
            child: Offstage(
              offstage: !_controller.shouldShowControlOverlay,
              child: PhysicalModel(
                elevation: 2.0,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(60.0),
                child: IconButton(
                  icon: Icon(
                      _assets.length == 1 ? Icons.close : Icons.arrow_back),
                  iconSize: 60.0,
                  onPressed: () {
                    if (_assets.length == 1) {
                      io.exit(0);
                      return;
                    }

                    _controller.pause();
                    Navigator.of(context).pop();
                  },
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen for asset selection
class _ChooserScreen extends StatefulWidget {
  const _ChooserScreen({Key key}) : super(key: key);

  @override
  _ChooserScreenState createState() => _ChooserScreenState();
}

class _ChooserScreenState extends State<_ChooserScreen> {
  Widget _buildChooseButton(Asset asset) {
    IconData iconData;

    switch (asset.type) {
      case AssetType.movie:
        iconData = Icons.movie;
        break;
      case AssetType.song:
        iconData = Icons.music_note;
        break;
      case AssetType.playlist:
        iconData = Icons.playlist_play;
        break;
    }

    return RaisedButton(
      onPressed: () {
        _play(asset);
        Navigator.of(context).pushNamed('/play');
      },
      color: Colors.black,
      child: Row(
        children: <Widget>[
          Icon(
            iconData,
            size: 60.0,
            color: Colors.grey[200],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                asset.title ?? '(no title)',
                style: TextStyle(color: Colors.grey[200], fontSize: 18.0),
              ),
              Text(
                asset.artist ?? '',
                style: TextStyle(color: Colors.grey[600], fontSize: 13.0),
              ),
              Text(
                asset.album ?? '',
                style: TextStyle(color: Colors.grey[800], fontSize: 13.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          ListView(
            itemExtent: 75.0,
            children: _assets.map(_buildChooseButton).toList(),
          ),
          Positioned(
            right: 0.0,
            top: 0.0,
            child: PhysicalModel(
              elevation: 2.0,
              color: Colors.transparent,
              child: IconButton(
                icon: Icon(Icons.close),
                iconSize: 60.0,
                onPressed: () {
                  io.exit(0);
                },
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Null> main() async {
  setupLogger(name: 'mediaplayer_flutter Module');
  log.fine('Module started');

  // explicitly opt out of intents
  Module().registerIntentHandler(NoopIntentHandler());

  await _readConfig();

  if (_assets.isEmpty) {
    print('no assets configured');
    return;
  }

  if (_assets.length == 1) {
    _play(_assets[0]);
  }

  runApp(MaterialApp(
    title: 'Media Player',
    home: _assets.length == 1 ? const _PlaybackScreen() : _ChooserScreen(),
    routes: <String, WidgetBuilder>{
      '/play': (BuildContext context) => const _PlaybackScreen()
    },
    theme: ThemeData(primarySwatch: Colors.blue),
    debugShowCheckedModeBanner: false,
  ));
}
