// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geocoding_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeocodingModel _$GeocodingModelFromJson(Map<String, dynamic> json) =>
    GeocodingModel(
      streetName: json['streetName'] as String? ?? '',
      streetNumber: json['streetNumber'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      siDo: json['siDo'] as String? ?? '',
      guGun: json['guGun'] as String? ?? '',
      dong: json['dong'] as String? ?? '',
    );

Map<String, dynamic> _$GeocodingModelToJson(GeocodingModel instance) =>
    <String, dynamic>{
      'streetName': instance.streetName,
      'streetNumber': instance.streetNumber,
      'postalCode': instance.postalCode,
      'siDo': instance.siDo,
      'guGun': instance.guGun,
      'dong': instance.dong,
    };
