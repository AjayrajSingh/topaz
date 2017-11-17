// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:entity_schemas/entities.dart' as entities;

import '../models/contact_card_model.dart';
import 'link_data.dart';

/// The model for the contact card module
class ContactCardModuleModel extends ModuleModel {
  /// The data store for the module
  final ContactCardModel model;

  /// Instantiate new [ContactCardModuleModel] with a data store
  ContactCardModuleModel({@required this.model}) : assert(model != null);

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
  ) {
    super.onReady(moduleContext, link);
    log.fine('ContactCardModuleModel onReady');
  }

  @override
  Future<Null> onNotify(String json) async {
    log.fine('ContactCardModuleModel received link data $json');
    LinkData linkData = new LinkData.fromJson(json);
    if (linkData != null) {
      entities.Contact contact = _resolveEntity(linkData.entityReference);
      model.contact = contact;
    } else {
      log.warning('Malformed link data $json');
    }
  }

  @override
  void onStop() {
    log.fine('ContactCardModuleModel onStop');
  }

  entities.Contact _resolveEntity(String entityReference) {
    // TODO(meiyili): integrate with entity resolver SO-979
    log.fine('Trying to resolve entity reference $entityReference');
    return new entities.Contact(
      displayName: 'Aparna Neilsen',
      id: '123',
      photoUrl: 'http://www.galaxycorgipuppies.com/img/products/coobee.jpg',
      emailAddresses: <entities.EmailAddress>[
        new entities.EmailAddress(
          value: 'aparna_nielsen@example.com',
          label: 'personal',
        ),
        new entities.EmailAddress(value: 'aparna_n@example.com', label: 'work')
      ],
      phoneNumbers: <entities.PhoneNumber>[
        new entities.PhoneNumber(number: '(312) 800-2342', label: 'mobile')
      ],
    );
  }
}
