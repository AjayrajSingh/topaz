// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: always_specify_types
// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert' show json;

import 'package:fidl_bluetooth/fidl.dart' as bt;
import 'package:fidl_bluetooth_low_energy/fidl.dart' as ble;
import 'package:fidl_modular/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.proposal.dart/proposal.dart';
import 'package:web_view/web_view.dart' as web_view;

final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

final ble.CentralDelegateBinding _delegateBinding =
    new ble.CentralDelegateBinding();
final ble.CentralProxy _central = new ble.CentralProxy();

const String kEddystoneUuid = '0000feaa-0000-1000-8000-00805f9b34fb';

final Set<String> proposed = new Set<String>();

Future<Null> proposeUrl(String url) async {
  // TODO(jamuraa): resolve this URL for a title or more info?
  // TODO(jamuraa): add icon for eddystone / physicalweb
  log.info('Proposing URL: $url');
  _proposalPublisher.propose(await createProposal(
    id: 'Eddystone-URL: $url',
    confidence: 0.0,
    headline: 'Open nearby webpage',
    subheadline: '$url',
    details: 'Eddystone nearby webpage detected',
    color: 0xFF0000FF,
    actions: <Action>[
      new Action.withCreateStory(
        new CreateStory(
          moduleId: web_view.kWebViewURL,
          initialData: json.encode(
            {
              'view': {
                'uri': url,
              }
            },
          ),
        ),
      )
    ],
  ));
}

String toHexString(final Iterable<int> data) {
  return data
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}

String decodeEddystoneURL(Iterable<int> encoded) {
  if (encoded.length < 2) {
    return null;
  }
  const Map<int, String> prefixes = const {
    0: 'http://www.',
    1: 'https://www.',
    2: 'http://',
    3: 'https://',
  };
  const Map<int, String> expansions = const {
    0: '.com/',
    1: '.org/',
    2: '.edu/',
    3: '.net/',
    4: '.info/',
    5: '.biz/',
    6: '.gov/',
    7: '.com',
    8: '.org',
    9: '.edu',
    10: '.net',
    11: '.info',
    12: '.biz',
    13: '.gov',
  };
  String decoded = prefixes[encoded.first];
  if (decoded == null) {
    log.warning('Eddystone-URL has invalid scheme: ${encoded.first}');
    return null;
  }
  StringBuffer buffer = new StringBuffer(decoded);
  for (final int c in encoded.skip(1)) {
    if ((c < 0x20) || (c > 0x7F)) {
      buffer.write(expansions[c]);
    } else {
      buffer.write(new String.fromCharCode(c));
    }
  }
  return buffer.toString();
}

class EddystoneScanner implements ble.CentralDelegate {
  int _delayMinutes = 1;

  void start(ble.Central central) {
    ble.ScanFilter filter =
        const ble.ScanFilter(serviceUuids: const [kEddystoneUuid]);
    log.info('BLE starting scan for Eddystone beacons');
    central.startScan(filter, (bt.Status status) {
      if (status.error != null) {
        log.warning(
            'BLE scan start failed: ${status.error.description}, retry in $_delayMinutes mins');
        new Timer(new Duration(minutes: _delayMinutes), () => start(_central));
        _delayMinutes *= 2;
        if (_delayMinutes > 60) {
          _delayMinutes = 60;
        }
      }
    });
  }

  // ble.CentralDelegate overrides:
  @override
  // ignore: avoid_positional_boolean_parameters
  void onScanStateChanged(bool scanning) {
    log.info('BLE adapter scan state changed: $scanning');
    if (!scanning) {
      _delayMinutes = 1;
      start(_central);
    }
  }

  @override
  void onDeviceDiscovered(ble.RemoteDevice device) {
    ble.AdvertisingData ad = device.advertisingData;
    for (final ble.ServiceDataEntry entry in ad.serviceData) {
      if (entry.uuid != kEddystoneUuid) {
        log.info('Not Eddystone: $entry.uuid');
        return;
      }
      if (entry.data.length < 4) {
        log.warning('invalid Eddystone format, dropping');
        return;
      }
      if (entry.data[0] == 0x10) {
        // Eddystone-URL
        String url =
            decodeEddystoneURL(entry.data.getRange(2, entry.data.length));
        if (url != null && !proposed.contains(url)) {
          proposed.add(url);
          proposeUrl(url);
        }
      }
    }
  }

  // We never connect to any peripherals so this implementation does nothing.
  @override
  void onPeripheralDisconnected(String id) {}
}

Future<Null> main(List<dynamic> args) async {
  setupLogger(name: 'Eddystone Agent');

  log.info('Agent starting');

  // ignore: unawaited_futures
  _central.ctrl.error
      .then((proxyerror) => log.warning('BLE Central: $proxyerror'));

  connectToService(_context.environmentServices, _proposalPublisher.ctrl);
  connectToService(_context.environmentServices, _central.ctrl);

  var scanner = new EddystoneScanner();
  _central.setDelegate(_delegateBinding.wrap(scanner));

  scanner.start(_central);
}
