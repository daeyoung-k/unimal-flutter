import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/map/models/geocoding_models.dart';

class GeocodingApiService {

  var host = Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER'];

  Future<GeocodingModel> getGeocoding(
    String latitude,
    String longitude,
  ) async {
    var url = Uri.http(host.toString(), 'map/reverse-geocoding', {
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