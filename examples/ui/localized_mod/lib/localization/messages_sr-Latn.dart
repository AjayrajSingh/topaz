// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a sr_Latn locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';
import 'dart:convert';
import 'messages_all.dart' show evaluateJsonTemplate;

// ignore: unnecessary_new
final messages = new MessageLookup();

// ignore: unused_element
final _keepAnalysisHappy = Intl.defaultLocale;

// ignore: non_constant_identifier_names
typedef MessageIfAbsent(String message_str, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  get localeName => 'sr_Latn';

  String evaluateMessage(translation, List<dynamic> args) {
    return evaluateJsonTemplate(translation, args);
  }

  var _messages;
  // ignore: unnecessary_new
  get messages => _messages ??= new JsonDecoder().convert(messageText);
  static final messageText = r'''
{"appTitle":"Lokalizovani mod","bodyText":["Intl.plural",0,"Nema poruka.","Jedna poruka.",null,[0," poruke."],null,[0," poruka."]],"footer":"Dolazi uskoro: zapravo čitanje ovih poruka!"}''';
}
