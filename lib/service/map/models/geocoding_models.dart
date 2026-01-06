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
  final String? siDo;

  @JsonKey(defaultValue: '')
  final String? guGun;
  
  @JsonKey(defaultValue: '')
  final String? dong;

  @JsonKey(defaultValue: 0)
  double? latitude;

  @JsonKey(defaultValue: 0)
  double? longitude;

  GeocodingModel({
      required this.streetName,
      required this.streetNumber,
      required this.postalCode,
      this.siDo,
      this.guGun,
      this.dong,
      this.latitude,
      this.longitude,
  });

  factory GeocodingModel.fromJson(Map<String, dynamic> json) => _$GeocodingModelFromJson(json);
  Map<String, dynamic> toJson() => _$GeocodingModelToJson(this);
}