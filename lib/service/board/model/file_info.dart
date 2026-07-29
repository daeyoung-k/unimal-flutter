class FileInfo {
  final String fileId;
  final String fileUrl;

  /// 마커용 400px JPEG 썸네일 URL. **없을 수 있다.**
  ///
  /// 서버(`unimal-server` photo 모듈)가 업로드 시 파생 생성하는데, 아래 경우엔
  /// 내려오지 않는다:
  /// - 썸네일 도입(2026-07-29) 전에 올라간 기존 파일 (백필 전)
  /// - 비이미지 파일
  /// - 썸네일 생성/업로드 실패 (서버는 원본 업로드만 성공 처리하고 넘어간다)
  ///
  /// 그래서 직접 쓰지 말고 [markerImageUrl] 을 쓸 것.
  final String? thumbUrl;

  FileInfo({
    required this.fileId,
    required this.fileUrl,
    this.thumbUrl,
  });

  /// 마커 아이콘용 이미지 URL — 썸네일이 있으면 그것, 없으면 원본으로 폴백.
  ///
  /// 마커는 200px 원 안에 그리므로 원본(실측 500KB~3.3MB)을 받을 이유가 없다.
  /// 썸네일은 긴 변 400px JPEG 라 훨씬 작고, 콜드 스타트 마커 표시가 빨라진다
  /// (근거: `docs/specs/2026-07-29-마커-썸네일-파생.md`).
  ///
  /// 빈 문자열도 없는 것으로 취급한다 — [fromJson] 이 누락 필드를 `''` 로
  /// 채우는 관례라 null 체크만으로는 부족하다.
  String get markerImageUrl {
    final thumb = thumbUrl;
    return (thumb != null && thumb.isNotEmpty) ? thumb : fileUrl;
  }

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      fileId: json['fileId'] as String? ?? '',
      fileUrl: json['fileUrl'] as String? ?? '',
      thumbUrl: json['thumbUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'fileUrl': fileUrl,
      'thumbUrl': thumbUrl,
    };
  }
}
