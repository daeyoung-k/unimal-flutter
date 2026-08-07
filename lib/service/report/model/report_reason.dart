/// 신고 사유.
///
/// **[name] 값은 서버의 `com.unimal.common.enums.report.ReportReason` 과 정확히 같아야
/// 한다.** 서버가 `@Enumerated(EnumType.STRING)` 으로 저장하기 때문에, 이름이 어긋나면
/// 접수는 되는데 어드민에서 목록을 열 때 역직렬화가 깨진다 — 신고 한 건 때문에 화면
/// 전체가 죽고, 원인을 찾기도 어렵다(실제로 옛 자유 텍스트 데이터로 겪었다).
///
/// 사유를 추가할 일이 생기면 **서버부터 배포한 뒤** 앱을 낸다. 순서가 반대면 구버전
/// 서버가 모르는 값을 받는다.
enum ReportReason {
  spam('SPAM', '스팸/광고'),
  abuse('ABUSE', '욕설/비방/혐오'),
  sexual('SEXUAL', '음란물/선정성'),
  falseInfo('FALSE_INFO', '허위정보'),
  illegal('ILLEGAL', '불법정보'),
  privacy('PRIVACY', '개인정보 노출'),
  etc('ETC', '기타');

  const ReportReason(this.name, this.label);

  /// 서버로 보내는 값.
  final String name;

  /// 화면에 보여주는 문구.
  final String label;

  /// 상세 내용이 필수인 사유.
  ///
  /// 서버도 같은 검증을 한다(`REPORT_DESCRIPTION_REQUIRED`). 앱에서 먼저 막는 이유는
  /// 사용자가 다 적고 나서 거절당하는 것보다 버튼을 비활성으로 두는 편이 낫기 때문이다.
  bool get requiresDescription => this == ReportReason.etc;
}

/// 신고 대상 종류. 서버의 `ReportTargetType` 과 이름이 같아야 한다.
enum ReportTargetType {
  post('POST'),
  reply('REPLY'),
  user('USER');

  const ReportTargetType(this.name);

  final String name;
}
