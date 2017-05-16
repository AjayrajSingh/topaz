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
  bool _networkingReady;
  @override
  void initState() {
    super.initState();

    /// TODO(apwilson): Reenable this code when it doesn't blow the app up.
    /*
    NetworkInterface.list().then((List<NetworkInterface> interfaces) {
      if (!mounted) {
        return;
      }
      setState(() {
        interfaces.forEach((NetworkInterface networkInterface) {
          _addresses.addAll(networkInterface.addresses);
        });
      });
    });
    */

    _checkData();
    _checkNetworking();
  }

  void _checkData() {
    new Directory('file:///data').stat().then((FileStat stat) {
      setState(() {
        if (!mounted) {
          return;
        }
        _dataSize = stat.size;
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
        }
      });
    }).catchError((_, __) {
      new Timer(const Duration(seconds: 5), _checkNetworking);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> columnChildren = <String>[];
    if (_dataSize == null) {
      columnChildren.add('Data is NOT ready!');
    } else if (_dataSize == 0) {
      columnChildren.add('Data is NOT persistant!');
    }

    if (_networkingReady != true) {
      columnChildren.add('Networking is NOT ready!');
    }

    columnChildren.addAll(
      _addresses.map((InternetAddress address) => address.address).toList(),
    );
    columnChildren.add(Platform.localHostname);
    return new Column(
        mainAxisSize: MainAxisSize.min,
        children: columnChildren
            .map(
              (String text) => new Container(
                    padding: const EdgeInsets.all(12.0),
                    color: Colors.black54,
                    child: new Text(
                      text,
                      style: new TextStyle(
                        fontFamily: 'RobotoMono',
                        color: Colors.white,
                      ),
                    ),
                  ),
            )
            .toList());
  }
}
