// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_conversation_info/widgets.dart';
import 'package:chat_models/chat_models.dart';
import 'package:fixtures/fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lib.widgets/model.dart';

final Fixtures _fixtures = new Fixtures();

/// Randomly generate three participants using [Fixtures] utility.
final List<Participant> _kTestParticipants = new List<Participant>.unmodifiable(
  new Iterable<Participant>.generate(
    3,
    (int i) => new Participant(
          email: _fixtures.email(),
          displayName: _fixtures.name(),
        ),
  ),
);

final Map<String, Participant> _kTestParticipantMap =
    new Map<String, Participant>.unmodifiable(
  new Map<String, Participant>.fromIterable(
    _kTestParticipants,
    // ignore: uses_dynamic_as_bottom
    key: (Participant p) => p.email,
    // ignore: uses_dynamic_as_bottom
    value: (Participant p) => p,
  ),
);

void main() {
  testWidgets(
    'The section header should be shown.',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        new MaterialApp(
          home: const Material(
            child: const ParticipantsSection(),
          ),
        ),
      );

      expect(find.text('People'), findsOneWidget);
    },
  );

  testWidgets(
    'The add button callback should be correctly called.',
    (WidgetTester tester) async {
      // When the editing is disabled, the add button should not be shown.
      await tester.pumpWidget(
        new MaterialApp(
          home: const Material(
            child: const ParticipantsSection(),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text('Add people'), findsNothing);

      // When the editing is disabled, the add button should not be shown.
      int tapAddCount = 0;

      await tester.pumpWidget(
        new MaterialApp(
          home: new Material(
            child: new ParticipantsSection(
              editingEnabled: true,
              onAddTapped: () => tapAddCount++,
            ),
          ),
        ),
      );

      expect(tapAddCount, 0);

      // Try tapping the icon.
      await tester.tap(find.byIcon(Icons.add));

      expect(tapAddCount, 1);

      // Try tapping the text, which should also work.
      await tester.tap(find.text('Add people'));

      expect(tapAddCount, 2);
    },
  );

  testWidgets(
    'The participants should be correctly shown.',
    (WidgetTester tester) async {
      UserModel userModel = new UserModel()..updateModel(_kTestParticipantMap);

      await tester.pumpWidget(
        new MaterialApp(
          home: new Material(
            child: new ScopedModel<UserModel>(
              model: userModel,
              child: const ParticipantsSection(),
            ),
          ),
        ),
      );

      for (Participant participant in _kTestParticipants) {
        expect(find.text(participant.effectiveDisplayName), findsOneWidget);
      }
    },
  );

  testWidgets(
    'The remove button callback should be correctly called.',
    (WidgetTester tester) async {
      UserModel userModel = new UserModel()..updateModel(_kTestParticipantMap);

      // When the editing is disabled, the remove buttons should not be shown.
      await tester.pumpWidget(
        new MaterialApp(
          home: new Material(
            child: new ScopedModel<UserModel>(
              model: userModel,
              child: const ParticipantsSection(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsNothing);

      // Key: participant email.
      // Value: remove button tap count for the participant.
      Map<String, int> tapCount = <String, int>{};

      await tester.pumpWidget(
        new MaterialApp(
          home: new Material(
            child: new ScopedModel<UserModel>(
              model: userModel,
              child: new ParticipantsSection(
                editingEnabled: true,
                onRemoveTapped: (Participant p) {
                  tapCount.putIfAbsent(p.email, () => 0);
                  tapCount[p.email]++;
                },
              ),
            ),
          ),
        ),
      );

      for (Participant participant in _kTestParticipants) {
        // Find the remove button associated with this participant.
        Finder removeButtonFinder = find.descendant(
          of: find.widgetWithText(ListTile, participant.effectiveDisplayName),
          matching: find.byIcon(Icons.clear),
        );

        expect(tapCount[participant.email], isNull);
        await tester.tap(removeButtonFinder);
        expect(tapCount[participant.email], 1);
      }
    },
  );
}
