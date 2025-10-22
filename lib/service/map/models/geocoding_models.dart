import 'package:json_annotation/json_annotation.dart';

part 'geocoding_models.g.dart';

@JsonSerializable()
class GeocodingModel {

  @JsonKey(defaultValue: '')
  final String streetName;

  @JsonKey(defaultValue: '')
  final String streetNumber;

  @JsonKey(defaultValue: '')
  final String postalCode;

  @JsonKey(defaultValue: '')
  final String siDo;

  @JsonKey(defaultValue: '')
  final String guGun;
  
  @JsonKey(defaultValue: '')
  final String dong;

  GeocodingModel({
      required this.streetName,
      required this.streetNumber,
      required this.postalCode,
      required this.siDo,
      required this.guGun,
      required this.dong,
  });

  factory GeocodingModel.fromJson(Map<String, dynamic> json) => _$GeocodingModelFromJson(json);
  Map<String, dynamic> toJson() => _$GeocodingModelToJson(this);
}