import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:unimal/service/notice/model/notice_model.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/api_client.dart';
import 'package:unimal/utils/api_uri.dart';

class NoticeService {
  final _logger = Logger();
  final _secureStorage = SecureStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _secureStorage.getAccessToken();
    return {
      'Content-Type': 'application/json;charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<NoticeModel>> getNoticeList() async {
    final url = ApiUri.resolve('/admin/notice/list');
    final response = await ApiClient.get(url, await _authHeaders());

    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body['code'] == 200) {
        final list = body['data'] as List? ?? [];
        return list.map((e) => NoticeModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }

    _logger.e('공지사항 목록 조회 실패: ${response.statusCode}');
    return [];
  }

  Future<NoticeModel?> getNoticeDetail(String noticeId) async {
    final url = ApiUri.resolve('/admin/notice/$noticeId');
    final response = await ApiClient.get(url, await _authHeaders());

    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body['code'] == 200) {
        return NoticeModel.fromJson(body['data'] as Map<String, dynamic>);
      }
    }

    _logger.e('공지사항 상세 조회 실패: ${response.statusCode}');
    return null;
  }
}
