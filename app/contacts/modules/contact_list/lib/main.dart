// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts_services/client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/modular.dart';

import 'src/models/contact_list_model.dart';
import 'src/service/contacts_service.dart';
import 'src/widgets/contact_list.dart';

const String _kContactsContentProviderUrl = 'contacts_content_provider';
const String _kContactCardModuleUrl = 'contact_card';
const String _kContactsUpdateQueue = 'contacts_update_queue';
const String _kSelectedContactLinkName = 'selected_contact';
const String _kEmbeddedModLinkName = 'contact';

void main() {
  setupLogger(name: 'contacts/contact_list');

  ModuleControllerClient contactCardController;
  ContactListModel model = new ContactListModel();
  ContactsContentProviderServiceClient contactsServiceClient =
      new ContactsContentProviderServiceClient();

  // Connect to the necessary services and start the contact card module
  IntentBuilder intentBuilder = new IntentBuilder.handler(
      _kContactCardModuleUrl)
    ..addParameterFromLink(_kEmbeddedModLinkName, _kSelectedContactLinkName);

  ModuleDriver driver = new ModuleDriver(onTerminate: () {
    contactsServiceClient.terminate();
    contactCardController?.terminate();
  });

  // Create a message queue in order to receive updates from the agent
  ContactsService contactsService = new ContactsService(
    client: contactsServiceClient,
    model: model,
    linkClientFuture: driver.getLink(_kSelectedContactLinkName),
  );

  driver.start().then((ModuleDriver initializedDriver) async {
    log.fine('Contact list started');
    await initializedDriver.connectToAgentService(
      _kContactsContentProviderUrl,
      contactsServiceClient,
    );

    log.fine('Creating message queue');
    String messageQueueToken = await initializedDriver.createMessageQueue(
      name: _kContactsUpdateQueue,
      onReceive: contactsService.handleUpdate,
    );

    log.fine('Message queue token received: $messageQueueToken');

    // Make initial call to retrieve list of contacts and pass along message queue
    // token to be able to handle updates
    // ignore: unawaited_futures
    contactsService.getInitialContactList(messageQueueToken);

    // Once we get the controller we know the child module instantiation was
    // successful
    contactCardController = await initializedDriver.startModule(
      module: _kContactCardModuleUrl,
      intent: intentBuilder.intent,
      surfaceRelation: const SurfaceRelation(
        arrangement: SurfaceArrangement.copresent,
        dependency: SurfaceDependency.dependent,
        emphasis: 2.0,
      ),
    );
  }).catchError((Object err, StackTrace stackTrace) {
    log.warning('Error starting contact list: $err, $stackTrace');
    model.error = true;
  });

  runApp(
    new MaterialApp(
      home: new ScopedModel<ContactListModel>(
        model: model,
        child: new ContactList(
          onQueryChanged: contactsService.searchContacts,
          onQueryCleared: contactsService.clearSearchResults,
          onContactTapped: contactsService.onContactTapped,
          onRefreshContacts: contactsService.refreshContacts,
        ),
      ),
    ),
  );
}
