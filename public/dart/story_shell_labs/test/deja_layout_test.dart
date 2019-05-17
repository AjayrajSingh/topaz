// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:story_shell_labs_lib/layout/deja_layout.dart';
import 'package:story_shell_labs_lib/layout/tile_model.dart';
import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:tiler/tiler.dart';

class MockFile extends Mock implements File {}

class MockLayoutStore extends Mock implements LayoutStore {}

final _kViewBookContent = ModuleInfo(
  modName: 'books_mod',
  intent: 'VIEW_BOOK',
  parameters: UnmodifiableListView<String>([]),
);

final _kViewCollectionContent = ModuleInfo(
  modName: 'collections_mod',
  intent: 'VIEW_COLLECTION',
  parameters: UnmodifiableListView<String>([]),
);

final _kNonMatchingIntentContent = ModuleInfo(
  modName: 'misc_mod',
  intent: 'NON_MATCHING_INTENT',
  parameters: UnmodifiableListView<String>([]),
);

MockFile _createLayoutFile(TilerModel<ModuleInfo> layout) {
  final layoutFile = MockFile();

  when(layoutFile.readAsString())
      .thenAnswer((_) => Future.value(json.encode(toJson(layout))));
  when(layoutFile.readAsStringSync())
      .thenAnswer((_) => json.encode(toJson(layout)));

  return layoutFile;
}

//          *
//        /   \
//    node1  node2
TilerModel<ModuleInfo> _genLayout2Mods({
  @required Map node1,
  @required Map node2,
}) {
  return TilerModel<ModuleInfo>(
    root: TileModel<ModuleInfo>(
      type: TileType.column,
      tiles: [
        TileModel<ModuleInfo>(
            flex: node1['flex'],
            type: TileType.content,
            content: node1['content'] ?? _kViewBookContent),
        TileModel<ModuleInfo>(
            flex: node2['flex'],
            type: TileType.content,
            content: node2['content'] ?? _kViewBookContent),
      ],
    ),
  );
}

//          *
//        /   \
//   node1     *
//            /  \
//        node2   node3
TilerModel<ModuleInfo> _genLayout3ModsA({
  @required Map node1,
  @required Map node2,
  @required Map node3,
}) {
  return TilerModel<ModuleInfo>(
    root: TileModel<ModuleInfo>(
      type: TileType.row,
      tiles: [
        TileModel<ModuleInfo>(
            flex: node1['flex'],
            type: TileType.content,
            content: node1['content'] ?? _kViewCollectionContent),
        TileModel<ModuleInfo>(
          type: TileType.column,
          tiles: [
            TileModel<ModuleInfo>(
                flex: node2['flex'],
                type: TileType.content,
                content: node2['content'] ?? _kViewCollectionContent),
            TileModel<ModuleInfo>(
                flex: node3['flex'],
                type: TileType.content,
                content: node3['content'] ?? _kViewBookContent),
          ],
        )
      ],
    ),
  );
}

//          *
//        /   \
//   node1     *
//            /  \
//         node2  node3
TilerModel<ModuleInfo> _genLayout3ModsB({
  @required Map node1,
  @required Map node2,
  @required Map node3,
}) {
  return TilerModel<ModuleInfo>(
    root: TileModel<ModuleInfo>(
      type: TileType.column,
      tiles: [
        TileModel<ModuleInfo>(
            flex: node1['flex'],
            type: TileType.content,
            content: node1['content'] ?? _kViewCollectionContent),
        TileModel<ModuleInfo>(
          type: TileType.row,
          tiles: [
            TileModel<ModuleInfo>(
                flex: node2['flex'],
                type: TileType.content,
                content: node2['content'] ?? _kViewCollectionContent),
            TileModel<ModuleInfo>(
                flex: node3['flex'],
                type: TileType.content,
                content: node3['content'] ?? _kViewBookContent),
          ],
        )
      ],
    ),
  );
}

