// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:fuchsia.fidl.contacts_content_provider/contacts_content_provider.dart'
    as fidl;

/// Client wrapper class for the [fidl.ContactsContentProvider] service
class ContactsContentProviderServiceClient
    extends ServiceClient<fidl.ContactsContentProvider> {
  fidl.ContactsContentProviderProxy _proxy;

  /// Create a new instance of [ContactsContentProviderServiceClient]
  ContactsContentProviderServiceClient()
      : super(new fidl.ContactsContentProviderProxy()) {
    // Keep a reference here that contains the service interface information
    _proxy = super.proxy;
  }

  /// Get the list of [fidl.Contact]s.
  ///
  /// [prefix] allows the caller to specify a prefix to filter the contact
  /// information on.
  ///
  /// [messageQueueToken] allows the caller to pass along a message queue to
  /// subscribe to updates to the contacts list.
  Future<List<fidl.Contact>> getContactList({
    String prefix = '',
    String messageQueueToken,
  }) {
    Completer<List<fidl.Contact>> completer =
        new Completer<List<fidl.Contact>>();

    try {
      _proxy.getContactList(
        prefix,
        messageQueueToken,
        (fidl.Status status, List<fidl.Contact> contacts) {
          if (status == fidl.Status.ok) {
            completer.complete(contacts);
          } else {
            completer.completeError(status);
          }
        },
      );
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// Retrieves the entity reference for a [fidl.Contact] with id [contactId]
  Future<String> getEntityReference(String contactId) {
    Completer<String> completer = new Completer<String>();

    try {
      _proxy.getEntityReference(
        contactId,
        (fidl.Status status, String entityReference) {
          if (status == fidl.Status.ok) {
            completer.complete(entityReference);
          } else {
            completer.completeError(status);
          }
        },
      );
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// Force a request to retrieve the latest contacts from the cloud
  Future<List<fidl.Contact>> refreshContacts() {
    Completer<List<fidl.Contact>> completer =
        new Completer<List<fidl.Contact>>();

    try {
      _proxy.refreshContacts((fidl.Status status, List<fidl.Contact> contacts) {
        if (status == fidl.Status.ok) {
          completer.complete(contacts);
        } else {
          completer.completeError(status);
        }
      });
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }
}
