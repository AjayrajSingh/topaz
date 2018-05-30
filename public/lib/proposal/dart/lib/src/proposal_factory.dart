// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_images/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:http/http.dart' as http;
import 'package:lib.app.dart/logging.dart';
import 'package:zircon/zircon.dart';

export 'dart:typed_data' show Uint8List;
export 'package:fidl_fuchsia_modular/fidl.dart';

/// Converts a url into a SizedVmo.  Null is returned if a SizedVmo couldn't
/// be created from the given url.
Future<SizedVmo> urlToVmo(String url) async {
  if (url?.isEmpty ?? true) {
    return null;
  }
  if (url.startsWith('http')) {
    http.Response response = await http.get(url);
    if (response.statusCode != 200) {
      return null;
    }
    HandleResult result = System.vmoCreate(response.bodyBytes.lengthInBytes);
    if (result.status == 0 && result.handle != null) {
      SizedVmo vmo = new SizedVmo(
        result.handle,
        response.bodyBytes.lengthInBytes,
      );
      if (vmo.write(response.bodyBytes.buffer.asByteData()) != 0) {
        return null;
      }
      return vmo;
    } else {
      return null;
    }
  } else {
    String modifiedUrl =
        url.startsWith('file://') ? url.substring('file://'.length) : url;
    try {
      return new SizedVmo.fromFile(modifiedUrl);
      // ignore: avoid_catching_errors
    } on ZxStatusException catch (e) {
      log.severe('Caught exception reading \'$modifiedUrl\' (\'$url\')! $e');
      return null;
    }
  }
}

/// Creates a SuggestionDIsplayImage from an image url.
Future<SuggestionDisplayImage> createSuggestionDisplayImage({
  String url,
  SuggestionImageType imageType = SuggestionImageType.other,
}) async {
  SizedVmo image = await urlToVmo(url);
  if (image == null) {
    return null;
  }
  return new SuggestionDisplayImage(
    image: new EncodedImage(vmo: image, size: image.size),
    imageType: imageType,
  );
}

/// Creates a proposal.
// TODO(miguelfrde): we should use a Builder pattern here instead.
Future<Proposal> createProposal({
  String id,
  String storyId,
  bool storyAffinity = false,
  double confidence = 0.0,
  String headline,
  String subheadline,
  String details,
  String imageUrl,
  SuggestionImageType imageType = SuggestionImageType.other,
  List<String> iconUrls,
  int color,
  AnnoyanceType annoyanceType = AnnoyanceType.none,
  List<Action> actions,
}) async {
  List<SuggestionDisplayImage> icons = iconUrls == null
      ? <SuggestionDisplayImage>[]
      : (await Future.wait(
          iconUrls.map(
            (String url) => createSuggestionDisplayImage(url: url),
          ),
        ))
          .where((SuggestionDisplayImage icon) => icon != null)
          .toList();

  SuggestionDisplayImage image = await createSuggestionDisplayImage(
    url: imageUrl,
    imageType: imageType,
  );

  return new Proposal(
    id: id,
    storyId: storyId,
    storyAffinity: storyAffinity,
    confidence: confidence,
    display: new SuggestionDisplay(
      headline: headline,
      subheadline: subheadline,
      details: details,
      color: color,
      icons: icons.isEmpty ? null : icons,
      image: image,
      annoyance: annoyanceType,
    ),
    onSelected: actions,
  );
}

/// Reads the data out of a SuggestionDisplayImage.
Uint8List readSuggestionDisplayImage(SuggestionDisplayImage image) =>
    readEncodedImage(image.image);

/// Reads the data out of an EncodedImage.
Uint8List readEncodedImage(EncodedImage image) {
  ReadResult result = image.vmo.read(image.size);
  if (result.status == 0) {
    return result.bytesAsUint8List();
  }
  return null;
}
