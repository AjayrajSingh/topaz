// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_tictactoe/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';

class GameTrackerImpl extends GameTracker {
  Sledge _sledge;
  DocumentId _sledgeDocumentId;

  GameTrackerImpl(ComponentContext conmpoentContext)
      : _sledge = new Sledge(conmpoentContext) {
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'xScore': new Integer(),
      'oScore': new Integer()
    };

    Schema schema = new Schema(schemaDescription);
    _sledgeDocumentId = new DocumentId.fromIntId(schema, 0);
  }

  @override
  void recordWin(Player player) async {
    await _sledge.runInTransaction(() async {
      dynamic doc = await _sledge.getDocument(_sledgeDocumentId);
      if (player == Player.x) {
        doc.xScore.value++;
      } else {
        doc.oScore.value++;
      }

      log
        ..infoT('Player $player won')
        ..infoT('Current score x: ${doc.xScore.value}  o: ${doc.oScore.value}');
    });
  }
}
