// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.bluetooth.fidl/common.fidl.dart' as bt;
import 'package:lib.bluetooth.fidl/low_energy.fidl.dart' as ble;
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

/// The [ModuleModel] for the Eddystone advertiser example.
class EddystoneModuleModel extends ModuleModel {
  // Members that maintain the FIDL service connections.
  final ble.PeripheralProxy _peripheral = new ble.PeripheralProxy();

  // The set of advertisements that we're adveertising. Maps url => id
  final Map<String, String> _activeAdvertisements = {};

  static const String kEddystoneUuid = '0000feaa-0000-1000-8000-00805f9b34fb';

  /// Constructor
  EddystoneModuleModel(this.applicationContext) : super();

  /// We use the |applicationContext| to obtain a handle to the "bluetooth::low_energy::Central"
  /// environment service.
  final ApplicationContext applicationContext;

  /// True if we have an active scan session.
  bool get isAdvertising => _activeAdvertisements.isNotEmpty;

  Iterable<String> get advertisedUrls => _activeAdvertisements.keys;

  /// Advertises a URL, if possible.
  Future<String> startAdvertising(String url) {
    Completer completer = new Completer();
    ble.AdvertisingData data = new ble.AdvertisingData();
    log.info('Advertising url: $url');
    data.serviceUuids = [kEddystoneUuid];
    data.serviceData = new Map<String, List<int>>();
    data.serviceData[kEddystoneUuid] = _eddystoneDataForUrl(url);
    _peripheral.startAdvertising(data, null, null, 1000, false,
        (bt.Status status, String advertisementId) {
      log.info('StartAdvertising result: $status with $advertisementId');
      if (status.error != null) {
        completer.completeError(status.error.description);
        return;
      }
      _activeAdvertisements[url] = advertisementId;
      notifyListeners();
      completer.complete(advertisementId);
    });
    return completer.future;
  }

  void stopAdvertising(String url) {
    if (!_activeAdvertisements.containsKey(url)) {
      return;
    }
    _peripheral.stopAdvertising(_activeAdvertisements[url], (bt.Status status) {
      if (status.error != null) {
        log.info('Error stopping advertising for $url: $status');
      }
    });
    _activeAdvertisements.remove(url);
    notifyListeners();
  }

  // ModuleModel overrides:

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    connectToService(applicationContext.environmentServices, _peripheral.ctrl);
  }

  @override
  void onStop() {
    for (final url in _activeAdvertisements.values) {
      stopAdvertising(url);
    }
    super.onStop();
  }

  final Map<String, int> _schemes = const {
    'http://www.': 0,
    'https://www.': 1,
    'http://': 2,
    'https://': 3,
  };

  String validateEddystoneUrl(final String proposed) {
    bool prefixFound = false;
    for (final prefix in _schemes.keys) {
      if (proposed.startsWith(prefix)) {
        prefixFound = true;
      }
    }

    if (!prefixFound) {
      return 'URL must start with http(s)://';
    }

    List<int> encoded = _eddystoneDataForUrl(proposed);
    if (encoded.length > 20) {
      return 'URL too long.';
    }

    return null;
  }

  List<int> _eddystoneDataForUrl(final String url) {
    List<int> result = [];

    // Eddystone header
    result.add(0x10); // Frame type (Eddystone-URL)
    result.add(0x12); // Faked tx-power (18dBm)
    String left = url;
    // Scheme

    final Map<String, int> expansions = const {
      '.com/': 0,
      '.org/': 1,
      '.edu/': 2,
      '.net/': 3,
      '.info/': 4,
      '.biz/': 5,
      '.gov/': 6,
      '.com': 7,
      '.org': 8,
      '.edu': 9,
      '.net': 10,
      '.info': 11,
      '.biz': 12,
      '.gov': 13,
    };

    for (final prefix in _schemes.keys) {
      if (left.startsWith(prefix)) {
        left = left.substring(prefix.length);
        result.add(_schemes[prefix]);
      }
    }

    while (left.length > 0) {
      bool compacted = false;
      for (final str in expansions.keys) {
        if (left.startsWith(str)) {
          result.add(expansions[str]);
          left = left.substring(str.length);
          compacted = true;
          break;
        }
      }
      if (compacted) continue;
      result.add(left.codeUnitAt(0));
      left = left.substring(1);
    }

    return result;
  }
}
