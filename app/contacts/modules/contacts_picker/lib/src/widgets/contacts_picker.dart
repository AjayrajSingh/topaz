// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';

import '../../stores.dart';
import 'contact_item.dart';

/// The UI widget that represents a list of contacts
class ContactsPicker extends StoreWatcher {
  /// Called when a contact is tapped
  final ContactItemCallback onContactTapped;

  /// Creates a new instance of [ContactsPicker]
  ContactsPicker({Key key, this.onContactTapped}) : super(key: key);

  @override
  void initStores(ListenToStore listenToStore) {
    listenToStore(contactsPickerStoreToken);
  }

  @override
  Widget build(BuildContext context, Map<StoreToken, Store> stores) {
    final ContactsPickerStore pickerStore = stores[contactsPickerStoreToken];

    return new Material(
      child: new ListView(
        children: pickerStore.contacts.map((ContactItemStore contact) {
          return new ContactItem(
            matchedPrefix: pickerStore.prefix,
            contact: contact,
            onTap: onContactTapped,
          );
        }).toList(),
      ),
    );
  }
}
