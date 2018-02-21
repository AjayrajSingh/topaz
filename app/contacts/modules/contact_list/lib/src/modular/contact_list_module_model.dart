// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.component.fidl/message_queue.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.module.fidl._module_controller/module_controller.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.contacts.services/contacts_content_provider.fidl.dart'
    as contacts_fidl;

import '../../models.dart';

const String _kContactsContentProviderUrl = 'contacts_content_provider';
const String _kContactCardModuleUrl = 'contact_card';
const String _kContactsUpdateQueue = 'contacts_update_queue';

/// Call back definition for [ContactListModuleModel]'s subscribe method.
typedef void OnSubscribeCallback(List<ContactItem> newContactList);

class _ContactListResponse {
  final contacts_fidl.Status status;
  final List<contacts_fidl.Contact> contacts;

  /// Constructor
  _ContactListResponse({
    @required this.status,
    @required this.contacts,
  })
      : assert(status != null),
        assert(contacts != null);
}

/// The [ModuleModel] for the contacts module set.
class ContactListModuleModel extends ModuleModel {
  // Proxies for the Contacts Content Provier Agent
  final contacts_fidl.ContactsContentProviderProxy _contactsContentProvider =
      new contacts_fidl.ContactsContentProviderProxy();
  final AgentControllerProxy _contactsContentProviderController =
      new AgentControllerProxy();

  // Proxies for the Contact Card Module
  final ModuleControllerProxy _contactCardModuleController =
      new ModuleControllerProxy();

  // Message queue proxies for receiving updates from the content provider
  final MessageQueueProxy _messageQueue = new MessageQueueProxy();
  MessageReceiverImpl _messageQueueReceiver;
  final Completer<String> _messageQueueToken = new Completer<String>();

  /// The [ContactListModel] that serves as the data store for the UI and
  /// contains the behaviors that users can use to mutate the data
  final ContactListModel model;

  /// Creates an instance of a [ContactListModuleModel] and takes a
  /// [ContactListModel] that it will keep updated.
  ContactListModuleModel({@required this.model}) : assert(model != null);

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

    // Start the contact card module
    _startContactCardModule();

    // Connect to ContactsContentProvider service
    ServiceProviderProxy contentProviderServices = new ServiceProviderProxy();
    componentContext.connectToAgent(
      _kContactsContentProviderUrl,
      contentProviderServices.ctrl.request(),
      _contactsContentProviderController.ctrl.request(),
    );
    connectToService(contentProviderServices, _contactsContentProvider.ctrl);

    // Create a message queue to pass to the content provider agent for updates
    componentContext.obtainMessageQueue(
      _kContactsUpdateQueue,
      _messageQueue.ctrl.request(),
    );

    // Save token to be passed to subscribe call
    _messageQueue.getToken(_messageQueueToken.complete);
    _messageQueueReceiver = new MessageReceiverImpl(
      messageQueue: _messageQueue,
      onReceiveMessage: _onReceiveMessage,
    );

    // Close all unnecessary bindings
    contentProviderServices.ctrl.close();
    componentContext.ctrl.close();

