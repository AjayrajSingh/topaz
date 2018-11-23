// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Interface implemented by all Sledge Values.
///
/// Values are used to store the structure and content of the fields of a
/// Document.
///
/// There are two main types of Values: NodeValues, and LeafValues.
/// Every Sledge Document holds a reference to a NodeValue.
/// The NodeValues hold references to at least one other Value (either a
/// NodeValue or a LeafValue).
/// The LeafValues store the actual content of the fields.
///
/// For example, a Document whose fields can be accessed the following way:
///   doc['a'].value = 1;
///   doc['b']['c'].value = 2.0;
///   doc['b']['d'].value = 'foobar';
/// Will be composed of 2 NodeValues and 3 LeafValues:
///   doc
///    └─NodeValue
///          ├─ 'a' : LeafValue (specialized for integers)
///          └─ 'b' : NodeValue
///                       ├─ 'c' : LeafValue (specialized for doubles)
///                       └─ 'd' : LeafValue (specialized for strings)
abstract class Value {}
