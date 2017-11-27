// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'contact_item.dart';

/// The action to search the contacts store with a given prefix
typedef void SearchContactsAction(String prefix);

/// The action to clear the search results
typedef void ClearSearchResultsAction();

/// The function that will be called when a contact is tapped
typedef void ContactTappedAction(ContactItem contact);

/// The action to refresh the list of contacts
typedef void RefreshContactsAction();
