// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:topaz.app.contacts.services/contacts_content_provider.fidl.dart'
    as contacts_fidl;

import '../../stores.dart';

const String _kContactsContentProviderUrl = 'contacts_content_provider';

/// The module model
class ContactsPickerModuleModel extends ModuleModel {
  final contacts_fidl.ContactsContentProviderProxy _contactsContentProvider =
      new contacts_fidl.ContactsContentProviderProxy();
  final AgentControllerProxy _contactsContentProviderController =
      new AgentControllerProxy();

  /// Creates an instance of a [ContactsPickerModuleModel]
  ContactsPickerModuleModel();

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
  ) async {
    super.onReady(moduleContext, link);
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
  }

  @override
  void onStop() {
    // Close the connection so that the agent knows that this module is no
    // longer using it
    _contactsContentProviderController.ctrl.close();
    _contactsContentProvider.ctrl.close();
    super.onStop();
  }

  @override
  Future<Null> onNotify(String json) async {
    LinkData linkData;
    try {
      linkData = new LinkData.fromJson(json);
    } on Exception catch (e, stackTrace) {
      log.severe('Failed to create LinkData.', e, stackTrace);
      return;
    }

    // TODO(youngseokyoon): only update the contacts when the link data is
    // different from the previously known one.
    List<ContactItemStore> contacts = await getContactList(linkData);
    await updateContactsListAction(contacts);
    await updatePrefixAction(linkData.prefix);
  }

  /// Call the content provider to retrieve the list of contacts
  Future<List<ContactItemStore>> getContactList(LinkData linkData) async {
    List<ContactItemStore> contactList = <ContactItemStore>[];
    Completer<contacts_fidl.Status> statusCompleter =
        new Completer<contacts_fidl.Status>();
    _contactsContentProvider.getContactList(
      linkData.prefix,
      null,
      (contacts_fidl.Status status, List<contacts_fidl.Contact> contacts) {
        contactList.addAll(
          contacts.map(
            (contacts_fidl.Contact c) {
              return _transformContact(c, linkData.detailType, linkData.prefix);
            },
          ),
        );
        statusCompleter.complete(status);
      },
    );

    contacts_fidl.Status status = await statusCompleter.future;
    if (status != contacts_fidl.Status.ok) {
      log.severe('${contacts_fidl.ContactsContentProvider.serviceName}'
          '::GetContactList() threw an error');

      // TODO(meiyili) SO-731, SO-732: throw error to notify UI
      return null;
    }

    return contactList;
  }

  /// Transform a FIDL Contact object into a ContactItemStore
  ContactItemStore _transformContact(
    contacts_fidl.Contact c,
    DetailType detailType,
    String prefix,
  ) {
    // TODO(meiyili): change how emails and phone numbers are stored and update
    // to handle the "custom" detail type as well
    String detail = '';
    if (detailType == DetailType.email && c.emails.isNotEmpty) {
      detail = c.emails[0].value;
    } else if (detailType == DetailType.phoneNumber &&
        c.phoneNumbers.isNotEmpty) {
      detail = c.phoneNumbers[0].value;
    }

    List<String> nameComponents = <String>[c.displayName];
    bool isMatchedOnName = false;
    int matchedNameIndex = -1;
    for (int i = 0; i < nameComponents.length; i++) {
      if (nameComponents[i].toLowerCase().startsWith(prefix)) {
        isMatchedOnName = true;
        matchedNameIndex = i;
      }
    }

    return new ContactItemStore(
      id: c.contactId,
      names: nameComponents,
      detail: detail,
      photoUrl: c.photoUrl,
      isMatchedOnName: isMatchedOnName,
      matchedNameIndex: matchedNameIndex,
    );
  }

  /// Handle the contact tap event and write the selected contact in the Link.
  void handleContactTapped(ContactItemStore contact) {
    _contactsContentProvider.getEntityReference(
      contact.id,
      (contacts_fidl.Status status, String entityReference) {
        if (status != contacts_fidl.Status.ok) {
          log.severe('Failed to get entity reference for contact ${contact.id}:'
              ' (status: $status)');
          return;
        }

        // Set the result in the Link.
        // TODO: Use an output noun instead.
        link.set(
          const <String>['selectedContact'],
          JSON.encode(entityReference),
        );
      },
    );
  }
}
