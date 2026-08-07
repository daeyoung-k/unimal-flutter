import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:unimal/service/report/model/report_reason.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/api_client.dart';
import 'package:unimal/utils/api_uri.dart';

/// 신고 요청 결과.
///
/// 성공/실패와 함께 **서버가 준 메시지를 그대로 들고 온다.** "이미 신고한 대상입니다",
/// "자기 자신은 신고할 수 없습니다" 처럼 사용자가 바로 이해할 수 있는 문구라 앱에서
/// 다시 만들 필요가 없고, 문구를 고칠 때 서버만 바꾸면 된다.
class ReportResult {
  const ReportResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class ReportApiService {
  final _logger = Logger();
  final _secureStorage = SecureStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _secureStorage.getAccessToken();
    return {
      'Content-Type': 'application/json;charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 신고를 접수한다.
  ///
  /// [targetId] 는 게시글·댓글이면 Hashids 문자열, 회원이면 이메일이다.
  /// 서버가 종류에 따라 알아서 해석한다.
  ///
  /// ## 성공 판정에 HTTP 상태를 쓰지 않는 이유
  ///
  /// 서버의 예외 핸들러가 `ex.status ?: HttpStatus.OK` 라서 **신고 실패도 HTTP 200 으로
  /// 내려온다.** 성공은 본문 `code = 201`, 실패는 `code = 400` 에 메시지가 담긴다.
  /// `statusCode == 200` 만 보면 "이미 신고한 대상입니다" 를 성공으로 처리하게 된다.
  Future<ReportResult> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? description,
  }) async {
    final url = ApiUri.resolve('board/report');
    final headers = await _authHeaders();
    final trimmedDescription = description?.trim();
    final body = jsonEncode({
      'target_type': targetType.name,
      'target_id': targetId,
      'reason': reason.name,
      if (trimmedDescription != null && trimmedDescription.isNotEmpty)
        'description': trimmedDescription,
    });

    try {
      final response = await ApiClient.post(url, headers, body: body);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final code = decoded is Map ? decoded['code'] as int? : null;
      final message = decoded is Map ? decoded['message'] as String? : null;

      // 2xx 대역이면 접수 성공. 서버는 201 을 준다.
      if (code != null && code >= 200 && code < 300) {
        return const ReportResult(success: true, message: '신고가 접수되었습니다.');
      }

      _logger.w('신고 실패: code=$code, message=$message');
      return ReportResult(
        success: false,
        message: message ?? '신고를 접수하지 못했습니다.',
      );
    } catch (e) {
      // 네트워크 오류나 본문 파싱 실패. 사용자에게 서버 메시지를 줄 수 없다.
      _logger.e('신고 요청 오류: $e');
      return const ReportResult(
        success: false,
        message: '신고를 접수하지 못했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }
}