//                *
//              /   \
//             *    node1
//            /  \
//       node2    node3
TilerModel<ModuleInfo> _genLayout3ModsC({
  @required Map node1,
  @required Map node2,
  @required Map node3,
}) {
  return TilerModel<ModuleInfo>(
    root: TileModel<ModuleInfo>(
      type: TileType.row,
      tiles: [
        TileModel<ModuleInfo>(
          type: TileType.column,
          tiles: [
            TileModel<ModuleInfo>(
                flex: node2['flex'],
                type: TileType.content,
                content: node2['content'] ?? _kViewCollectionContent),
            TileModel<ModuleInfo>(
                flex: node3['flex'],
                type: TileType.content,
                content: node3['content'] ?? _kViewBookContent),
          ],
        ),
        TileModel<ModuleInfo>(
            flex: node1['flex'],
            type: TileType.content,
            content: node1['content'] ?? _kViewCollectionContent),
      ],
    ),
  );
}

//                *
//              /   \
//             *    node1
//            /  \
//       node2    node3
TilerModel<ModuleInfo> _genLayout3ModsD({
  @required Map node1,
  @required Map node2,
  @required Map node3,
}) {
  return TilerModel<ModuleInfo>(
    root: TileModel<ModuleInfo>(
      type: TileType.column,
      tiles: [
        TileModel<ModuleInfo>(
          type: TileType.row,
          tiles: [
            TileModel<ModuleInfo>(
                flex: node2['flex'],
                type: TileType.content,
                content: node2['content'] ?? _kViewBookContent),
            TileModel<ModuleInfo>(
                flex: node3['flex'],
                type: TileType.content,
                content: node3['content'] ?? _kViewCollectionContent),
          ],
        ),
        TileModel<ModuleInfo>(
            flex: node1['flex'],
            type: TileType.content,
            content: node1['content'] ?? _kViewCollectionContent),
      ],
    ),
  );
}

List<MockFile> _fillLayoutFiles(
    List<int> fills, List<TilerModel<ModuleInfo>> layouts) {
  assert(fills.length == layouts.length);

  final layoutFiles = <MockFile>[];
  for (int i = 0; i < fills.length; i++) {
    layoutFiles
        .addAll(List.filled(fills[i], layouts[i]).map(_createLayoutFile));
  }

  layoutFiles.shuffle();
  return layoutFiles;
}

