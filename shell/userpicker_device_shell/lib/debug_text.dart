// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Displays debug text like hostname and ip addresses.
class DebugText extends StatefulWidget {
  @override
  _DebugTextState createState() => new _DebugTextState();
}

class _DebugTextState extends State<DebugText> {
  final List<InternetAddress> _addresses = <InternetAddress>[];
  int _dataSize;
  bool _networkingReady = false;
  bool _showHostInformation = true;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    new Timer(
      const Duration(seconds: 11),
      () => setState(() {
            _ready = true;
            new Timer(
              const Duration(minutes: 1),
              () => setState(() {
                    _showHostInformation = false;
                  }),
            );
          }),
    );

    _checkNetworking();
    _checkData();
  }

  void _checkData() {
    new Directory('/data').stat().then((FileStat stat) {
      setState(() {
        if (!mounted) {
          return;
        }
        _dataSize = stat.size;
        if (_dataSize == 0) {
          new Timer(const Duration(seconds: 5), _checkData);
        }
      });
    }).catchError((_, __) {
      new Timer(const Duration(seconds: 5), _checkData);
    });
  }

  void _checkNetworking() {
    http.get('http://www.example.com').then((http.Response response) {
      setState(() {
        if (!mounted) {
          return;
        }
        _networkingReady = response.statusCode == 200;
        if (!_networkingReady) {
          new Timer(const Duration(seconds: 5), _checkNetworking);
        } else {
          NetworkInterface.list().then((List<NetworkInterface> interfaces) {
            if (!mounted) {
              return;
            }
            setState(() {
              for (NetworkInterface networkInterface in interfaces) {
                _addresses.addAll(networkInterface.addresses);
              }
            });
          });
        }
      });
    }).catchError((_, __) {
      new Timer(const Duration(seconds: 5), _checkNetworking);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<_DebugEntry> columnChildren = <_DebugEntry>[];
    if (_ready && _showHostInformation) {
      columnChildren
        ..add(new _DebugEntry(text: Platform.localHostname))
        ..addAll(
          _addresses
              .map(
                (InternetAddress address) =>
                    new _DebugEntry(text: address.address),
              )
              .toList(),
        );
    }

    if (_ready && !_networkingReady) {
      columnChildren.add(
        new _DebugEntry(
          text: 'Networking is NOT ready!',
          color: Colors.redAccent,
        ),
      );
    }

    if (_ready) {
      if (_dataSize == null) {
        columnChildren.add(
          new _DebugEntry(text: 'Data is NOT ready!', color: Colors.yellow),
        );
      } else if (_dataSize == 0) {
        columnChildren.add(
          new _DebugEntry(
            text: 'Data is NOT persistent!',
            color: Colors.redAccent,
          ),
        );
      }
    }

    return new Offstage(
      offstage: columnChildren.isEmpty,
      child: new Container(
        margin: const EdgeInsets.all(8.0),
        child: new PhysicalModel(
          color: Colors.grey[900],
          elevation: 799.0, // Mouse pointer is at 800.0
          borderRadius: new BorderRadius.circular(8.0),
          child: new Container(
            padding: const EdgeInsets.all(8.0),
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: new List<Widget>.generate(
                columnChildren.length,
                (int i) => new Container(
                      padding: new EdgeInsets.only(top: (i == 0) ? 0.0 : 8.0),
                      child: new Text(
                        columnChildren[i].text,
                        style: new TextStyle(
                          fontFamily: 'RobotoMono',
                          color: columnChildren[i].color,
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugEntry {
  final Color color;
  final String text;
  _DebugEntry({this.text, this.color: Colors.white});
}
