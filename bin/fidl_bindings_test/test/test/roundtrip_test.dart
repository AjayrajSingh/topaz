// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:fidl_fidl_examples_bindingstest/fidl_async.dart';
import 'package:fidl/fidl.dart' as fidl;

import 'gidl.dart';

void main() {
  group('roundtrip', () {
    SuccessCase.run(
        'empty-struct-sandwich',
        TestEmptyStructSandwich(
            before: 'before', es: EmptyStruct(), after: 'after'),
        kTestEmptyStructSandwich_Type,
        Uint8List.fromList([
          6, 0, 0, 0, 0, 0, 0, 0, // length of "before"
          255, 255, 255, 255, 255, 255, 255, 255, // "before" is present
          0, // empty struct zero field
          0, 0, 0, 0, 0, 0,
          0, // 7 bytes of padding after empty struct, to align to 64 bits
          5, 0, 0, 0, 0, 0, 0, 0, // length of "after"
          255, 255, 255, 255, 255, 255, 255, 255, // "after" is present
          98, 101, 102, 111, 114, 101, // "before"
          0, 0, // 2 bytes of padding after "before", to align to 64 bits
          97, 102, 116, 101, 114, // "after" string
          0, 0, 0, // 3 bytes of padding after "after", to align to 64 bits
        ]));

    SuccessCase.run(
        'simpletable-x-and-y',
        TestSimpleTable(
          table: SimpleTable(x: 42, y: 67),
        ),
        kTestSimpleTable_Type,
        Uint8List.fromList([
          5, 0, 0, 0, 0, 0, 0, 0, // max ordinal
          255, 255, 255, 255, 255, 255, 255, 255, // alloc present
          8, 0, 0, 0, 0, 0, 0, 0, // envelope 1: num bytes / num handles
          255, 255, 255, 255, 255, 255, 255, 255, // alloc present
          0, 0, 0, 0, 0, 0, 0, 0, // envelope 2: num bytes / num handles
          0, 0, 0, 0, 0, 0, 0, 0, // no alloc
          0, 0, 0, 0, 0, 0, 0, 0, // envelope 3: num bytes / num handles
          0, 0, 0, 0, 0, 0, 0, 0, // no alloc
          0, 0, 0, 0, 0, 0, 0, 0, // envelope 4: num bytes / num handles
          0, 0, 0, 0, 0, 0, 0, 0, // no alloc
          8, 0, 0, 0, 0, 0, 0, 0, // envelope 5: num bytes / num handles
          255, 255, 255, 255, 255, 255, 255, 255, // alloc present
          42, 0, 0, 0, 0, 0, 0, 0, // field X
          67, 0, 0, 0, 0, 0, 0, 0, // field Y
        ]));

    SuccessCase.run(
        'simpletable-just-y',
        TestSimpleTable(
          table: SimpleTable(y: 67),
        ),
        kTestSimpleTable_Type,
        Uint8List.fromList([
          5, 0, 0, 0, 0, 0, 0, 0, // max ordinal
          255, 255, 255, 255, 255, 255, 255, 255, // alloc present
          0, 0, 0, 0, 0, 0, 0, 0, // envelope 1: num bytes / num handles
          0, 0, 0, 0, 0, 0, 0, 0, // no alloc
          0, 0, 0, 0, 0, 0, 0, 0, // envelope 2: num bytes / num handles
          0, 0, 0, 0, 0, 0, 0, 0, // no alloc
          0, 0, 0, 0, 0, 0, 0, 0, // envelope 3: num bytes / num handles
          0, 0, 0, 0, 0, 0, 0, 0, // no alloc
          0, 0, 0, 0, 0, 0, 0, 0, // envelope 4: num bytes / num handles
          0, 0, 0, 0, 0, 0, 0, 0, // no alloc
          8, 0, 0, 0, 0, 0, 0, 0, // envelope 5: num bytes / num handles
          255, 255, 255, 255, 255, 255, 255, 255, // alloc present
          67, 0, 0, 0, 0, 0, 0, 0, // field Y
        ]));

    SuccessCase.run(
        'table-with-string-and-vector-1',
        TestTableWithStringAndVector(
          table: TableWithStringAndVector(
            foo: 'hello',
            bar: 27,
          ),
        ),
        kTestTableWithStringAndVector_Type,
        Uint8List.fromList([
          2, 0, 0, 0, 0, 0, 0, 0, // max ordinal
          255, 255, 255, 255, 255, 255, 255, 255, // alloc present
          24, 0, 0, 0, 0, 0, 0, 0, // envelope 1: num bytes / num handles
          255, 255, 255, 255, 255, 255, 255, 255, // envelope 1: alloc present
          8, 0, 0, 0, 0, 0, 0, 0, // envelope 2: num bytes / num handles
          255, 255, 255, 255, 255, 255, 255, 255, // envelope 2: alloc present
          5, 0, 0, 0, 0, 0, 0, 0, // element 1: length
          255, 255, 255, 255, 255, 255, 255, 255, // element 1: alloc present
          104, 101, 108, 108, 111, 0, 0, 0, // element 1: hello
          27, 0, 0, 0, 0, 0, 0, 0, // element 2: value
        ]));

    SuccessCase.run(
        'empty-table',
        TestSimpleTable(table: SimpleTable()),
        kTestSimpleTable_Type,
        Uint8List.fromList([
          0, 0, 0, 0, 0, 0, 0, 0, // max ordinal
          255, 255, 255, 255, 255, 255, 255, 255, // alloc present
        ]));

    SuccessCase.run(
        'inline-xunion-in-struct',
        TestInlineXUnionInStruct(
          before: 'before',
          xu: SampleXUnion.withU(0xdeadbeef),
          after: 'after',
        ),
        kTestInlineXUnionInStruct_Type,
        Uint8List.fromList([
          0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "before" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" presence

          0xd6, 0xb5, 0x01, 0x2d, 0x00, 0x00, 0x00,
          0x00, // xunion discriminator + padding
          0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, // num bytes + num handles
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
          0xff, // envelope data is present

          0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "after" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" presence

          // secondary object 1: "before"
          98, 101, 102, 111, 114, 101, 0x00, 0x00,

          // secondary object 2: xunion content
          0xef, 0xbe, 0xad, 0xde, 0x00, 0x00, 0x00,
          0x00, // xunion envelope content (0xdeadbeef) + padding

          // secondary object 3: "after"
          97, 102, 116, 101, 114, 0x00, 0x00, 0x00,
        ]));

    SuccessCase.run(
        'optional-xunion-in-struct-absent',
        TestOptionalXUnionInStruct(
          before: 'before',
          after: 'after',
        ),
        kTestOptionalXUnionInStruct_Type,
        Uint8List.fromList([
          0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "before" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" presence

          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, // xunion discriminator + padding
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, // num bytes + num handles
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, // envelope data is absent

          0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "after" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" presence

          // secondary object 1: "before"
          98, 101, 102, 111, 114, 101, 0x00, 0x00,

          // secondary object 2: "after"
          97, 102, 116, 101, 114, 0x00, 0x00, 0x00,
        ]));

    SuccessCase.run(
        'optional-xunion-in-struct-present',
        TestOptionalXUnionInStruct(
          before: 'before',
          xu: SampleXUnion.withU(0xdeadbeef),
          after: 'after',
        ),
        kTestOptionalXUnionInStruct_Type,
        Uint8List.fromList([
          0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "before" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" presence

          0xd6, 0xb5, 0x01, 0x2d, 0x00, 0x00, 0x00,
          0x00, // xunion discriminator + padding
          0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, // num bytes + num handles
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
          0xff, // envelope data is present

          0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "after" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" presence

          // secondary object 1: "before"
          98, 101, 102, 111, 114, 101, 0x00, 0x00,

          // secondary object 2: xunion content
          0xef, 0xbe, 0xad, 0xde, 0x00, 0x00, 0x00,
          0x00, // xunion envelope content (0xdeadbeef) + padding

          // secondary object 3: "after"
          97, 102, 116, 101, 114, 0x00, 0x00, 0x00,
        ]));

    SuccessCase.run(
        'xunion-in-table-xunion-absent',
        TestXUnionInTable(
            value: XUnionInTable(
          before: 'before',
          after: 'after',
        )),
        kTestXUnionInTable_Type,
        Uint8List.fromList([
          // primary object
          0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, // vector<envelope> element count
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
          0xff, // vector<envelope> present

          // secondary object 1: vector data
          // vector[0]: envelope<string before>
          0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // size + handle count
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" is present
          // vector[1]: envelope<SampleXUnion xu>
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // size + handle count
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // xunion is absent
          // vector[2]: envelope<string after>
          0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // size + handle count
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "after" is present

          // secondary object 2: "before" length + pointer
          0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "before" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" present

          // secondary object 3: "before"
          98, 101, 102, 111, 114, 101, 0x00, 0x00,

          // secondary object 4: "after" length + pointer
          0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "after" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "after" present

          // secondary object 5: "before"
          97, 102, 116, 101, 114, 0x00, 0x00, 0x00,
        ]));

    SuccessCase.run(
        'xunion-in-table-xunion-present',
        TestXUnionInTable(
            value: XUnionInTable(
          before: 'before',
          xu: SampleXUnion.withU(0xdeadbeef),
          after: 'after',
        )),
        kTestXUnionInTable_Type,
        Uint8List.fromList([
          // primary object
          0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, // vector<envelope> element count
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
          0xff, // vector<envelope> present

          // secondary object 1: vector data
          // vector[0]: envelope<string before>
          0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // size + handle count
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" is present
          // vector[1]: envelope<SampleXUnion xu>
          0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // size + handle count
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // xunion is present
          // vector[2]: envelope<string after>
          0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // size + handle count
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "after" is present

          // secondary object 2: "before" length + pointer
          0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "before" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "before" present

          // secondary object 3: "before"
          98, 101, 102, 111, 114, 101, 0x00, 0x00,

          // secondary object 4: xunion
          0xd6, 0xb5, 0x01, 0x2d, 0x00, 0x00, 0x00,
          0x00, // xunion discriminator + padding
          0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, // num bytes + num handles
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
          0xff, // envelope data is present

          // secondary object 5: xunion content
          0xef, 0xbe, 0xad, 0xde, 0x00, 0x00, 0x00,
          0x00, // 0xdeadbeef + padding

          // secondary object 6: "after" length + pointer
          0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // "after" length
          0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // "after" present

          // secondary object 7: "after"
          97, 102, 116, 101, 114, 0x00, 0x00, 0x00,
        ]));

    EncodeFailureCase.run(
        'string3-string-too-long',
        TestString3(
          a: [
            'too long', // limit is 4, provided is longer(tm)
            'g'
          ],
          b: [null, null],
        ),
        kTestString3_Type,
        fidl.FidlErrorCode.fidlStringTooLong);

    DecodeFailureCase.run(
        'string-wrong-ptr-no-alloc',
        kTestStringWithBound_Type,
        Uint8List.fromList(
          [
            0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // length
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ptr (no alloc)
            // no data, unmarshal should fail before
          ],
        ),
        fidl.FidlErrorCode.fidlNonNullableTypeWithNullValue);
  });
}
