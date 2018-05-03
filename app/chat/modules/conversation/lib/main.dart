// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_models/chat_models.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/conversation_module_model.dart';
import 'src/modular/conversation_screen.dart';

void main() {
  setupLogger(name: 'chat/conversation');

  UserModel userModel = new UserModel();

  ModuleWidget<ChatConversationModuleModel> moduleWidget =
      new ModuleWidget<ChatConversationModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new ChatConversationModuleModel(userModel: userModel),
    child: new ScopedModel<UserModel>(
      model: userModel,
      child: const ChatConversationScreen(),
    ),
  )..advertise();

  runApp(moduleWidget);
}
