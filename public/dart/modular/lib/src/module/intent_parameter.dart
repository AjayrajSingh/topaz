// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:meta/meta.dart';

/// An [IntentParameter] is an object which is included in the [Intent].
/// The parameter will hold data which the module has requested in the
/// module manifest file. [IntentParameter]s can be watched if they are
/// of the type of parameter that will constantly update their values
/// or a single value can be retrieved if they are not expected to get
/// a stream of data.
///
/// Note: you will likely not need to create an [IntentParameter] on you
/// own but rather retrieve them from the [Intent] object. If you need to
/// add them to the [Intent] use the helper methods on [Intent] directly.
class IntentParameter extends fidl.IntentParameter {
  /// The object which will convert the intent parameter data
  /// object into a more useable type.
  final IntentParameterDataTransformer dataTransformer;

  /// Creates an [IntentParameter] object with the required values.
  /// It is not common that this method will be used.
  IntentParameter({
    @required String name,
    @required fidl.IntentParameterData data,
    @required this.dataTransformer,
  })  : assert(name != null),
        assert(data != null),
        assert(dataTransformer != null),
        super(name: name, data: data);

  /// Returns the value associated with this [IntentParameter]. The [codec]
  /// will be used to translate the incoming bytes to a dart object.
  Future<T> getValue<T>(IntentParameterCodec<T> codec) =>
      dataTransformer.getValue(data, codec);

  /// Returns a [Stream] which can be watched to receive continuous updates.
  /// The [codec] will be used to translate the incoming bytes to a dart object.
  Stream<T> watchData<T>(IntentParameterCodec<T> codec) =>
      dataTransformer.createStream(data, codec);
}

/// Only here to make the compiler happy until we figure out the signature
class IntentParameterCodec<T> {}

/// A class which converts [fidl.IntentParameterData] objects to streams and
/// values
abstract class IntentParameterDataTransformer {
  /// Creates a stream from the given data that transforms bytes using
  /// the codec.
  Stream<T> createStream<T>(
      fidl.IntentParameterData data, IntentParameterCodec<T> codec);

  /// Converts the given data into a future using the provided codec.
  Future<T> getValue<T>(
      fidl.IntentParameterData data, IntentParameterCodec<T> codec);
}