// Layout Suggestions are sorted descending by occurrence count.
// Each layout suggestion is different geometric layout.
//
// Top N suggestions are determined by:
// 1. Matching Intents
//    2. Group by equivalent geometric layout.
//       Sort this Group by occurrence count.
//.     3. In a geometric layout group. Further Group by equivalent flex
//         layouts. Sort this Group by occurrence count.
//
//
// Additional Details: Geometric layout.
// Flex is not a property that changes the geometric layout.
//
// A geometric layout could not be equivalent because of different layout tree
// structure
//          *                     *
//         /  \                  /  \
//        t     *               *    t
//             / \             / \
//            t   t           t   t
//
// Or a geometric layout could be different because of the Tile orientation
// TileType.row, TileType.column. But the tree layout structure could be
// the same.
//
//          * (TileType.row)              * (TileType.column)
//         /  \                         /   \
//        t     * (TileType.column)    t      * (TileType.row)
//             / \                          /  \
//            t   t                        t    t
//
void main() {
  MockLayoutStore mockLayoutStore;

  setUp(() {
    mockLayoutStore = MockLayoutStore();
    when(mockLayoutStore.read(any)).thenAnswer((Invocation i) {
      final MockFile f = i.positionalArguments[0];
      final s = f.readAsStringSync();
      return fromJson(jsonDecode(s));
    });
  });

  test(
      'Expect current layout as the only suggestion'
      ' if no stored matching geometric layouts.', () {
    final layouts = [
      _genLayout3ModsA(
        node1: {'flex': 0.5},
        node2: {'flex': 0.5},
        node3: {'flex': 0.5},
      ), // appears 3 times
      _genLayout3ModsA(
        node1: {'flex': 0.2},
        node2: {'flex': 0.4},
        node3: {'flex': 0.6},
      ), // appears 2 times
    ];

    final layoutFiles = _fillLayoutFiles([3, 2], layouts);
    when(mockLayoutStore.listSync()).thenReturn(layoutFiles);
    final layoutPolicy = LayoutPolicy(layoutStore: mockLayoutStore);

    final currentLayout = _genLayout2Mods(
      node1: {'flex': 0.5},
      node2: {'flex': 0.5},
    );

    final tilerModelsSuggestions = layoutPolicy.getLayout(currentLayout);
    expect(tilerModelsSuggestions.length, 1);
    expect(tilerModelsSuggestions[0], currentLayout);
  });

  test(
      'Expect current layout as the only suggestion'
      ' if no stored layouts with matching intents.', () {
    final layouts = [
      _genLayout3ModsA(
        node1: {'flex': 0.5, 'content': _kNonMatchingIntentContent},
        node2: {'flex': 0.5, 'content': _kNonMatchingIntentContent},
        node3: {'flex': 0.5, 'content': _kNonMatchingIntentContent},
      ), // appears 3 times
      _genLayout3ModsA(
        node1: {'flex': 0.2, 'content': _kNonMatchingIntentContent},
        node2: {'flex': 0.4, 'content': _kNonMatchingIntentContent},
        node3: {'flex': 0.6, 'content': _kNonMatchingIntentContent},
      ), // appears 2 times
    ];

    final layoutFiles = _fillLayoutFiles([3, 2], layouts);
    when(mockLayoutStore.listSync()).thenReturn(layoutFiles);
    final layoutPolicy = LayoutPolicy(layoutStore: mockLayoutStore);

    final currentLayout = _genLayout3ModsB(
      node1: {'flex': 0.5},
      node2: {'flex': 0.5},
      node3: {'flex': 0.5},
    );

    final tilerModelsSuggestions = layoutPolicy.getLayout(currentLayout);
    expect(tilerModelsSuggestions.length, 1);
    expect(tilerModelsSuggestions[0], currentLayout);
  });

  test(
      'Expect current layout is not part of the suggestions if there are'
      ' any stored layouts with matching geometry and intents', () {
    final layouts = [
      _genLayout3ModsA(
        node1: {'flex': 0.2},
        node2: {'flex': 0.3},
        node3: {'flex': 0.7},
      ),
    ];

    final layoutFiles = [_createLayoutFile(layouts[0])];
    when(mockLayoutStore.listSync()).thenReturn(layoutFiles);
    final layoutPolicy = LayoutPolicy(layoutStore: mockLayoutStore);

    final currentLayout = _genLayout3ModsD(
      node1: {'flex': 0.8},
      node2: {'flex': 0.2},
      node3: {'flex': 0.8},
    );

    final tilerModelsSuggestions = layoutPolicy.getLayout(currentLayout);
    expect(tilerModelsSuggestions.length, 1);
    expect(toJson(tilerModelsSuggestions[0]), toJson(layouts[0]));
  });

  test(
      'Expect only 1 suggestion generated if all stored layouts are'
      ' geometric equivalent even if flex amounts differ', () {
    // All stored layouts below are all geometrically equivalent.
    // Therefore only 1 layout suggestion is generated since layout
    // suggestion must each be a different geometry.
    final layouts = [
      // Top 1 layout is the one below since it occurs most often.
      _genLayout3ModsA(
        node1: {'flex': 0.5},
        node2: {'flex': 0.5},
        node3: {'flex': 0.5},
      ), // appears 6 times
      _genLayout3ModsA(
        node1: {'flex': 0.2},
        node2: {'flex': 0.3},
        node3: {'flex': 0.7},
      ), // appears 5 times
      _genLayout3ModsA(
        node1: {'flex': 0.3},
        node2: {'flex': 0.4},
        node3: {'flex': 0.6},
      ), // appears 4 times
      _genLayout3ModsA(
        node1: {'flex': 0.4},
        node2: {'flex': 0.8},
        node3: {'flex': 0.2},
      ), // appears 3 times
    ];

    final layoutFiles = _fillLayoutFiles([6, 5, 4, 3], layouts);
    when(mockLayoutStore.listSync()).thenReturn(layoutFiles);
    final layoutPolicy = LayoutPolicy(layoutStore: mockLayoutStore);

    final currentLayout = _genLayout3ModsA(
      node1: {'flex': 0.3},
      node2: {'flex': 0.2},
      node3: {'flex': 0.8},
    );

    final tilerModelsSuggestions = layoutPolicy.getLayout(currentLayout);
    expect(tilerModelsSuggestions.length, 1);
    expect(toJson(tilerModelsSuggestions[0]), toJson(layouts[0]));
  });

  test(
      'Expect top N layouts sorted by occurence for geometric and flex.'
      ' Each suggestion is a different geometric layout with'
      ' matching intents', () {
    final layouts = [
      // Top 4 layouts below.
      _genLayout3ModsA(
        node1: {'flex': 0.5},
        node2: {'flex': 0.5},
        node3: {'flex': 0.5},
      ), // appears 9 times
      _genLayout3ModsB(
        node1: {'flex': 0.2},
        node2: {'flex': 0.4},
        node3: {'flex': 0.6},
      ), // appears 8 times
      _genLayout3ModsC(
        node1: {'flex': 0.1},
        node2: {'flex': 0.3},
        node3: {'flex': 0.7},
      ), // appears 7 times
      _genLayout3ModsD(
        node1: {'flex': 0.1},
        node2: {'flex': 0.3},
        node3: {'flex': 0.7},
      ), // appears 6 times
      // The layouts below are layouts that are geometrically equivalent to
      // the top ranking layouts, but their flex amounts differ. The number of
      // times these layouts occurs also differs.
      _genLayout3ModsA(
        node1: {'flex': 0.1},
        node2: {'flex': 0.1},
        node3: {'flex': 0.9},
      ), // appears 5 times
      _genLayout3ModsB(
        node1: {'flex': 0.2},
        node2: {'flex': 0.2},
        node3: {'flex': 0.8},
      ), // appears 4 times
      _genLayout3ModsC(
        node1: {'flex': 0.3},
        node2: {'flex': 0.8},
        node3: {'flex': 0.2},
      ), // appears 3 times
      _genLayout3ModsD(
        node1: {'flex': 0.4},
        node2: {'flex': 0.2},
        node3: {'flex': 0.8},
      ), // appears 2 times
    ];

    final layoutFiles = _fillLayoutFiles([9, 8, 7, 6, 5, 4, 3, 2], layouts);
    when(mockLayoutStore.listSync()).thenReturn(layoutFiles);
    final layoutPolicy = LayoutPolicy(layoutStore: mockLayoutStore);

    final currentLayout = _genLayout3ModsA(
      node1: {'flex': 0.7},
      node2: {'flex': 0.2},
      node3: {'flex': 0.8},
    );

    final top4layouts = layouts.sublist(0, 4);
    final tilerModelsSuggestions = layoutPolicy.getLayout(currentLayout);
    expect(tilerModelsSuggestions.length, 4);
    expect(tilerModelsSuggestions.map(toJson), top4layouts.map(toJson));
  });

  test('Expect only matching intents layouts to appear in top N layouts', () {
    final layouts = [
      // Top 2 layouts below.
      _genLayout3ModsA(
        node1: {'flex': 0.5},
        node2: {'flex': 0.5},
        node3: {'flex': 0.5},
      ), // appears 4 times
      _genLayout3ModsB(
        node1: {'flex': 0.2},
        node2: {'flex': 0.4},
        node3: {'flex': 0.6},
      ), // appears 3 times
      // Layouts below are those with non-matching intents to current layout.
      _genLayout3ModsD(
        node1: {'flex': 0.6, 'content': _kNonMatchingIntentContent},
        node2: {'flex': 0.1, 'content': _kNonMatchingIntentContent},
        node3: {'flex': 0.9, 'content': _kNonMatchingIntentContent},
      ), // appears 7 times
      _genLayout3ModsC(
        node1: {'flex': 0.8, 'content': _kNonMatchingIntentContent},
        node2: {'flex': 0.8, 'content': _kNonMatchingIntentContent},
        node3: {'flex': 0.2, 'content': _kNonMatchingIntentContent},
      ), // appears 6 times
      _genLayout3ModsB(
        node1: {'flex': 0.7, 'content': _kNonMatchingIntentContent},
        node2: {'flex': 0.4, 'content': _kNonMatchingIntentContent},
        node3: {'flex': 0.6, 'content': _kNonMatchingIntentContent},
      ), // appears 5 times
    ];

    final layoutFiles = _fillLayoutFiles([4, 3, 7, 6, 5], layouts);
    when(mockLayoutStore.listSync()).thenReturn(layoutFiles);
    final layoutPolicy = LayoutPolicy(layoutStore: mockLayoutStore);

    final currentLayout = _genLayout3ModsA(
      node1: {'flex': 0.3},
      node2: {'flex': 0.2},
      node3: {'flex': 0.8},
    );

    final top2layouts = layouts.sublist(0, 2);
    final tilerModelsSuggestions = layoutPolicy.getLayout(currentLayout);
    expect(tilerModelsSuggestions.length, 2);
    expect(tilerModelsSuggestions.map(toJson), top2layouts.map(toJson));
  });
}
