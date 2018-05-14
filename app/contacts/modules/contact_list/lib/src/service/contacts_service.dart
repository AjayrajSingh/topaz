// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json;

import 'package:contacts_services/client.dart';
import 'package:fidl_contacts_content_provider/fidl.dart'
    as contacts_fidl;
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:meta/meta.dart';

import '../../models.dart';

/// Call back definition for [ContactsService]'s subscribe method.
typedef void OnSubscribeCallback(List<ContactItem> newContactList);

/// A call to update a link specified by [name] with new [data].
typedef void UpdateLink(String name, String data);

class _ContactListResponse {
  final contacts_fidl.Status status;
  final List<contacts_fidl.Contact> contacts;

  /// Constructor
  _ContactListResponse({
    @required this.status,
    @required this.contacts,
  })  : assert(status != null),
        assert(contacts != null);
}

/// The [ContactsService] for interacting with the contacts services and
/// updating the model
class ContactsService {
  /// Future for the message queue token that will be used to subscribe to
  /// receiving updates from the content provider
  Future<String> messageQueueToken;

  /// The [ContactsContentProviderServiceClient] for interacting with the
  /// contacts provider service
  final ContactsContentProviderServiceClient client;

  /// The [ContactListModel] that serves as the data store for the UI and
  /// contains the behaviors that users can use to mutate the data
  final ContactListModel model;

  /// Future containing the link client to write the selected contact to
  final Future<LinkClient> _linkClient;

  /// Creates an instance of a [ContactsService] and takes a
  /// [ContactListModel] that it will keep updated.
  ContactsService({
    @required this.client,
    @required this.model,
    @required Future<LinkClient> linkClientFuture,
  })  : assert(client != null),
        assert(model != null),
        assert(linkClientFuture != null),
        _linkClient = linkClientFuture;

  /// Search the contacts store with the given prefix and then update the model
  Future<Null> searchContacts(String prefix) async {
    // TODO(meiyili) SO-731, SO-732: handle errors
    model.searchResults = await _getContactList(prefix: prefix);
  }

  /// Handle refreshing the user's contact list
  Future<Null> refreshContacts() async {
    model.contacts = await _getContactList(refresh: true);
  }

  /// Get the initial list of contacts
  Future<Null> getInitialContactList(String messageQueueToken) async {
    await _getContactList(token: messageQueueToken);
  }

  /// Call the content provider to retrieve the list of contacts
  Future<List<ContactItem>> _getContactList({
    String prefix: '',
    bool refresh: false,
    String token,
  }) async {
    List<ContactItem> contactList = <ContactItem>[];
    Completer<_ContactListResponse> responseCompleter =
        new Completer<_ContactListResponse>();

    List<contacts_fidl.Contact> contacts;
    if (refresh) {
      contacts = await client.refreshContacts();
    } else {
      if (token == null || token.isEmpty) {
        contacts = await client.getContactList(prefix: prefix);
      } else {
        contacts = await client.getContactList(
          prefix: prefix,
          messageQueueToken: token,
        );
      }
    }
    model.contacts = contacts.map(_transformContact).toList();

    _ContactListResponse response = await responseCompleter.future;
    if (response.status != contacts_fidl.Status.ok) {
      log.severe('${contacts_fidl.ContactsContentProvider.$serviceName}'
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
  Future<Null> onContactTapped(ContactItem contact) async {
    try {
      // Make a request to get the entity reference
      String entityReference = await client.getEntityReference(contact.id);
      log.fine('Link set: contact_entity_reference to $entityReference, '
          'contact id to ${contact.id}');
      LinkClient link = await _linkClient;
      await link.setEntity(entityReference);
    } on Exception catch (err, stackTrace) {
      log.warning('Error retrieving entity reference: $err, $stackTrace');
    }
  }

  /// Transform a FIDL Contact object into a ContactItem
  ContactItem _transformContact(contacts_fidl.Contact c) => new ContactItem(
        id: c.contactId,
        displayName: c.displayName,
        photoUrl: c.photoUrl,
      );

  /// Handle messages received on the message queue
  void handleUpdate(String data, void ack()) {
    ack();

    Map<String, dynamic> updates = json.decode(data);
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
