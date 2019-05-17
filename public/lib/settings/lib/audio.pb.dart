///
//  Generated code. Do not modify.
//  source: audio.proto
///
// ignore_for_file: non_constant_identifier_names,library_prefixes,unused_import

// ignore: UNUSED_SHOWN_NAME
import 'dart:core' show int, bool, double, String, List, Map, override;

import 'package:protobuf/protobuf.dart' as $pb;

class Audio extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('Audio')
    ..a<double>(1, 'gain', $pb.PbFieldType.OD)
    ..aOB(2, 'muted')
    ..hasRequiredFields = false
  ;

  Audio() : super();
  Audio.fromBuffer(List<int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Audio.fromJson(String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Audio clone() => Audio()..mergeFromMessage(this);
  Audio copyWith(void Function(Audio) updates) => super.copyWith((message) => updates(message as Audio));
  $pb.BuilderInfo get info_ => _i;
  static Audio create() => Audio();
  Audio createEmptyInstance() => create();
  static $pb.PbList<Audio> createRepeated() => $pb.PbList<Audio>();
  static Audio getDefault() => _defaultInstance ??= create()..freeze();
  static Audio _defaultInstance;
  static void $checkItem(Audio v) {
    if (v is! Audio) $pb.checkItemFailed(v, _i.qualifiedMessageName);
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

