import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:unimal/service/map/models/geocoding_models.dart';
import 'package:unimal/utils/api_uri.dart';

class GeocodingApiService {

  Future<GeocodingModel> getGeocoding(
    String latitude,
    String longitude,
  ) async {
    var url = ApiUri.resolve('map/reverse-geocoding', {
      'latitude': latitude,
      'longitude': longitude,
    });    
    var res = await http.get(url);
    var bodyData = jsonDecode(utf8.decode(res.bodyBytes));

    if (bodyData['code'] == 200) {
      return GeocodingModel.fromJson(bodyData['data']);
    } else {
      return GeocodingModel(
        streetName: '위치 정보를 가져오지 못하였습니다.',
        streetNumber: '',
        postalCode: '',
        siDo: null,
        guGun: null,
        dong: null,
        latitude: null,
        longitude: null,
      );
    }
  }
  
}