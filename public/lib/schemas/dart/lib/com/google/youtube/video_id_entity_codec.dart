// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/entity_codec.dart';

const String _kYoutubeVideoIdEntityUri = 'com.fuchsia.youtube.videoid';

/// Convert a request to set the videoID to a form passable over a Link between
/// modules.
class VideoIdEntityCodec extends EntityCodec<String> {
  /// Constuctor assigns the proper values to en/decode a the request.
  VideoIdEntityCodec()
      : super(
          type: _kYoutubeVideoIdEntityUri,
          encode: (x) => x,
          decode: (x) => x,
        );
}
