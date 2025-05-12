enum LoginType {
  naver("네이버 로그인"),
  kakao("카카오 로그인"),
  google("구글 로그인"),
  manual("일반(수동) 이메일 로그인"),
  none("로그인 상태가 아닙니다.");

  const LoginType(this.description);
  final String description;

  factory LoginType.from(String code) {
    return LoginType.values.firstWhere((value) => value.name == code,
        orElse: () => LoginType.none);
  }
}