    // Fetch the contacts list and subscribe to updates only after we have
    // gotten the initial results
    model.contacts = await _getContactList();
    moduleContext.ready();
  }

  void _startContactCardModule() {
    moduleContext.startModuleInShell(
      'contact_card',
      _kContactCardModuleUrl,
      null, // Passes default link to the child
      null,
      _contactCardModuleController.ctrl.request(),
      const SurfaceRelation(
        arrangement: SurfaceArrangement.copresent,
        dependency: SurfaceDependency.dependent,
        emphasis: 2.0,
      ),
      false,
    );
  }

  @override
  void onNotify(String json) {
    // TODO (meiyili): read previously selected contact id from link and
    // highlight it SO-996
    log.fine('onNotify called');
  }

  @override
  Future<Null> onStop() async {
    log.fine('onStop called');
    String token = await _messageQueueToken.future;
    _contactsContentProvider.unsubscribe(token);
    _messageQueueReceiver.close();
    _messageQueue.ctrl.close();

    // Close the connection so that the agent knows that this module is no
    // longer using it
    _contactsContentProviderController.ctrl.close();
    _contactsContentProvider.ctrl.close();
    super.onStop();
  }

  /// Search the contacts store with the given prefix and then update the model
  Future<Null> searchContacts(String prefix) async {
    // TODO(meiyili) SO-731, SO-732: handle errors
    model.searchResults = await _getContactList(prefix: prefix);
  }

  /// Handle refreshing the user's contact list
  Future<Null> refreshContacts() async {
    model.contacts = await _getContactList(refresh: true);
  }

  /// Call the content provider to retrieve the list of contacts
  Future<List<ContactItem>> _getContactList({
    String prefix: '',
    bool refresh: false,
  }) async {
    List<ContactItem> contactList = <ContactItem>[];
    Completer<_ContactListResponse> responseCompleter =
        new Completer<_ContactListResponse>();

    if (refresh) {
      _contactsContentProvider.refreshContacts((
        contacts_fidl.Status status,
        List<contacts_fidl.Contact> contacts,
      ) {
        responseCompleter.complete(
            new _ContactListResponse(status: status, contacts: contacts));
      });
    } else {
      String token = await _messageQueueToken.future;
      _contactsContentProvider.getContactList(prefix, token, (
        contacts_fidl.Status status,
        List<contacts_fidl.Contact> contacts,
      ) {
        responseCompleter.complete(new _ContactListResponse(
          status: status,
          contacts: contacts,
        ));
      });
    }

    _ContactListResponse response = await responseCompleter.future;
    if (response.status != contacts_fidl.Status.ok) {
      log.severe('${contacts_fidl.ContactsContentProvider.serviceName}'
          '::threw an error');

      // TODO(meiyili) SO-731, SO-732: throw error to notify UI
      return null;
    } else {
      contactList.addAll(
        response.contacts.map(_transformContact),
      );
      return contactList;
    }
  }

  /// Clears the search results from the model
  void clearSearchResults() {
    model.searchResults = <ContactItem>[];
  }

  /// Handle when a contact is tapped
  void onContactTapped(ContactItem contact) {
    // Make a request to get the entity reference
    _contactsContentProvider.getEntityReference(
      contact.id,
      (contacts_fidl.Status status, String entityReference) {
        if (status == contacts_fidl.Status.ok) {
          // Pass the entity reference to the contact card module via link and
          // save off the contact id for next time the module starts
          log.fine('Link set: contact_entity_reference to $entityReference, '
              'contact id to ${contact.id}');
          link
            ..set(
              const <String>['selected_contact_id'],
              JSON.encode(contact.id),
            )
            ..set(
              const <String>['contact_entity_reference'],
              JSON.encode(entityReference),
            );
        } else {
          // TODO(meiyili): better error handling
          String errorMsg = 'Error retrieving entity reference';
          log.warning(errorMsg);
        }
      },
    );
  }

  /// Transform a FIDL Contact object into a ContactItem
  ContactItem _transformContact(contacts_fidl.Contact c) => new ContactItem(
        id: c.contactId,
        displayName: c.displayName,
        photoUrl: c.photoUrl,
      );

  /// Handle messages received on the message queue
  void _onReceiveMessage(String data, void ack()) {
    ack();

    Map<String, dynamic> updates = JSON.decode(data);
    log.fine('Decoded contact updates = $updates');

    if (updates.containsKey('contact_list')) {
      List<ContactItem> updatedContacts = updates['contact_list']
          .map(_getContactFromJson)
          .where((ContactItem c) => c != null)
          .toList();

      // TODO(meiyili): update search results if we are on the search results
      // view
      model.contacts = updatedContacts;
    }
  }

  ContactItem _getContactFromJson(Map<String, dynamic> json) {
    if (json is Map) {
      return new ContactItem(
          id: json['contactId'],
          displayName: json['displayName'],
          photoUrl: json['photoUrl']);
    } else {
      return null;
    }
  }
}
