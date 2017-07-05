// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.maxwell.lib.dart/decomposition.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.surface/surface.fidl.dart';
import 'package:lib.widgets/modular.dart';

const String _kContextLinkName = 'hotel_context';
const String _kHotelContextTopic = 'hotel';
const String _kHotelType = 'http://types.fuchsia.io/hotel';
const String _kHotelName = 'The Loft SF';
const String _kHotelRoomServiceId = '6gmwxUTc0IFMnyZCepWs8J';
const String _kBookingLinkName = 'booking';

/// The Modular Model for the Hotel Confirmation module.
class HotelConfirmationModuleModel extends ModuleModel {
  final LinkProxy _contextLink = new LinkProxy();

  LinkProxy _bookingLink;

  final ModuleControllerProxy _bookingModuleController =
      new ModuleControllerProxy();

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    // Setup the Context Link and publish hotel context
    moduleContext.getLink(_kContextLinkName, _contextLink.ctrl.request());
    Map<String, dynamic> contextLinkData = <String, dynamic>{
      '@context': <String, dynamic>{
        'topic': _kHotelContextTopic,
      },
      '@type': _kHotelType,
      'name': _kHotelName,
    };
    _contextLink.set(null, JSON.encode(contextLinkData));
  }

  /// Open up the manage booking portal
  void manageBooking() {
    Uri arg = new Uri(
      scheme: 'spotify',
      host: 'album',
      pathSegments: <String>[_kHotelRoomServiceId],
    );
    String data = JSON.encode(<String, dynamic>{'view': decomposeUri(arg)});

    if (_bookingLink == null) {
      _bookingLink = new LinkProxy();
      moduleContext.getLink(_kBookingLinkName, _bookingLink.ctrl.request());
      _bookingLink.set(null, data);
      moduleContext.startModuleInShell(
        'Hotel Room Service',
        'file:///system/apps/music_album',
        _kBookingLinkName,
        null, // outgoingServices,
        null, // incomingServices,
        _bookingModuleController.ctrl.request(),
        new SurfaceRelation()..arrangement = SurfaceArrangement.sequential,
        true, // focused
      );
    }
    _bookingModuleController.focus();
  }
}
