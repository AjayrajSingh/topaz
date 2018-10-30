// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia/services.dart';
import 'package:mockito/mockito.dart';
import 'package:fuchsia_modular/src/module/internal/_intent_handler_impl.dart';
import 'package:fuchsia_modular/src/module/internal/_module_impl.dart';
import 'package:fuchsia_modular/src/module/module_state_exception.dart';
import 'package:test/test.dart';

// ignore_for_file: implementation_imports

const fidl.Intent _emptyIntent = fidl.Intent(
  action: '',
  handler: '',
  parameters: [],
);

// Mock classes
class MockModuleContext extends Mock implements fidl.ModuleContextProxy {}

void main() {
  IntentHandlerImpl handlerImpl;

  setUp(() {
    handlerImpl =
        IntentHandlerImpl(startupContext: StartupContext.fromStartupInfo());
  });

  test('addModuleToStory should return ModuleController upon success',
      () async {
    final context = MockModuleContext();
    when(context.addModuleToStory(any, any, any, any))
        .thenAnswer((_) => Future.value(fidl.StartModuleStatus.success));

    final moduleImpl =
        ModuleImpl(intentHandlerImpl: handlerImpl, moduleContextProxy: context);

    final ctrl = await moduleImpl.addModuleToStory(
        name: 'testMod', intent: _emptyIntent);
    expect(ctrl, const TypeMatcher<fidl.ModuleController>());
  });

  test(
      'addModuleToStory should throw ModuleResolutionException if no module '
      'found', () {
    final context = MockModuleContext();
    when(context.addModuleToStory(any, any, any, any))
        .thenAnswer((_) => Future.value(fidl.StartModuleStatus.noModulesFound));

    final moduleImpl =
        ModuleImpl(intentHandlerImpl: handlerImpl, moduleContextProxy: context);

    expect(moduleImpl.addModuleToStory(name: 'testMod', intent: _emptyIntent),
        throwsA(const TypeMatcher<ModuleResolutionException>()));
  });

  test('addModuleToStory should throw ModuleStateException for unknown errors',
      () {
    final context = MockModuleContext();
    when(context.addModuleToStory(any, any, any, any))
        .thenAnswer((_) => Future.value(fidl.StartModuleStatus(-99)));

    final moduleImpl =
        ModuleImpl(intentHandlerImpl: handlerImpl, moduleContextProxy: context);

    expect(moduleImpl.addModuleToStory(name: 'testMod', intent: _emptyIntent),
        throwsA(const TypeMatcher<ModuleStateException>()));
  });

  /// Embed Module
  test('embedModule should throw ModuleResolutionException if no module found',
      () {
    final context = MockModuleContext();
    when(context.embedModule(any, any, any, any))
        .thenAnswer((_) => Future.value(fidl.StartModuleStatus.noModulesFound));

    final moduleImpl =
        ModuleImpl(intentHandlerImpl: handlerImpl, moduleContextProxy: context);

    expect(moduleImpl.embedModule(name: 'testMod', intent: _emptyIntent),
        throwsA(const TypeMatcher<ModuleResolutionException>()));
  });

  test('embedModule should throw ModuleStateException for unknown errors', () {
    final context = MockModuleContext();
    when(context.embedModule(any, any, any, any))
        .thenAnswer((_) => Future.value(fidl.StartModuleStatus.success));

    final moduleImpl =
        ModuleImpl(intentHandlerImpl: handlerImpl, moduleContextProxy: context);

    expect(moduleImpl.embedModule(name: '', intent: _emptyIntent),
        throwsArgumentError);
  });

  test('embedModule should throw ArgumentError for invalid name', () {
    final context = MockModuleContext();
    when(context.embedModule(any, any, any, any))
        .thenAnswer((_) => Future.value(fidl.StartModuleStatus(-99)));

    final moduleImpl =
        ModuleImpl(intentHandlerImpl: handlerImpl, moduleContextProxy: context);

    expect(moduleImpl.embedModule(name: 'testMod', intent: _emptyIntent),
        throwsA(const TypeMatcher<ModuleStateException>()));
  });
}
