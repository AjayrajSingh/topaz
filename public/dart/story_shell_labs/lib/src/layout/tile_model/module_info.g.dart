// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: avoid_as

part of 'module_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModuleInfo _$ModuleInfoFromJson(Map<String, dynamic> json) {
  return ModuleInfo(
      modName: json['modName'] as String,
      intent: json['intent'] as String,
      parameters: json['parameters'] == null
          ? null
          : ModuleInfo._unmodifiableListViewFromJson(
              json['parameters'] as List));
}

Map<String, dynamic> _$ModuleInfoToJson(ModuleInfo instance) =>
    <String, dynamic>{
      'modName': instance.modName,
      'intent': instance.intent,
      'parameters': instance.parameters == null
          ? null
          : ModuleInfo._unmodifiableListViewToJson(instance.parameters)
    };
