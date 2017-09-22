// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.contacts.services/contacts_content_provider.fidl.dart'
    as contacts_fidl;

import '../../models.dart';

const String _kContactsContentProviderUrl =
    'file:///system/apps/contacts_content_provider';

/// Call back definition for [ContactListModuleModel]'s subscribe method.
typedef void OnSubscribeCallback(List<ContactListItem> newContactList);

/// The [ModuleModel] for the contacts module set.
class ContactListModuleModel extends ModuleModel {
  final contacts_fidl.ContactsContentProviderProxy _contactsContentProvider =
      new contacts_fidl.ContactsContentProviderProxy();
  final AgentControllerProxy _contactsContentProviderController =
      new AgentControllerProxy();

  /// The [ContactListModel] that serves as the data store for the UI and
  /// contains the behaviors that users can use to mutate the data
  final ContactListModel model;

  /// Creates an instance of a [ContactListModuleModel] and takes a
  /// [ContactListModel] that it will keep updated.
  ContactListModuleModel({@required this.model}) {
    assert(model != null);
  }

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) async {
    super.onReady(moduleContext, link, incomingServices);
    log.fine('ModuleModel::onReady call');

    // Obtain the component context
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());

    // Connect to ContactsContentProvider service
    ServiceProviderProxy contentProviderServices = new ServiceProviderProxy();
    componentContext.connectToAgent(
      _kContactsContentProviderUrl,
      contentProviderServices.ctrl.request(),
      _contactsContentProviderController.ctrl.request(),
    );
    connectToService(contentProviderServices, _contactsContentProvider.ctrl);

    // Close all unnecessary bindings
    contentProviderServices.ctrl.close();
    componentContext.ctrl.close();

    // Fetch the contacts list
    model.contactList = await getContactList();
  }

  @override
  void onStop() {
    // Close the connection so that the agent knows that this module is no
    // longer using it
    _contactsContentProviderController.ctrl.close();
    super.onStop();
  }

  /// Call the content provider to retrieve the list of contacts
  Future<List<ContactListItem>> getContactList({String prefix = ''}) async {
    List<ContactListItem> contactList = <ContactListItem>[];
    Completer<contacts_fidl.Status> statusCompleter =
        new Completer<contacts_fidl.Status>();
    _contactsContentProvider.getContactList(prefix,
        (contacts_fidl.Status status, List<contacts_fidl.Contact> contacts) {
      contacts.forEach(
          (contacts_fidl.Contact c) => contactList.add(_transformContact(c)));
      statusCompleter.complete(status);
    });

    contacts_fidl.Status status = await statusCompleter.future;
    if (status != contacts_fidl.Status.ok) {
      log.severe('${contacts_fidl.ContactsContentProvider.serviceName}'
          '::GetContactList() threw an error');

      // TODO(meiyili) SO-731, SO-732: throw error to notify UI
      return null;
    }

    return contactList;
  }

  /// Transform a FIDL Contact object into a ContactListItem
  ContactListItem _transformContact(contacts_fidl.Contact c) =>
      new ContactListItem(
        id: c.googleContactId,
        displayName: c.displayName,
        photoUrl: c.photoUrl,
      );
}
