// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';

import '../../stores.dart';

/// The UI widget that represents a list of contacts
class ContactsPicker extends StoreWatcher {
  /// Creates a new instance of [ContactsPicker]
  ContactsPicker({Key key}) : super(key: key);

  @override
  void initStores(ListenToStore listenToStore) {
    listenToStore(contactsPickerStoreToken);
  }

  @override
  Widget build(BuildContext context, Map<StoreToken, Store> stores) {
    final ContactsPickerStore pickerStore = stores[contactsPickerStoreToken];

    return new Material(
      child: new ListView(
        children: pickerStore.contacts.map((ContactListItem contact) {
          return new Row(
            children: <Widget>[
              new Text(contact.displayName),
              new Text(' - ${contact.detail}'),
            ],
          );
        }).toList(),
      ),
    );
  }
}
