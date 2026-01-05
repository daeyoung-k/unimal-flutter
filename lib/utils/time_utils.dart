class TimeUtils {
  /// createdAt 문자열을 상대 시간으로 변환 (방금 전, 1분 전, 2시간 전 등)
  static String getRelativeTime(String createdAt) {
    if (createdAt.isEmpty) return '방금 전';

    try {
      // ISO 8601 형식의 날짜 문자열을 파싱
      DateTime createdDate;
      
      // 다양한 날짜 형식 지원
      if (createdAt.contains('T')) {
        // ISO 8601 형식: "2024-01-01T12:00:00" 또는 "2024-01-01T12:00:00Z"
        createdDate = DateTime.parse(createdAt);
      } else if (createdAt.contains('-') && createdAt.contains(' ')) {
        // "2024-01-01 12:00:00" 형식
        final parts = createdAt.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('-');
          final timeParts = parts[1].split(':');
          if (dateParts.length == 3 && timeParts.length >= 2) {
            createdDate = DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
              timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
            );
          } else {
            return '방금 전';
          }
        } else {
          return '방금 전';
        }
      } else {
        // 타임스탬프 형식 (밀리초)
        final timestamp = int.tryParse(createdAt);
        if (timestamp != null) {
          // 타임스탬프가 초 단위인지 밀리초 단위인지 확인
          if (timestamp < 10000000000) {
            // 초 단위 (10자리 미만)
            createdDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          } else {
            // 밀리초 단위
            createdDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        } else {
          return '방금 전';
        }
      }

      final now = DateTime.now();
      final difference = now.difference(createdDate);

      // 미래 시간이면 방금 전으로 표시
      if (difference.isNegative) {
        return '방금 전';
      }

      // 초 단위
      if (difference.inSeconds < 60) {
        return '방금 전';
      }
      
      // 분 단위
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      }
      
      // 시간 단위
      if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      }
      
      // 일 단위
      if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      }
      
      // 주 단위
      if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '${weeks}주 전';
      }
      
      // 월 단위
      if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '${months}개월 전';
      }
      
      // 년 단위
      final years = (difference.inDays / 365).floor();
      return '${years}년 전';
    } catch (e) {
      // 파싱 실패 시 기본값 반환
      return '방금 전';
    }
  }
}

