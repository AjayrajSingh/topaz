// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../models.dart';

/// Common Type Definitions

/// Callback function signature for an action on a Contact
typedef void ContactActionCallback(Contact contact);

/// Callback function signature for an action on a PhoneEntry
typedef void PhoneNumberActionCallback(PhoneNumber phone);

/// Callback function signature for an action on a EmailEntry
typedef void EmailAddressActionCallback(EmailAddress email);

/// Callback function signature for an action on a AddressEntry
typedef void AddressActionCallback(Address address);
