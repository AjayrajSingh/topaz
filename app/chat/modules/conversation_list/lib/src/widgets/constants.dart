// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Background color to be used for the selected conversaion in the conversation
/// list.
final Color kSelectedBgColor = Color.lerp(Colors.white, Colors.blue[200], 0.2);

/// New chat conversation form: title
const String kNewChatFormTitle = 'New Chat';

/// New chat conversation form: hint text for the text field
const String kNewChatFormHintText = 'Enter email';

/// New chat conversation form: cancel button text
const String kNewChatFormCancel = 'CANCEL';

/// New chat conversation form: submit button text
const String kNewChatFormSubmit = 'OK';
