import 'dart:convert';
import 'package:lib.schemas.dart/entity_codec.dart';

import 'score.dart';

const String _type = 'com.fuchsia.row_column';
const String _xScoreKey = 'xScore';
const String _oScoreKey = 'oScore';

/// Codec for encoding score to json.
class ScoreCodec extends EntityCodec<Score> {
  ScoreCodec() : super(type: _type, encode: _encode, decode: _decode);

  static String _encode(Score data) {
    return jsonEncode({_xScoreKey: data.xScore, _oScoreKey: data.oScore});
  }

  static Score _decode(String data) {
    if (data == null) {
      return null;
    }
    if (data is! String) {
      throw const FormatException('Decoding Entity with unsupported type');
    }
    String encoded = data;
    if (encoded.isEmpty) {
      throw const FormatException('Decoding Entity with empty string');
    }
    if (encoded == 'null') {
      return null;
    }
    var decoded = jsonDecode(encoded);
    if (decoded == null || decoded is! Map) {
      throw const FormatException('Decoding Entity with invalid data');
    }
    Map<String, dynamic> map = decoded.cast<String, dynamic>();
    if (map[_xScoreKey] == null || map[_oScoreKey] == null) {
      throw const FormatException('Converting Entity with invalid values');
    }
    return new Score(decoded['xScore'], decoded['oScore']);
  }
}
