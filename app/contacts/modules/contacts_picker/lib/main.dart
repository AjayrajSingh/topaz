// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.schemas.dart/com.fuchsia.contact.dart';
import 'package:lib.schemas.dart/entity_codec.dart';
import 'package:contacts_services/client.dart';

import 'src/widgets/contacts_picker.dart';
import 'stores.dart';

const String _kContactsContentProviderUrl = 'contacts_content_provider';

class _StringCodec extends EntityCodec<String> {
  _StringCodec()
      : super(
          type: 'com.fuchsia.string',
          encode: (String s) => s,
          decode: (String s) => s,
        );
}

/*
  This Module will experiment with the use of the Flutter Flux framework.
  It will be compared to the Contact_List module which also follows a flux-like
  pattern along the lines of unidirectional data flow.
*/
void main() {
  setupLogger(name: 'contacts/contacts_picker');
  ContactsContentProviderServiceClient serviceClient =
      new ContactsContentProviderServiceClient();
  FilterEntityCodec codec = new FilterEntityCodec();
  ModuleDriver module = new ModuleDriver()
    ..start().then((_) {
      log.fine('Contacts picker started...');
    })
    ..connectToAgentService(_kContactsContentProviderUrl, serviceClient)
    ..watch('filter', codec).listen((FilterEntityData filter) async {
      if (filter != null) {
        log.fine('Received new data in link: $filter');
        await updateContactsListAction(
          await serviceClient.getContactList(prefix: filter?.prefix ?? ''),
        );
        await updateFilterAction(filter);
      }
    });

  runApp(
    new MaterialApp(
      home: new ContactsPicker(
        onContactTapped: (ContactItemStore contact) {
          serviceClient.getEntityReference(contact.id).then(
            (String entityReference) {
              module.put(
                'selected_contact',
                entityReference,
                new _StringCodec(),
              );
            },
          );
        },
      ),
    ),
  );
}
