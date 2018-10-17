// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_images/fidl_async.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart';
import 'package:fidl/fidl.dart';
import 'package:http/http.dart' as http;
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

export 'dart:typed_data' show Uint8List;
export 'package:fidl_fuchsia_modular/fidl_async.dart';

/// Dart-idiomatic wrapper to create a modular.Proposal.
class ProposalBuilder {
  String _id;

  /// Creates a new ProposalBuilder for a Proposal with the specified ID.
  ProposalBuilder({
    @required String id,
    @required this.headline,
  })  : assert(id != null && id.isNotEmpty),
        assert(headline != null && headline.isNotEmpty),
        _id = id;

  /// The commands that will be executed if the proposal is accepted.
  List<StoryCommand> commands = [];

  /// The affinities to stories and/or modules the proposal can have.
  List<ProposalAffinity> affinities = [];

  /// Adds an command to the proposal.
  void addStoryCommand(StoryCommand command) => commands.add(command);

  /// Adds an affinity to the proposal.
  void addStoryAffinity(String storyName) {
    final StoryAffinity storyAffinity = StoryAffinity(
      storyName: storyName,
    );
    affinities.add(ProposalAffinity.withStoryAffinity(storyAffinity));
  }

  /// Sets the story name associated with this proposal. The story name is
  /// defined by the creator of the proposal, and can be re-used across
  /// multiple proposals to refer to the same story. If a story with the
  /// given name is not running, one will be created.
  String storyName;

  /// Sets the creator's confidence that the proposal would be selected if it were
  /// the only one presented to the user.
  double confidence = 0.0;

  /// Sets the headline of the display information associated with the Proposal.
  String headline = '';

  /// Sets the subheadline of the display information associated with the Proposal.
  String subheadline;

  /// Sets the details string of the display information associated with the Proposal.
  String details;

  /// Sets the image URL which can be used when suggesting the proposal to the user.
  String imageUrl;

  /// The type of image to display with the suggestion.
  SuggestionImageType imageType;

  /// The icon URLs which can be used when suggesting the proposal to the user.
  List<String> iconUrls = [];

  /// Adds an image URL to the proposal's icons, which can be used when suggesting the
  /// proposal to the user.
  void addIconUrl(String iconUrl) => iconUrls.add(iconUrl);

  /// Sets the color of the display information associated with the Proposal.
  /// The color is encoded as 0xaarrggbb.
  int color = 0;

  /// Sets the AnnoyanceType of the display information associated with the Proposal.
  /// This is used as a hint by the framework to determine how to display the
  /// proposal to the user.
  AnnoyanceType annoyanceType = AnnoyanceType.none;

  /// Sets the ProposalListener for the Proposal, which is notified when
  /// the proposal is accepted.
  InterfaceHandle<ProposalListener> listener;

  /// Returns a new proposal built from the current configuration of the
  /// ProposalBuilder.
  Future<Proposal> build() async {
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

    return Proposal(
        id: _id,
        storyName: storyName,
        onSelected: commands,
        affinity: affinities,
        confidence: confidence,
        display: SuggestionDisplay(
            headline: headline,
            subheadline: subheadline,
            details: details,
            color: color,
            icons: icons.isEmpty ? null : icons,
            image: image,
            annoyance: annoyanceType),
        listener: listener);
  }
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
