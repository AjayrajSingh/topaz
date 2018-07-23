///
//  Generated code. Do not modify.
///
// ignore_for_file: non_constant_identifier_names,library_prefixes

// ignore: UNUSED_SHOWN_NAME
import 'dart:core' show int, bool, double, String, List, override;

import 'package:protobuf/protobuf.dart';

class Audio extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('Audio')
    ..a<double>(1, 'gain', PbFieldType.OD)
    ..aOB(2, 'muted')
    ..hasRequiredFields = false
  ;

  Audio() : super();
  Audio.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Audio.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Audio clone() => new Audio()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;
  static Audio create() => new Audio();
  static PbList<Audio> createRepeated() => new PbList<Audio>();
  static Audio getDefault() {
    if (_defaultInstance == null) _defaultInstance = new _ReadonlyAudio();
    return _defaultInstance;
  }
  static Audio _defaultInstance;
  static void $checkItem(Audio v) {
    if (v is! Audio) checkItemFailed(v, 'Audio');
  }

  double get gain => $_getN(0);
  set gain(double v) { $_setDouble(0, v); }
  bool hasGain() => $_has(0);
  void clearGain() => clearField(1);

  bool get muted => $_get(1, false);
  set muted(bool v) { $_setBool(1, v); }
  bool hasMuted() => $_has(1);
  void clearMuted() => clearField(2);
}

class _ReadonlyAudio extends Audio with ReadonlyMessageMixin {}

