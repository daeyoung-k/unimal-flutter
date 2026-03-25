import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/notice/model/notice_model.dart';
import 'package:unimal/state/secure_storage.dart';
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
    try {
      final res = await http.get(url, headers: await _authHeaders());
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body['code'] == 200) {
        final list = body['data'] as List? ?? [];
        return list.map((e) => NoticeModel.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _logger.e('공지사항 목록 조회 실패.. ${body['message']}');
        return [];
      }
    } catch (e) {
      _logger.e('공지사항 목록 조회 실패.. $e');
      return [];
    }
  }

  Future<NoticeModel?> getNoticeDetail(String noticeId) async {
    final url = ApiUri.resolve('/admin/notice/$noticeId');
    try {
      final res = await http.get(url, headers: await _authHeaders());
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body['code'] == 200) {
        return NoticeModel.fromJson(body['data'] as Map<String, dynamic>);
      } else {
        _logger.e('공지사항 상세 조회 실패.. ${body['message']}');
        return null;
      }
    } catch (e) {
      _logger.e('공지사항 상세 조회 실패.. $e');
      return null;
    }
  }
}
